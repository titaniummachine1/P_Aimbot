---@class Prediction
local Prediction = {}
Prediction.__index = Prediction

-- Reverse imports:
-- Used by: PAimbot.Aimbot, PAimbot.Movement

local Common = require("PAimbot.Common")
local G = require("PAimbot.Globals")

-- Constants and helpers
local vUp = Vector3(0, 0, 1)
local nullVector = Vector3(0, 0, 0)
local ignoreEntities = { "CTFAmmoPack", "CTFDroppedWeapon" }
local MAX_SPEED = 450 -- Default max speed if not provided by player

-- Create a lookup table for faster class checks
local ignoreClassLookup = {}
for _, class in ipairs(ignoreEntities) do
    ignoreClassLookup[class] = true
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------
-- Determines if an entity should be considered for collision
---@param entity Entity The entity to check
---@param player Entity The player entity to compare against
---@return boolean Whether the entity should be hit by traces
local function shouldHitEntityFun(entity, player)
    -- Branchless entity collision check using mathematical operations
    local entityClass = entity:GetClass()
    local isIgnoredClass = ignoreClassLookup[entityClass] and 1 or 0
    local isSameEntity = (entity == player) and 1 or 0
    local isSameTeam = (entity:GetTeamNumber() == player:GetTeamNumber()) and 1 or 0

    local pos = entity:GetAbsOrigin() + Vector3(0, 0, 1)
    local contents = engine.GetPointContents(pos)
    local isNotEmpty = (contents ~= CONTENTS_EMPTY) and 1 or 0

    -- Sum all the "should ignore" conditions - if any are true (sum > 0), we ignore
    local ignoreScore = isIgnoredClass + isSameEntity + isSameTeam + isNotEmpty

    -- Return true only if ignoreScore is 0 (no ignore conditions met)
    return ignoreScore == 0
end

--------------------------------------------------------------------------------
-- Prediction State: reset, initialization, and update
--------------------------------------------------------------------------------
---@param self Prediction
function Prediction:reset()
    -- Clear simulation history
    self.currentTick = 0
    self.cachedPredictions = { pos = {}, vel = {}, onGround = {} }

    -- Clear physics variables
    self.gravity = nil
    self.stepHeight = nil
    self.position = nil
    self.velocity = nil
    self.onGround = nil
    self.deltaStrafe = nil
    self.vStep = nil
    self.hitbox = nil
    self.MAX_SPEED = nil
    self.shouldHitEntity = nil
    self.terminalVelocity = nil

    -- Variables for move intent simulation
    self.moveIntent = nil        -- Current intended movement vector
    self.initialMoveIntent = nil -- Baseline movement vector at start
    self.accumulatedStrafe = 0   -- Accumulated strafe angle (in degrees)
end

-- Update simulation state from the current player's data
---@param self Prediction
---@param player Entity The player entity to simulate
function Prediction:update(player)
    self:reset()

    -- Get physics constants from game
    self.gravity = client.GetConVar("sv_gravity") or 800
    self.acceleration = client.GetConVar("sv_accelerate") or 10
    self.friction = client.GetConVar("sv_friction") or 4
    self.stepHeight = player:GetPropFloat("localdata", "m_flStepSize") or 18

    -- TF2 Terminal Velocity (based on fall damage plateau at ~3500 HU/s)
    self.terminalVelocity = -3500 -- Negative because downward

    -- Set up hitbox dimensions based on player state
    G.Hitbox.Max.z = Common.IsOnGround(player) and 62 or 82
    self.hitbox = G.Hitbox or { Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82) }
    self.vStep = Vector3(0, 0, self.stepHeight)

    -- Get current player state
    self.position = player:GetAbsOrigin()
    self.velocity = player:EstimateAbsVelocity()
    self.onGround = Common.IsOnGround(player)
    self.MAX_SPEED = player:GetPropFloat("m_flMaxspeed") or MAX_SPEED

    -- Set the move intent to the current velocity
    self.initialMoveIntent = self.velocity
    self.moveIntent = self.velocity
    self.accumulatedStrafe = 0

    -- Create a closure for entity collision detection
    self.shouldHitEntity = function(entity)
        return shouldHitEntityFun(entity, player)
    end

    -- Get strafe delta from history
    local playerIndex = player:GetIndex()
    local predictionDelta = G.history[playerIndex] or { strafeDelta = 0 }
    self.deltaStrafe = predictionDelta.strafeDelta
end

--------------------------------------------------------------------------------
-- predictTick: Simulate one tick of prediction.
--
-- This function applies gravity, rotates the move intent based on strafe input,
-- and then updates the horizontal velocity using friction and acceleration toward
-- the desired (move intent) direction. It then handles wall and ground collisions.
--------------------------------------------------------------------------------
---@param self Prediction
---@return table Result containing position, velocity and ground state
function Prediction:predictTick()
    local dt = G.TickInterval

    -- Branchless gravity application: multiply by (1 - onGround) to apply only when airborne
    local airborneMultiplier = self.onGround and 0 or 1
    self.velocity.z = self.velocity.z - self.gravity * dt * airborneMultiplier

    -- Apply terminal velocity clamping (branchless)
    -- Only clamp if velocity is more negative than terminal velocity
    local exceedsTerminal = (self.velocity.z < self.terminalVelocity) and 1 or 0
    self.velocity.z = self.velocity.z * (1 - exceedsTerminal) + self.terminalVelocity * exceedsTerminal

    -- Rotate the move intent by the current strafe input (branchless - deltaStrafe can be 0)
    self.moveIntent = Common.RotateVector(self.moveIntent, self.deltaStrafe or 0)

    -- Compute the desired horizontal direction from the move intent
    local desiredDir = Common.Normalize(Vector3(self.moveIntent.x, self.moveIntent.y, 0))
    local desiredSpeed = self.MAX_SPEED -- Full input implies full speed

    -- --- Friction: reduce current horizontal speed if on ground (branchless)
    local currentHorizontal = Vector3(self.velocity.x, self.velocity.y, 0)
    local currentSpeed = currentHorizontal:Length()

    -- Branchless friction calculation
    local groundMultiplier = self.onGround and 1 or 0
    local speedMultiplier = (currentSpeed > 0) and 1 or 0
    local drop = currentSpeed * self.friction * dt * groundMultiplier * speedMultiplier
    local newSpeed = math.max(currentSpeed - drop, 0)

    -- Branchless normalization: if currentSpeed is 0, this becomes (0,0,0) * 0 = (0,0,0)
    local normalizedCurrent = currentSpeed > 0 and (currentHorizontal / currentSpeed) or Vector3(0, 0, 0)
    currentHorizontal = normalizedCurrent * newSpeed

    -- --- Acceleration: accelerate horizontally toward the desired direction
    local speedAlongWish = currentHorizontal:Dot(desiredDir)
    local addSpeed = desiredSpeed - speedAlongWish
    local accelSpeed = self.acceleration * desiredSpeed * dt

    -- Branchless min: use math.min instead of if-then
    accelSpeed = math.min(accelSpeed, addSpeed)

    currentHorizontal = currentHorizontal + desiredDir * accelSpeed

    -- Branchless speed clamping
    local currentHorLength = currentHorizontal:Length()
    local clampMultiplier = math.min(desiredSpeed / math.max(currentHorLength, 0.001), 1)
    currentHorizontal = currentHorizontal * clampMultiplier

    -- Update horizontal velocity; vertical component remains
    self.velocity.x = currentHorizontal.x
    self.velocity.y = currentHorizontal.y

    -- --- Update Position ---
    local pos = self.position + self.velocity * dt
    local vel = self.velocity
    local onGround = self.onGround

    -- --- Wall Collision Handling ---
    local wallTrace = Common.TRACE_HULL(
        self.position + self.vStep,
        pos + self.vStep,
        self.hitbox.Min,
        self.hitbox.Max,
        MASK_PLAYERSOLID,
        self.shouldHitEntity
    )

    -- Branchless wall collision handling
    local hitWall = (wallTrace.fraction < 1) and 1 or 0
    local normal = wallTrace.plane or Vector3(0, 0, 0)
    local dot = vel:Dot(normal)

    -- Only clip if moving into the wall (dot < 0) and we hit a wall
    local clipMultiplier = ((dot < 0) and hitWall == 1) and 1 or 0
    vel = vel - normal * (dot * clipMultiplier)

    -- Branchless position update: lerp between original pos and collision point
    pos.x = pos.x * (1 - hitWall) + wallTrace.endpos.x * hitWall
    pos.y = pos.y * (1 - hitWall) + wallTrace.endpos.y * hitWall

    -- Update velocity components
    self.velocity.x = vel.x
    self.velocity.y = vel.y

    -- --- Ground Collision Handling ---
    local downStep = self.onGround and self.vStep or nullVector
    local groundTrace = Common.TRACE_HULL(
        pos + self.vStep,
        pos - downStep,
        self.hitbox.Min,
        self.hitbox.Max,
        MASK_PLAYERSOLID,
        self.shouldHitEntity
    )

    -- Branchless ground collision
    local hitGround = (groundTrace.fraction < 1) and 1 or 0
    local groundNormal = groundTrace.plane or Vector3(0, 0, 1)
    local groundAngle = math.deg(math.acos(math.max(0, math.min(1, groundNormal:Dot(vUp)))))

    -- Determine ground state based on angle ranges (branchless)
    local isWalkable = (groundAngle < 45) and 1 or 0
    local isSlippery = ((groundAngle >= 45) and (groundAngle < 55)) and 1 or 0
    local isWall = (groundAngle >= 55) and 1 or 0

    -- Apply ground effects branchlessly
    pos = pos * (1 - hitGround * isWalkable) + groundTrace.endpos * (hitGround * isWalkable)
    onGround = (hitGround * isWalkable == 1) or (hitGround * isWall == 1)

    -- Handle slippery surfaces (stop all movement)
    vel = vel * (1 - hitGround * isSlippery)

    -- Handle wall surfaces (clip velocity)
    local wallDot = vel:Dot(groundNormal)
    vel = vel - groundNormal * (wallDot * hitGround * isWall)

    -- Zero vertical velocity if on ground
    local groundVelMultiplier = onGround and 0 or 1
    vel.z = vel.z * groundVelMultiplier

    -- Apply gravity again if not on ground (was already applied at start for airborne)
    local finalAirborneMultiplier = onGround and 0 or 1
    vel.z = vel.z - self.gravity * dt * finalAirborneMultiplier

    -- Apply terminal velocity clamping again after ground collision effects
    local exceedsTerminalFinal = (vel.z < self.terminalVelocity) and 1 or 0
    vel.z = vel.z * (1 - exceedsTerminalFinal) + self.terminalVelocity * exceedsTerminalFinal

    -- Cache the simulation results
    self.cachedPredictions.pos[self.currentTick + 1] = pos
    self.cachedPredictions.vel[self.currentTick + 1] = vel
    self.cachedPredictions.onGround[self.currentTick + 1] = onGround

    self.position = pos
    self.velocity = vel
    self.onGround = onGround
    self.currentTick = self.currentTick + 1

    return { pos = pos, vel = vel, onGround = onGround }
end

--------------------------------------------------------------------------------
-- Public API for running multiple ticks and rewinding
--------------------------------------------------------------------------------
---@param self Prediction
---@param ticks number Number of ticks to predict forward
---@return table Result containing position, velocity and ground state
function Prediction:predict(ticks)
    ticks = ticks or 1
    for i = 1, ticks do
        self:predictTick()
    end
    return {
        pos = self.cachedPredictions.pos[self.currentTick],
        vel = self.cachedPredictions.vel[self.currentTick],
        onGround = self.cachedPredictions.onGround[self.currentTick]
    }
end

---@param self Prediction
---@param ticks number Number of ticks to rewind
---@return table Result containing position, velocity and ground state
function Prediction:rewind(ticks)
    ticks = ticks or 1
    local targetTick = self.currentTick - ticks
    if targetTick < 1 then targetTick = 1 end
    self.currentTick = targetTick
    return {
        pos = self.cachedPredictions.pos[self.currentTick],
        vel = self.cachedPredictions.vel[self.currentTick],
        onGround = self.cachedPredictions.onGround[self.currentTick]
    }
end

---@param self Prediction
---@return table Complete prediction history
function Prediction:history()
    return self.cachedPredictions
end

--------------------------------------------------------------------------------
-- Create and return the singleton Prediction instance
--------------------------------------------------------------------------------
local predictionInstance = setmetatable({}, Prediction)
predictionInstance:reset()
return predictionInstance
