---@class HistoryHandler
local HistoryHandler = {}
HistoryHandler.__index = HistoryHandler

local G = require("PAimbot.Globals")
local Config = require("PAimbot.Config")

--------------------------------------------------------------------------------
-- Kalman Filter Configuration
--------------------------------------------------------------------------------
HistoryHandler.kalmanConfig = {
    processNoise = 0.7,          -- Base process noise (Q)
    baseMeasurementNoise = 0.05, -- Base measurement noise (R)
    minimumHistoryCount = 4,     -- Minimum sample count for dynamic noise computation
}

--------------------------------------------------------------------------------
-- Initialize HistoryHandler storage
--------------------------------------------------------------------------------
function HistoryHandler:init()
    -- Table to store motion data samples per entity:
    -- histories[entityIndex] = {
    --   {strafeDelta = value, velocity = vec, acceleration = vec, jerk = vec, snap = vec, pop = vec, timestamp = time},
    --   ...
    -- }
    self.histories = {}

    -- For computing differences between successive measurements
    self.lastVelocities = {}    -- last recorded velocity for each entity
    self.lastAccelerations = {} -- last recorded acceleration for each entity
    self.lastJerks = {}         -- last recorded jerk for each entity
    self.lastSnaps = {}         -- last recorded snap for each entity
    self.lastPositions = {}     -- last recorded position for each entity

    -- (Optional) Last delta values
    self.lastDelta = {}

    -- Maximum number of history samples to store per entity (configurable)
    self.maxHistoryTicks = Config.advanced.maxPredictionHistory or 66 -- Default 66, range 7-198

    -- Table of Kalman filters for smoothing motion data
    self.kalmanFiltersDelta = {}
    self.kalmanFiltersAccel = {}
    self.kalmanFiltersJerk = {}

    -- Clear the global history table
    G.history = {}
end

--------------------------------------------------------------------------------
-- Compute sample standard deviation of a specific motion component
--------------------------------------------------------------------------------
local function computeStdDev(history, component)
    if not history or #history < 2 then
        return nil
    end

    local sum = 0
    local count = 0
    for _, data in ipairs(history) do
        if data[component] ~= nil then
            if type(data[component]) == "number" then
                sum = sum + data[component]
            else
                -- Vector component - use magnitude
                sum = sum + data[component]:Length()
            end
            count = count + 1
        end
    end

    if count < 2 then return nil end

    local mean = sum / count

    local varianceSum = 0
    for _, data in ipairs(history) do
        if data[component] ~= nil then
            local value = type(data[component]) == "number" and data[component] or data[component]:Length()
            local diff = value - mean
            varianceSum = varianceSum + diff * diff
        end
    end

    local sampleVariance = varianceSum / (count - 1)
    return math.sqrt(sampleVariance)
end

--------------------------------------------------------------------------------
-- Calculate predictability score based on motion consistency
-- Lower values = more predictable movement
--------------------------------------------------------------------------------
function HistoryHandler:calculatePredictabilityScore(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history < 4 then
        return 1.0 -- High unpredictability if insufficient data
    end

    -- Calculate variance for different motion components
    local strafeVariance = computeStdDev(history, "strafeDelta") or 0
    local accelVariance = computeStdDev(history, "acceleration") or 0
    local jerkVariance = computeStdDev(history, "jerk") or 0
    local snapVariance = computeStdDev(history, "snap") or 0
    local popVariance = computeStdDev(history, "pop") or 0

    -- Weighted combination - higher order derivatives indicate less predictable movement
    local predictabilityScore = (
        strafeVariance * 0.3 + -- 30% weight on strafe consistency
        accelVariance * 0.25 + -- 25% weight on acceleration consistency
        jerkVariance * 0.20 +  -- 20% weight on jerk consistency
        snapVariance * 0.15 +  -- 15% weight on snap consistency
        popVariance * 0.10     -- 10% weight on pop consistency
    )

    -- Normalize to 0-1 range (higher = less predictable)
    return math.min(predictabilityScore / 100.0, 1.0)
end

--------------------------------------------------------------------------------
-- Calculate dynamic measurement noise (R) using the sample variance.
--------------------------------------------------------------------------------
function HistoryHandler:calculateDynamicMeasurementNoise(entityIndex, component)
    local history = self.histories[entityIndex]
    if not history or #history < self.kalmanConfig.minimumHistoryCount then
        return self.kalmanConfig.baseMeasurementNoise
    end

    local stdDev = computeStdDev(history, component or "strafeDelta")
    if not stdDev then
        return self.kalmanConfig.baseMeasurementNoise
    end

    -- Measurement noise R = (stdDev)^2 + baseline noise.
    return (stdDev * stdDev) + self.kalmanConfig.baseMeasurementNoise
end

--------------------------------------------------------------------------------
-- Calculate dynamic process noise (Q) using the sample variance.
--------------------------------------------------------------------------------
function HistoryHandler:calculateDynamicProcessNoise(entityIndex, component)
    local history = self.histories[entityIndex]
    if not history or #history < self.kalmanConfig.minimumHistoryCount then
        return self.kalmanConfig.processNoise
    end

    local stdDev = computeStdDev(history, component or "strafeDelta")
    if not stdDev then
        return self.kalmanConfig.processNoise
    end

    -- Process noise Q = (stdDev)^2 + base process noise.
    return (stdDev * stdDev) + self.kalmanConfig.processNoise
end

--------------------------------------------------------------------------------
-- Generic Kalman update for any motion component
--------------------------------------------------------------------------------
function HistoryHandler:kalmanUpdate(entityIndex, measurement, component, filterTable)
    local filter = filterTable[entityIndex]
    if not filter then
        filter = {
            x = measurement,                            -- initial state
            p = 1,                                      -- initial error covariance
            q = self.kalmanConfig.processNoise,         -- process noise (will be updated dynamically)
            r = self.kalmanConfig.baseMeasurementNoise, -- measurement noise (updated dynamically)
            k = 0,                                      -- Kalman gain (to be computed)
        }
        filterTable[entityIndex] = filter
    end

    -- Update process and measurement noise dynamically
    filter.q = self:calculateDynamicProcessNoise(entityIndex, component)
    filter.r = self:calculateDynamicMeasurementNoise(entityIndex, component)

    -- Predict step: increase the error covariance
    filter.p = filter.p + filter.q

    -- Update step: compute Kalman gain, update the state, and reduce covariance
    filter.k = filter.p / (filter.p + filter.r)
    filter.x = filter.x + filter.k * (measurement - filter.x)
    filter.p = (1 - filter.k) * filter.p

    return filter.x
end

--------------------------------------------------------------------------------
-- Kalman update for strafeDelta (backward compatibility)
--------------------------------------------------------------------------------
function HistoryHandler:kalmanUpdateDelta(entityIndex, measurement)
    return self:kalmanUpdate(entityIndex, measurement, "strafeDelta", self.kalmanFiltersDelta)
end

--------------------------------------------------------------------------------
-- Retrieve weighted motion data for a given entity
--------------------------------------------------------------------------------
function HistoryHandler:getWeightedMotionData(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history == 0 then
        return {
            strafeDelta = 0,
            acceleration = Vector3(0, 0, 0),
            jerk = Vector3(0, 0, 0),
            predictabilityScore = 1.0
        }
    end

    local mostRecent = history[1]
    local weightedData = {
        strafeDelta = self:kalmanUpdateDelta(entityIndex, mostRecent.strafeDelta or 0),
        acceleration = mostRecent.acceleration or Vector3(0, 0, 0),
        jerk = mostRecent.jerk or Vector3(0, 0, 0),
        snap = mostRecent.snap or Vector3(0, 0, 0),
        pop = mostRecent.pop or Vector3(0, 0, 0),
        predictabilityScore = self:calculatePredictabilityScore(entityIndex)
    }

    -- Apply Kalman filtering to vector magnitudes for acceleration and jerk
    if mostRecent.acceleration then
        local accelMag = mostRecent.acceleration:Length()
        weightedData.accelerationMagnitude = self:kalmanUpdate(entityIndex, accelMag, "acceleration",
            self.kalmanFiltersAccel)
    end

    if mostRecent.jerk then
        local jerkMag = mostRecent.jerk:Length()
        weightedData.jerkMagnitude = self:kalmanUpdate(entityIndex, jerkMag, "jerk", self.kalmanFiltersJerk)
    end

    return weightedData
end

--------------------------------------------------------------------------------
-- Retrieve a weighted (smoothed) strafe delta for a given entity (backward compatibility)
--------------------------------------------------------------------------------
function HistoryHandler:getWeightedStrafeDelta(entityIndex)
    local motionData = self:getWeightedMotionData(entityIndex)
    return motionData.strafeDelta
end

--------------------------------------------------------------------------------
-- Check if a player is a valid target for history tracking.
--------------------------------------------------------------------------------
function HistoryHandler:isValidTarget(player)
    return player and player:IsAlive() and not player:IsDormant()
end

--------------------------------------------------------------------------------
-- Update history for all valid targets with comprehensive motion tracking
--------------------------------------------------------------------------------
function HistoryHandler:update()
    local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")
    -- MAJOR OPTIMIZATION: Only process enemies, not all players
    local players = FastPlayers.GetEnemies()
    local currentTime = globals.RealTime()

    for _, player in pairs(players) do
        local playerRaw = player._rawEntity
        if self:isValidTarget(playerRaw) then
            local entityIndex = playerRaw:GetIndex()

            -- Get current motion data
            local currentPos = playerRaw:GetAbsOrigin()
            local currentVel = playerRaw:EstimateAbsVelocity()

            -- Initialize tracking data if not present
            if not self.lastPositions[entityIndex] then
                self.lastPositions[entityIndex] = currentPos
                self.lastVelocities[entityIndex] = currentVel
                self.lastAccelerations[entityIndex] = Vector3(0, 0, 0)
                self.lastJerks[entityIndex] = Vector3(0, 0, 0)
                self.lastSnaps[entityIndex] = Vector3(0, 0, 0)
                goto continue
            end

            -- Calculate only basic motion data for performance
            local dt = globals.TickInterval()

            -- Calculate acceleration (change in velocity)
            local acceleration = (currentVel - self.lastVelocities[entityIndex]) / dt

            -- SIMPLIFIED: Only calculate jerk, skip snap and pop for performance
            local jerk = (acceleration - self.lastAccelerations[entityIndex]) / dt

            -- Calculate strafe delta (change in velocity angle) - simplified
            local strafeDelta = 0
            if currentVel:Length() > 10 and self.lastVelocities[entityIndex]:Length() > 10 then
                local currentAngle = currentVel:Angles().y
                local lastAngle = self.lastVelocities[entityIndex]:Angles().y
                strafeDelta = currentAngle - lastAngle

                -- Normalize strafe delta to [-180, 180]
                while strafeDelta > 180 do strafeDelta = strafeDelta - 360 end
                while strafeDelta < -180 do strafeDelta = strafeDelta + 360 end
            end

            -- Create simplified motion data sample
            local motionSample = {
                strafeDelta = strafeDelta,
                velocity = currentVel,
                acceleration = acceleration,
                jerk = jerk,
                timestamp = currentTime,
                position = currentPos
            }

            -- Insert the new sample at the beginning of the history
            self.histories[entityIndex] = self.histories[entityIndex] or {}
            table.insert(self.histories[entityIndex], 1, motionSample)

            -- Trim history to max length
            if #self.histories[entityIndex] > self.maxHistoryTicks then
                table.remove(self.histories[entityIndex])
            end

            -- Update last values for next iteration
            self.lastPositions[entityIndex] = currentPos
            self.lastVelocities[entityIndex] = currentVel
            self.lastAccelerations[entityIndex] = acceleration
            self.lastJerks[entityIndex] = jerk
            -- Skip snap update for performance

            -- Get simplified motion data and store in global history
            local weightedMotion = self:getSimplifiedMotionData(entityIndex)
            G.history[entityIndex] = weightedMotion

            ::continue::
        end
    end
end

--------------------------------------------------------------------------------
-- Retrieve simplified motion data for a given entity (performance optimized)
--------------------------------------------------------------------------------
function HistoryHandler:getSimplifiedMotionData(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history == 0 then
        return {
            strafeDelta = 0,
            acceleration = Vector3(0, 0, 0),
            jerk = Vector3(0, 0, 0),
            predictabilityScore = 1.0
        }
    end

    local mostRecent = history[1]

    -- SIMPLIFIED: Skip expensive Kalman filtering for performance
    local weightedData = {
        strafeDelta = mostRecent.strafeDelta or 0,
        acceleration = mostRecent.acceleration or Vector3(0, 0, 0),
        jerk = mostRecent.jerk or Vector3(0, 0, 0),
        predictabilityScore = self:getSimplePredictabilityScore(entityIndex)
    }

    return weightedData
end

--------------------------------------------------------------------------------
-- Simplified predictability score calculation (performance optimized)
--------------------------------------------------------------------------------
function HistoryHandler:getSimplePredictabilityScore(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history < 3 then
        return 1.0 -- High unpredictability if insufficient data
    end

    -- Use more samples for stable analysis (up to 50 samples instead of 5)
    local recentSamples = math.min(#history, 50) -- Check up to 50 samples for stability
    local strafeDeltaSum = 0
    local accelSum = 0
    local jerkSum = 0

    for i = 1, recentSamples do
        local sample = history[i]
        if sample then
            if sample.strafeDelta then
                strafeDeltaSum = strafeDeltaSum + math.abs(sample.strafeDelta)
            end
            if sample.acceleration then
                accelSum = accelSum + sample.acceleration:Length()
            end
            if sample.jerk then
                jerkSum = jerkSum + sample.jerk:Length()
            end
        end
    end

    local avgStrafeDelta = strafeDeltaSum / recentSamples
    local avgAccel = accelSum / recentSamples
    local avgJerk = jerkSum / recentSamples

    -- Combined predictability score using multiple motion components
    local predictabilityScore = (
        math.min(avgStrafeDelta / 45.0, 1.0) * 0.4 + -- Strafe: 40%
        math.min(avgAccel / 200.0, 1.0) * 0.35 +     -- Acceleration: 35%
        math.min(avgJerk / 500.0, 1.0) * 0.25        -- Jerk: 25%
    )

    return predictabilityScore
end

--------------------------------------------------------------------------------
-- Update the maximum history length from config
--------------------------------------------------------------------------------
function HistoryHandler:updateMaxHistoryFromConfig()
    local Config = require("PAimbot.Config")
    local newMaxHistory = Config.advanced.maxPredictionHistory or 66
    -- Clamp to valid range (7-198)
    self.maxHistoryTicks = math.max(7, math.min(198, newMaxHistory))
end

--------------------------------------------------------------------------------
-- Update history for specific targets (called by BestTarget.UpdateHistory)
--------------------------------------------------------------------------------
function HistoryHandler:updateTarget(player)
    if not self:isValidTarget(player) then
        return
    end

    -- Update max history from config (in case it changed)
    self:updateMaxHistoryFromConfig()

    local entityIndex = player:GetIndex()
    local currentTick = globals.TickCount()

    -- Get current motion data
    local currentPos = player:GetAbsOrigin()
    local currentVel = player:EstimateAbsVelocity()

    -- Initialize tracking data if not present
    if not self.lastPositions[entityIndex] then
        self.lastPositions[entityIndex] = currentPos
        self.lastVelocities[entityIndex] = currentVel
        self.lastAccelerations[entityIndex] = Vector3(0, 0, 0)
        self.lastJerks[entityIndex] = Vector3(0, 0, 0)
        self.lastSnaps[entityIndex] = Vector3(0, 0, 0)
        return
    end

    -- Calculate only basic motion data for performance
    local dt = globals.TickInterval()

    -- Calculate acceleration (change in velocity)
    local acceleration = (currentVel - self.lastVelocities[entityIndex]) / dt

    -- SIMPLIFIED: Only calculate jerk, skip snap and pop for performance
    local jerk = (acceleration - self.lastAccelerations[entityIndex]) / dt

    -- Calculate strafe delta (change in velocity angle) - simplified
    local strafeDelta = 0
    if currentVel:Length() > 10 and self.lastVelocities[entityIndex]:Length() > 10 then
        local currentAngle = currentVel:Angles().y
        local lastAngle = self.lastVelocities[entityIndex]:Angles().y
        strafeDelta = currentAngle - lastAngle

        -- Normalize strafe delta to [-180, 180]
        while strafeDelta > 180 do strafeDelta = strafeDelta - 360 end
        while strafeDelta < -180 do strafeDelta = strafeDelta + 360 end
    end

    -- Create simplified motion data sample with TICK COUNT (not time)
    local motionSample = {
        strafeDelta = strafeDelta,
        velocity = currentVel,
        acceleration = acceleration,
        jerk = jerk,
        tick = currentTick, -- Store by tick count, not time
        position = currentPos
    }

    -- Insert the new sample at the beginning of the history
    self.histories[entityIndex] = self.histories[entityIndex] or {}
    table.insert(self.histories[entityIndex], 1, motionSample)

    -- Trim history to max length (by tick count limit, not time)
    if #self.histories[entityIndex] > self.maxHistoryTicks then
        table.remove(self.histories[entityIndex])
    end

    -- Update last values for next iteration
    self.lastPositions[entityIndex] = currentPos
    self.lastVelocities[entityIndex] = currentVel
    self.lastAccelerations[entityIndex] = acceleration
    self.lastJerks[entityIndex] = jerk

    -- Get simplified motion data and store in global history
    local weightedMotion = self:getSimplifiedMotionData(entityIndex)
    G.history[entityIndex] = weightedMotion
end

--------------------------------------------------------------------------------
-- Clear history for a specific target
--------------------------------------------------------------------------------
function HistoryHandler:clearTarget(player)
    local entityIndex = player:GetIndex()

    -- Clear all tracking data for this target
    self.histories[entityIndex] = nil
    self.lastPositions[entityIndex] = nil
    self.lastVelocities[entityIndex] = nil
    self.lastAccelerations[entityIndex] = nil
    self.lastJerks[entityIndex] = nil
    self.lastSnaps[entityIndex] = nil

    -- Clear Kalman filters
    self.kalmanFiltersDelta[entityIndex] = nil
    self.kalmanFiltersAccel[entityIndex] = nil
    self.kalmanFiltersJerk[entityIndex] = nil

    -- Clear global history
    G.history[entityIndex] = nil
end

--------------------------------------------------------------------------------
-- Create and return the singleton instance.
--------------------------------------------------------------------------------
local historyHandlerInstance = setmetatable({}, HistoryHandler)
historyHandlerInstance:init()

return historyHandlerInstance
