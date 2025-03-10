---@class HistoryHandler
local HistoryHandler = {}
HistoryHandler.__index = HistoryHandler

local G = require("PAimbot.Globals")
local Config = require("PAimbot.Config")

--------------------------------------------------------------------------------
-- Kalman Filter Configuration
--------------------------------------------------------------------------------
HistoryHandler.kalmanConfig = {
    processNoise = 0.7,              -- Base process noise (Q)
    baseMeasurementNoise = 0.05,   -- Base measurement noise (R)
    minimumHistoryCount = 4,       -- Minimum sample count for dynamic noise computation
}

--------------------------------------------------------------------------------
-- Initialize HistoryHandler storage
--------------------------------------------------------------------------------
function HistoryHandler:init()
    -- Table to store raw strafe delta samples per entity:
    -- histories[entityIndex] = { {strafeDelta = value}, ... }
    self.histories = {}
    
    -- For computing the difference between successive velocity angles.
    self.lastVelocities = {} -- last recorded angle for each entity
    
    -- (Optional) Last delta value (if needed for further computations)
    self.lastDelta = {} 

    -- Maximum number of history samples to store per entity.
    self.maxHistoryTicks = Config.advanced.HistoryTicks or 4

    -- Table of Kalman filters for smoothing each entity’s strafe delta.
    self.kalmanFiltersDelta = {} 

    -- Clear the global history table.
    G.history = {}
end

--------------------------------------------------------------------------------
-- Compute sample standard deviation of strafeDelta from a history table.
--------------------------------------------------------------------------------
local function computeStdDev(history)
    if not history or #history < 2 then 
        return nil 
    end

    local sum = 0
    for _, data in ipairs(history) do
        sum = sum + data.strafeDelta
    end
    local mean = sum / #history

    local varianceSum = 0
    for _, data in ipairs(history) do
        local diff = data.strafeDelta - mean
        varianceSum = varianceSum + diff * diff
    end

    local sampleVariance = varianceSum / (#history - 1)
    return math.sqrt(sampleVariance)
end

--------------------------------------------------------------------------------
-- Calculate dynamic measurement noise (R) using the sample variance.
--------------------------------------------------------------------------------
function HistoryHandler:calculateDynamicMeasurementNoise(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history < self.kalmanConfig.minimumHistoryCount then
        return self.kalmanConfig.baseMeasurementNoise
    end

    local stdDev = computeStdDev(history)
    if not stdDev then
        return self.kalmanConfig.baseMeasurementNoise
    end

    -- Measurement noise R = (stdDev)^2 + baseline noise.
    return (stdDev * stdDev) + self.kalmanConfig.baseMeasurementNoise
end

--------------------------------------------------------------------------------
-- Calculate dynamic process noise (Q) using the sample variance.
--------------------------------------------------------------------------------
function HistoryHandler:calculateDynamicProcessNoise(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history < self.kalmanConfig.minimumHistoryCount then
        return self.kalmanConfig.processNoise
    end

    local stdDev = computeStdDev(history)
    if not stdDev then
        return self.kalmanConfig.processNoise
    end

    -- Process noise Q = (stdDev)^2 + base process noise.
    return (stdDev * stdDev) + self.kalmanConfig.processNoise
end

--------------------------------------------------------------------------------
-- Kalman update for strafeDelta for a given entity.
-- This function smooths the raw measurement (most recent sample) using a simple
-- Kalman filter.
--------------------------------------------------------------------------------
function HistoryHandler:kalmanUpdateDelta(entityIndex, measurement)
    local filter = self.kalmanFiltersDelta[entityIndex]
    if not filter then
        filter = {
            x = measurement,        -- initial state
            p = 1,                  -- initial error covariance
            q = self.kalmanConfig.processNoise,  -- process noise (will be updated dynamically)
            r = self.kalmanConfig.baseMeasurementNoise, -- measurement noise (updated dynamically)
            k = 0,                  -- Kalman gain (to be computed)
        }
        self.kalmanFiltersDelta[entityIndex] = filter
    end

    -- Update process and measurement noise dynamically.
    filter.q = self:calculateDynamicProcessNoise(entityIndex)
    filter.r = self:calculateDynamicMeasurementNoise(entityIndex)

    -- Predict step: increase the error covariance.
    filter.p = filter.p + filter.q

    -- Update step: compute Kalman gain, update the state, and reduce covariance.
    filter.k = filter.p / (filter.p + filter.r)
    filter.x = filter.x + filter.k * (measurement - filter.x)
    filter.p = (1 - filter.k) * filter.p

    return filter.x
end

--------------------------------------------------------------------------------
-- Retrieve a weighted (smoothed) strafe delta for a given entity.
-- Uses the most recent sample and runs it through the Kalman filter.
--------------------------------------------------------------------------------
function HistoryHandler:getWeightedStrafeDelta(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history == 0 then
        return 0
    end

    local mostRecentDelta = history[1].strafeDelta
    return self:kalmanUpdateDelta(entityIndex, mostRecentDelta)
end

--------------------------------------------------------------------------------
-- Check if a player is a valid target for history tracking.
--------------------------------------------------------------------------------
function HistoryHandler:isValidTarget(player)
    return player and player:IsAlive() and not player:IsDormant()
end

--------------------------------------------------------------------------------
-- Update history for all valid targets.
-- For each valid player, compute the change in velocity angle and store it.
-- Then, smooth the sample using the Kalman filter and save the result globally.
--------------------------------------------------------------------------------
function HistoryHandler:update()
    local players = entities.FindByClass("CTFPlayer")
    for _, player in pairs(players) do
        if self:isValidTarget(player) then
            local entityIndex = player:GetIndex()
            local velocity = player:EstimateAbsVelocity()

            -- Initialize last recorded velocity angle if not present.
            if not self.lastVelocities[entityIndex] then
                self.lastVelocities[entityIndex] = velocity:Angles().y
            end

            local currentAngle = velocity:Angles().y
            local strafeDelta = currentAngle - self.lastVelocities[entityIndex]
            self.lastVelocities[entityIndex] = currentAngle

            -- Insert the new strafe delta sample at the beginning of the history.
            self.histories[entityIndex] = self.histories[entityIndex] or {}
            table.insert(self.histories[entityIndex], 1, { strafeDelta = strafeDelta })
            if #self.histories[entityIndex] > self.maxHistoryTicks then
                table.remove(self.histories[entityIndex])
            end

            -- Compute a smoothed strafe delta.
            local filteredDelta = self:getWeightedStrafeDelta(entityIndex)

            -- Save the smoothed value in the global history table.
            G.history[entityIndex] = {
                strafeDelta = filteredDelta
            }
        end
    end
end

--------------------------------------------------------------------------------
-- Create and return the singleton instance.
--------------------------------------------------------------------------------
local historyHandlerInstance = setmetatable({}, HistoryHandler)
historyHandlerInstance:init()

return historyHandlerInstance
