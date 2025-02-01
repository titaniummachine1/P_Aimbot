---@class Prediction
local Prediction = {}
Prediction.__index = Prediction

local Common = require("PAimbot.Common")
local G = require("PAimbot.Globals")

-- Constants and helpers.
local vUp         = Vector3(0, 0, 1)
local emptyVector = Vector3(0, 0, 0)
local ignoreEntities = { "CTFAmmoPack", "CTFDroppedWeapon" }
local MAX_SPEED   = 450 -- Default max speed if not provided by player.

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------
-- Determines if an entity should be considered for collision
local function shouldHitEntityFun(entity, player)
    for _, ignoreEntity in ipairs(ignoreEntities) do
        if entity:GetClass() == ignoreEntity then
            return false
        end
    end
    local pos = entity:GetAbsOrigin() + Vector3(0, 0, 1)
    local contents = engine.GetPointContents(pos)
    if contents ~= CONTENTS_EMPTY then return false end
    if entity == player then return false end
    if entity:GetTeamNumber() == player:GetTeamNumber() then return false end
    return true
end

-- Simple check whether the player is on the ground.
local function IsOnGround(player)
    local pFlags = player:GetPropInt("m_fFlags")
    return (pFlags & FL_ONGROUND) == 1
end

-- Provide a simple linear interpolation if not defined.
if not Common.LerpVector then
    function Common.LerpVector(t, a, b)
        return a * (1 - t) + b * t
    end
end

-- Rotate a vector about the Z-axis by a given angle (degrees).
if not Common.RotateVector then
    function Common.RotateVector(vec, angleDeg)
        local rad = math.rad(angleDeg)
        local cosA = math.cos(rad)
        local sinA = math.sin(rad)
        return Vector3(vec.x * cosA - vec.y * sinA, vec.x * sinA + vec.y * cosA, vec.z)
    end
end

--------------------------------------------------------------------------------
-- Prediction State: reset, initialization, and update
--------------------------------------------------------------------------------
function Prediction:reset()
    -- Clear simulation history.
    self.currentTick = 0
    self.cachedPredictions = { pos = {}, vel = {}, onGround = {} }
    
    -- Clear physics variables.
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

    -- Variables for move intent simulation.
    self.moveIntent = nil          -- Current intended movement vector.
    self.initialMoveIntent = nil   -- Baseline movement vector at start.
    self.accumulatedStrafe = 0     -- Accumulated strafe angle (in degrees).
end

function Prediction:init()
    self:reset()
end

-- Update simulation state from the current player's data.
function Prediction:update(player)
    self:reset()

    self.gravity = client.GetConVar("sv_gravity") or 800
    self.acceleration = client.GetConVar("sv_accelerate") or 10
    self.friction = client.GetConVar("sv_friction") or 4
    self.stepHeight = player:GetPropFloat("localdata", "m_flStepSize") or 18

    G.Hitbox.Max.z = IsOnGround(player) and 62 or 82
    self.hitbox = G.Hitbox or { Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82) }
    self.vStep = Vector3(0, 0, self.stepHeight)

    self.position = player:GetAbsOrigin()
    self.velocity = player:EstimateAbsVelocity()

    -- Set the move intent to the current velocity.
    self.initialMoveIntent = self.velocity
    self.moveIntent = self.velocity
    self.accumulatedStrafe = 0

    self.onGround = IsOnGround(player)
    self.MAX_SPEED = player:GetPropFloat("m_flMaxspeed") or MAX_SPEED

    self.shouldHitEntity = function(entity)
        return shouldHitEntityFun(entity, player)
    end

    local playerIndex = player:GetIndex()
    self.deltaStrafe = G.history[playerIndex] or { strafeDelta = 0 }
end

--------------------------------------------------------------------------------
-- predictTick: Simulate one tick of prediction.
--
-- This function applies gravity, rotates the move intent based on strafe input,
-- and then updates the horizontal velocity using friction and acceleration toward
-- the desired (move intent) direction. It then handles wall and ground collisions.
--------------------------------------------------------------------------------
function Prediction:predictTick()
    local dt = G.TickInterval

    -- Apply gravity (vertical component) if airborne.
    if not self.onGround then
        self.velocity.z = self.velocity.z - self.gravity * dt
    end

    -- Rotate the move intent by the current strafe input.
    if self.deltaStrafe then
        self.moveIntent = Common.RotateVector(self.moveIntent, self.deltaStrafe)
    end

    -- Compute the desired horizontal direction from the move intent.
    local desiredDir = Common.Normalize(Vector3(self.moveIntent.x, self.moveIntent.y, 0))
    local desiredSpeed = self.MAX_SPEED  -- Full input implies full speed.

    -- --- Friction: reduce current horizontal speed if on ground.
    local currentHorizontal = Vector3(self.velocity.x, self.velocity.y, 0)
    local currentSpeed = currentHorizontal:Length()
    if self.onGround and currentSpeed > 0 then
        local drop = currentSpeed * self.friction * dt
        local newSpeed = math.max(currentSpeed - drop, 0)
        currentHorizontal = Common.Normalize(currentHorizontal) * newSpeed
    end

    -- --- Acceleration: accelerate horizontally toward the desired direction.
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

    -- Update horizontal velocity; vertical component remains.
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
        MASK_SHOT_HULL,
        self.shouldHitEntity
    )
    if wallTrace.fraction < 1 then
        local normal = wallTrace.plane
        -- Project the desired horizontal direction onto the wall plane.
        local projectedWish = desiredDir - normal * desiredDir:Dot(normal)
        projectedWish = Common.Normalize(projectedWish)
        local horSpeed = currentHorizontal:Length()
        currentHorizontal = projectedWish * horSpeed
        self.velocity.x = currentHorizontal.x
        self.velocity.y = currentHorizontal.y
        pos.x, pos.y = wallTrace.endpos.x, wallTrace.endpos.y
    end

    -- --- Ground Collision Handling ---
    local downStep = self.onGround and self.vStep or emptyVector
    local groundTrace = Common.TRACE_HULL(
        pos + self.vStep,
        pos - downStep,
        self.hitbox.Min,
        self.hitbox.Max,
        MASK_SHOT_HULL,
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

    -- Cache the simulation results.
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
-- Public API for running multiple ticks and rewinding.
--------------------------------------------------------------------------------
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

function Prediction:history()
    return self.cachedPredictions
end

--------------------------------------------------------------------------------
-- Create and return the singleton Prediction instance.
--------------------------------------------------------------------------------
local predictionInstance = setmetatable({}, Prediction)
predictionInstance:init()
return predictionInstance