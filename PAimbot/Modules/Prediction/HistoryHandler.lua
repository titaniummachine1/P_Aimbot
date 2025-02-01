---@class HistoryHandler
local HistoryHandler = {}
HistoryHandler.__index = HistoryHandler

local G = require("PAimbot.Globals")
local Config = require("PAimbot.Config")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
HistoryHandler.kalmanConfig = {
    -- We now only have processNoise for strafeDelta
    processNoise = 1,
    -- Measurement noise (R)
    baseMeasurementNoise = 0.05,
    -- Minimum number of samples before computing dynamic noise
    minimumHistoryCount = 4,
}

--------------------------------------------------------------------------------
-- Initialize the module and prepare storage
--------------------------------------------------------------------------------
function HistoryHandler:init()
    -- We only track strafeDelta now
    self.histories      = {} -- table<number, table<number, {strafeDelta: number}>>
    self.lastVelocities = {} -- table<number, number>
    self.lastDelta      = {} -- table<number, number> (for computing strafeDelta changes if needed)
    self.maxHistoryTicks = Config.advanced.HistoryTicks or 4

    -- Single Kalman filter table for strafeDelta
    self.kalmanFiltersDelta = {} -- table<number, { x=..., p=..., ... }>

    -- Clear the global results
    G.history = {}
end

--------------------------------------------------------------------------------
-- Standard deviation utility for strafeDelta
--------------------------------------------------------------------------------
local function computeStdDev(history)
    if not history or #history < 2 then return nil end

    -- 1) Compute mean
    local sum = 0
    for _, data in ipairs(history) do
        sum = sum + data.strafeDelta
    end
    local mean = sum / #history

    -- 2) Compute variance
    local varianceSum = 0
    for _, data in ipairs(history) do
        local diff = data.strafeDelta - mean
        varianceSum = varianceSum + diff * diff
    end

    local variance = varianceSum / (#history - 1) -- sample variance
    return math.sqrt(variance)
end

--------------------------------------------------------------------------------
-- Dynamic measurement noise (R) for strafeDelta
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

    -- R = std^2 + baseline
    return (stdDev * stdDev) + self.kalmanConfig.baseMeasurementNoise
end

--------------------------------------------------------------------------------
-- Dynamic process noise (Q) for strafeDelta
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

    -- Example formula: Q = std^2 + baseProcessNoise
    return (stdDev * stdDev) + self.kalmanConfig.processNoise
end

--------------------------------------------------------------------------------
-- Kalman update for strafeDelta
--------------------------------------------------------------------------------
function HistoryHandler:kalmanUpdateDelta(entityIndex, measurement)
    local filter = self.kalmanFiltersDelta[entityIndex]
    if not filter then
        filter = {
            x = measurement, -- initial state
            p = 1,
            -- We'll override q, r below
            q = self.kalmanConfig.processNoise,
            r = self.kalmanConfig.baseMeasurementNoise,
            k = 0,
        }
        self.kalmanFiltersDelta[entityIndex] = filter
    end

    -- Dynamic Q for strafeDelta
    filter.q = self:calculateDynamicProcessNoise(entityIndex)

    -- Dynamic R for strafeDelta
    filter.r = self:calculateDynamicMeasurementNoise(entityIndex)

    -- Predict
    filter.p = filter.p + filter.q

    -- Update
    filter.k = filter.p / (filter.p + filter.r)
    filter.x = filter.x + filter.k * (measurement - filter.x)
    filter.p = (1 - filter.k) * filter.p

    return filter.x
end

--------------------------------------------------------------------------------
-- getWeightedStrafeDelta
--------------------------------------------------------------------------------
function HistoryHandler:getWeightedStrafeDelta(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history == 0 then
        return 0
    end

    -- The most recent strafeDelta
    local latestDelta = history[1].strafeDelta
    return self:kalmanUpdateDelta(entityIndex, latestDelta)
end

--------------------------------------------------------------------------------
-- Valid target check
--------------------------------------------------------------------------------
function HistoryHandler:isValidTarget(player)
    return player and player:IsAlive() and not player:IsDormant()
end

--------------------------------------------------------------------------------
-- updateAllValidTargets
--------------------------------------------------------------------------------
function HistoryHandler:update()
    local players = entities.FindByClass("CTFPlayer")

    for _, player in pairs(players) do
        if self:isValidTarget(player) then
            local entityIndex = player:GetIndex()
            local velocity = player:EstimateAbsVelocity()

            -- If we have no recorded velocity angle, initialize
            if not self.lastVelocities[entityIndex] then
                self.lastVelocities[entityIndex] = velocity:Angles().y
            end

            local currentVelocityAngle = velocity:Angles().y
            local strafeDelta = currentVelocityAngle - self.lastVelocities[entityIndex]
            self.lastVelocities[entityIndex] = currentVelocityAngle

            -- Insert strafeDelta into history
            self.histories[entityIndex] = self.histories[entityIndex] or {}
            table.insert(self.histories[entityIndex], 1, { strafeDelta = strafeDelta })
            if #self.histories[entityIndex] > self.maxHistoryTicks then
                table.remove(self.histories[entityIndex])
            end

            -- Use the Kalman filter to get a smoothed strafeDelta
            local filteredDelta = self:getWeightedStrafeDelta(entityIndex)

            -- Save in the global table
            G.history[entityIndex] = {
                strafeDelta = filteredDelta
            }
        end
    end
end

--------------------------------------------------------------------------------
-- Initialize and return the module
--------------------------------------------------------------------------------
local historyHandlerInstance = setmetatable({}, HistoryHandler)
historyHandlerInstance:init()

return historyHandlerInstance
