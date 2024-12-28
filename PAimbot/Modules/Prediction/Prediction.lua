---@class Prediction
local Prediction = {}
Prediction.__index = Prediction

local Common = require("PAimbot.Common")
local G = require("PAimbot.Globals")

local vUp         = Vector3(0, 0, 1)
local emptyVector = Vector3(0, 0, 0)
local ignoreEntities = { "CTFAmmoPack", "CTFDroppedWeapon" }
local MAX_SPEED   = 450 -- Maximum speed the player can have on the ground

--------------------------------------------------------------------------------
-- Determines if we should hit (collide with) the given entity.
-- This filters out ammo packs, dropped weapons, self, teammates, or anything
-- in solid area that we shouldn’t collide with for prediction logic.
--------------------------------------------------------------------------------
local function shouldHitEntityFun(entity, player)
    -- Ignore certain entities based on their class
    for _, ignoreEntity in ipairs(ignoreEntities) do
        if entity:GetClass() == ignoreEntity then
            return false
        end
    end

    -- Check if the entity is in a solid area (not air)
    local pos      = entity:GetAbsOrigin() + Vector3(0, 0, 1)
    local contents = engine.GetPointContents(pos)
    if contents ~= CONTENTS_EMPTY then
        return false
    end

    -- Ignore self (the player being simulated)
    if entity == player then
        return false
    end

    -- Ignore teammates
    if entity:GetTeamNumber() == player:GetTeamNumber() then
        return false
    end

    -- Otherwise, we consider the entity as hittable
    return true
end

--------------------------------------------------------------------------------
-- Returns whether the player is on the ground using m_fFlags & FL_ONGROUND
--------------------------------------------------------------------------------
---@return boolean
local function IsOnGround(player)
    local pFlags = player:GetPropInt("m_fFlags")
    return (pFlags & FL_ONGROUND) == 1
end

--------------------------------------------------------------------------------
-- Prediction: The main class handling movement and collision prediction.
--------------------------------------------------------------------------------
---@class Prediction
function Prediction:reset()
    -- Clears all prediction data
    self.currentTick = 0
    self.cachedPredictions = {
        pos      = {},
        vel      = {},
        onGround = {}
    }
    self.gravity      = nil
    self.stepHeight   = nil
    self.position     = nil
    self.velocity     = nil
    self.onGround     = nil
    self.deltaStrafe  = nil
    self.vStep        = nil
    self.hitbox       = nil
    self.MAX_SPEED    = nil
    self.shouldHitEntity = nil
end

--------------------------------------------------------------------------------
-- Retrieves the current tick number and its associated data
--------------------------------------------------------------------------------
function Prediction:getCurrentState()
    if self.cachedPredictions.pos[self.currentTick] then
        return self.currentTick, {
            pos      = self.cachedPredictions.pos[self.currentTick],
            vel      = self.cachedPredictions.vel[self.currentTick],
            onGround = self.cachedPredictions.onGround[self.currentTick]
        }
    end
    return self.currentTick, nil
end

--------------------------------------------------------------------------------
-- Initialize the Prediction instance
--------------------------------------------------------------------------------
function Prediction:init()
    self:reset() -- Automatically reset on initialization
end

--------------------------------------------------------------------------------
-- Update: Updates prediction with player data (gravity, step height, etc.)
--         and prepares initial state for the predict() calls.
--------------------------------------------------------------------------------
function Prediction:update(player)
    -- Reset to clear the cache before updating with new data
    self:reset()

    -- Cache gravity using the ConVar, with a fallback default value of 800
    self.gravity = client.GetConVar("sv_gravity") or 800

    -- Cache step height from the player's properties, with a fallback default of 18
    self.stepHeight = player:GetPropFloat("localdata", "m_flStepSize") or 18

    -- Cache hitbox dimensions from G.Hitbox, if available
    -- Adjust for ducking if on ground
    G.Hitbox.Max.z = IsOnGround(player) and 62 or 82
    self.hitbox = G.Hitbox or { Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82) }

    -- Cache vStep based on the cached step height
    self.vStep = Vector3(0, 0, self.stepHeight)

    -- Cache initial player state
    self.position  = player:GetAbsOrigin()
    self.velocity  = player:EstimateAbsVelocity()
    self.onGround  = IsOnGround(player)
    self.MAX_SPEED = player:GetPropFloat("m_flMaxspeed") or MAX_SPEED -- If not found, default 450

    -- Set up a function to decide whether we should collide with a given entity
    self.shouldHitEntity = function(entity)
        return shouldHitEntityFun(entity, player)
    end

    -- Retrieve the delta values from the global prediction delta table
    local playerIndex   = player:GetIndex()
    local predictionDelta = G.history[playerIndex] or { strafeDelta = 0 }
    self.deltaStrafe = predictionDelta.strafeDelta
end

--------------------------------------------------------------------------------
-- predictTick: Runs the prediction logic for one simulation tick
--------------------------------------------------------------------------------
function Prediction:predictTick()
    -- Apply gravity if the player is not on the ground
    if not self.onGround then
        self.velocity.z = self.velocity.z + (-self.gravity * G.TickInterval)
    end

    -- Rotate velocity by the strafeDelta angle
    local velocitySpeed = self.velocity:Length()
    if self.deltaStrafe then
        local ang = self.velocity:Angles()
        ang.y = ang.y + self.deltaStrafe
        self.velocity = ang:Forward() * velocitySpeed
    end

    -- Compute the start position and velocity for this current tick
    local pos      = self.position + self.velocity * G.TickInterval
    local vel      = self.velocity
    local onGround = self.onGround

    -- Forward collision handling
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
        local angle  = math.deg(math.acos(normal:Dot(vUp)))

        -- If wall is steep (angle > 55), slide along it
        if angle > 55 then
            local dot = vel:Dot(normal)
            vel = vel - normal * dot
        end

        -- Adjust the X/Y position to the collision impact
        pos.x, pos.y = wallTrace.endpos.x, wallTrace.endpos.y
    end

    -- Ground collision handling
    local downStep = self.vStep
    if not onGround then
        downStep = emptyVector
    end

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
        local angle  = math.deg(math.acos(normal:Dot(vUp)))

        -- Gentle slope => land on ground
        if angle < 45 then
            pos      = groundTrace.endpos
            onGround = true

        -- Near vertical => zero velocity, remain in air
        elseif angle < 55 then
            vel.x, vel.y, vel.z = 0, 0, 0
            onGround = false

        -- Slide along angled surface => on ground
        else
            local dot = vel:Dot(normal)
            vel = vel - normal * dot
            onGround = true
        end

        -- If on ground, nullify vertical velocity
        if onGround then
            vel.z = 0
        end
    else
        onGround = false
    end

    -- Gravity application if not on the ground (second time)
    if not onGround then
        vel.z = vel.z - self.gravity * G.TickInterval
    end

    -- Store the prediction result for this tick
    self.cachedPredictions.pos[self.currentTick + 1]      = pos
    self.cachedPredictions.vel[self.currentTick + 1]      = vel
    self.cachedPredictions.onGround[self.currentTick + 1] = onGround

    -- Update the current state for the next tick
    self.position  = pos
    self.velocity  = vel
    self.onGround  = onGround
    self.currentTick = self.currentTick + 1

    -- Return the final state of this tick
    return {
        pos      = pos,
        vel      = vel,
        onGround = onGround
    }
end

--------------------------------------------------------------------------------
-- predict: Predicts a given number of ticks ahead from the current tick
--------------------------------------------------------------------------------
function Prediction:predict(ticks)
    ticks = ticks or 1 -- Default to predicting one tick if no value is provided

    -- Predict the necessary ticks
    for i = 1, ticks do
        self:predictTick()
    end

    -- Return the result table for the final tick
    return {
        pos      = self.cachedPredictions.pos[self.currentTick],
        vel      = self.cachedPredictions.vel[self.currentTick],
        onGround = self.cachedPredictions.onGround[self.currentTick]
    }
end

--------------------------------------------------------------------------------
-- Rewind: Rewinds the prediction to a previous tick
--------------------------------------------------------------------------------
function Prediction:rewind(ticks)
    ticks = ticks or 1 -- Default to rewinding one tick if no value is provided
    local targetTick = self.currentTick - ticks

    if targetTick < 1 then
        targetTick = 1 -- Ensure we don't rewind before the first tick
    end

    self.currentTick = targetTick

    -- Return the result table for the rewound tick
    return {
        pos      = self.cachedPredictions.pos[self.currentTick],
        vel      = self.cachedPredictions.vel[self.currentTick],
        onGround = self.cachedPredictions.onGround[self.currentTick]
    }
end

--------------------------------------------------------------------------------
-- history: Returns the entire prediction history (pos/vel/onGround for each tick)
--------------------------------------------------------------------------------
function Prediction:history()
    return self.cachedPredictions
end

--------------------------------------------------------------------------------
-- Initialize and return the Prediction instance immediately
--------------------------------------------------------------------------------
local predictionInstance = setmetatable({}, Prediction)
predictionInstance:init()

return predictionInstance
