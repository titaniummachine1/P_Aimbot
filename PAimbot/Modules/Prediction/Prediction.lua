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
    -- Use logical operators to create a single return statement
    -- Each condition evaluates to true/false and we return true only if all checks pass
    local entityClass = entity:GetClass()
    local sameTeam = entity:GetTeamNumber() == player:GetTeamNumber()
    local pos = entity:GetAbsOrigin() + Vector3(0, 0, 1)
    local contents = engine.GetPointContents(pos)

    return not (
        ignoreClassLookup[entityClass] or -- Not in ignore list
        entity == player or               -- Not the player
        sameTeam or                       -- Not on same team
        contents ~= CONTENTS_EMPTY        -- Not in empty space
    )
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

    -- Apply gravity (vertical component) if airborne
    if not self.onGround then
        self.velocity.z = self.velocity.z - self.gravity * dt
    end

    -- Rotate the move intent by the current strafe input
    if self.deltaStrafe then
        self.moveIntent = Common.RotateVector(self.moveIntent, self.deltaStrafe)
    end

    -- Compute the desired horizontal direction from the move intent
    local desiredDir = Common.Normalize(Vector3(self.moveIntent.x, self.moveIntent.y, 0))
    local desiredSpeed = self.MAX_SPEED -- Full input implies full speed

    -- --- Friction: reduce current horizontal speed if on ground
    local currentHorizontal = Vector3(self.velocity.x, self.velocity.y, 0)
    local currentSpeed = currentHorizontal:Length()
    if self.onGround and currentSpeed > 0 then
        local drop = currentSpeed * self.friction * dt
        local newSpeed = math.max(currentSpeed - drop, 0)
        currentHorizontal = Common.Normalize(currentHorizontal) * newSpeed
    end

    -- --- Acceleration: accelerate horizontally toward the desired direction
    local speedAlongWish = currentHorizontal:Dot(desiredDir)
    local addSpeed = desiredSpeed - speedAlongWish
    local accelSpeed = self.acceleration * desiredSpeed * dt
    if accelSpeed > addSpeed then
        accelSpeed = addSpeed
    end
    currentHorizontal = currentHorizontal + desiredDir * accelSpeed

    if currentHorizontal:Length() > desiredSpeed then
        currentHorizontal = Common.Normalize(currentHorizontal) * desiredSpeed
    end

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
    if wallTrace.fraction < 1 then
        local normal = wallTrace.plane
        -- In TF2, wall collision only affects velocity, NOT the moveIntent/strafe direction
        -- The player continues to strafe in their intended direction, but velocity gets clipped along the wall

        -- Clip the velocity along the wall plane (not the desired direction)
        local dot = vel:Dot(normal)
        if dot < 0 then -- Only clip if moving into the wall
            vel = vel - normal * dot
        end

        -- Update position to the collision point
        pos.x, pos.y = wallTrace.endpos.x, wallTrace.endpos.y

        -- Update the horizontal velocity components after clipping
        self.velocity.x = vel.x
        self.velocity.y = vel.y
    end

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
    if groundTrace.fraction < 1 then
        local normal = groundTrace.plane
        local angle = math.deg(math.acos(normal:Dot(vUp)))
        if angle < 45 then
            pos = groundTrace.endpos
            onGround = true
        elseif angle < 55 then
            vel = Vector3(0, 0, 0)
            onGround = false
        else
            local dot = vel:Dot(normal)
            vel = vel - normal * dot
            onGround = true
        end
        if onGround then
            vel.z = 0
        end
    else
        onGround = false
    end

    if not onGround then
        vel.z = vel.z - self.gravity * dt
    end

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
