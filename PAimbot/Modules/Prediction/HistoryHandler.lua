---@class HistoryHandler
local HistoryHandler = {}
HistoryHandler.__index = HistoryHandler

local G = require("PAimbot.Globals")

--------------------------------------------------------------------------------
-- Configuration
--------------------------------------------------------------------------------
HistoryHandler.kalmanConfig = {
    processNoise       = 0.7,  -- Q for strafeDelta
    processNoiseAcc    = 0.1,  -- Q for acceleration
    baseMeasurementNoise   = 0.05, -- R baseline for strafeDelta
    baseMeasurementNoiseAcc= 0.05, -- R baseline for acceleration
    minimumHistoryCount    = 4,    -- Only compute std if at least x samples
}

--------------------------------------------------------------------------------
-- Initialize the module and prepare storage
--------------------------------------------------------------------------------
function HistoryHandler:init()
    self.histories       = {} -- table<number, table<number, {strafeDelta: number}>>
    self.accHistories    = {} -- table<number, table<number, {acc: number}>>
    self.lastVelocities  = {} -- table<number, number>
    self.lastDelta       = {} -- table<number, number> (used to compute acceleration)
    self.maxHistoryTicks = G.Menu.Advanced.HistoryTicks or 4

    -- Kalman filters for strafeDelta and acceleration
    self.kalmanFiltersDelta = {} -- table<number, { x=..., p=..., ... }>
    self.kalmanFiltersAcc   = {} -- table<number, { x=..., p=..., ... }>

    G.history = {} -- Global table storing final results
end

--------------------------------------------------------------------------------
-- Standard deviation utility for strafeDelta or acceleration
--------------------------------------------------------------------------------
local function computeStdDev(history, key)
    if not history or #history < 2 then return nil end

    -- 1) Compute mean
    local sum = 0
    for _, data in ipairs(history) do
        sum = sum + data[key]
    end
    local mean = sum / #history

    -- 2) Compute variance
    local varianceSum = 0
    for _, data in ipairs(history) do
        local diff = data[key] - mean
        varianceSum = varianceSum + diff * diff
    end
    local variance = varianceSum / (#history - 1)
    return math.sqrt(variance) -- std dev
end

--------------------------------------------------------------------------------
-- Dynamic R (measurement noise) for strafeDelta
--------------------------------------------------------------------------------
function HistoryHandler:calculateDynamicMeasurementNoiseDelta(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history < self.kalmanConfig.minimumHistoryCount then
        return self.kalmanConfig.baseMeasurementNoise
    end

    local stdDev = computeStdDev(history, "strafeDelta")
    if not stdDev then
        return self.kalmanConfig.baseMeasurementNoise
    end
    -- R = std^2 + baseline
    return (stdDev * stdDev) + self.kalmanConfig.baseMeasurementNoise
end

--------------------------------------------------------------------------------
-- Dynamic R (measurement noise) for acceleration
--------------------------------------------------------------------------------
function HistoryHandler:calculateDynamicMeasurementNoiseAcc(entityIndex)
    local history = self.accHistories[entityIndex]
    if not history or #history < self.kalmanConfig.minimumHistoryCount then
        return self.kalmanConfig.baseMeasurementNoiseAcc
    end

    local stdDev = computeStdDev(history, "acc")
    if not stdDev then
        return self.kalmanConfig.baseMeasurementNoiseAcc
    end
    -- R = std^2 + baseline
    return (stdDev * stdDev) + self.kalmanConfig.baseMeasurementNoiseAcc
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
            q = self.kalmanConfig.processNoise,
            r = self.kalmanConfig.baseMeasurementNoise,
            k = 0,
        }
        self.kalmanFiltersDelta[entityIndex] = filter
    end

    -- Dynamically compute measurement noise for strafeDelta
    filter.r = self:calculateDynamicMeasurementNoiseDelta(entityIndex)

    -- Predict
    filter.p = filter.p + filter.q

    -- Update
    filter.k = filter.p / (filter.p + filter.r)
    filter.x = filter.x + filter.k * (measurement - filter.x)
    filter.p = (1 - filter.k) * filter.p

    return filter.x
end

--------------------------------------------------------------------------------
-- Kalman update for acceleration
--------------------------------------------------------------------------------
function HistoryHandler:kalmanUpdateAcc(entityIndex, measurement)
    local filter = self.kalmanFiltersAcc[entityIndex]
    if not filter then
        filter = {
            x = measurement, -- initial state
            p = 1,
            q = self.kalmanConfig.processNoiseAcc,
            r = self.kalmanConfig.baseMeasurementNoiseAcc,
            k = 0,
        }
        self.kalmanFiltersAcc[entityIndex] = filter
    end

    -- Dynamically compute measurement noise for acceleration
    filter.r = self:calculateDynamicMeasurementNoiseAcc(entityIndex)

    -- Predict
    filter.p = filter.p + filter.q

    -- Update
    filter.k = filter.p / (filter.p + filter.r)
    filter.x = filter.x + filter.k * (measurement - filter.x)
    filter.p = (1 - filter.k) * filter.p

    return filter.x
end

--------------------------------------------------------------------------------
-- getWeightedStrafeDelta: same usage as before, but uses the new Kalman filter
--------------------------------------------------------------------------------
function HistoryHandler:getWeightedStrafeDelta(entityIndex)
    local history = self.histories[entityIndex]
    if not history or #history == 0 then
        return 0
    end
    -- We'll feed the latest strafeDelta to the delta filter
    local latestDelta = history[1].strafeDelta
    return self:kalmanUpdateDelta(entityIndex, latestDelta)
end

--------------------------------------------------------------------------------
-- getAcceleration: compute & filter acceleration
--------------------------------------------------------------------------------
function HistoryHandler:getAcceleration(entityIndex)
    local accHistory = self.accHistories[entityIndex]
    if not accHistory or #accHistory == 0 then
        return 0
    end
    -- The newest acceleration measurement
    local latestAcc = accHistory[1].acc
    return self:kalmanUpdateAcc(entityIndex, latestAcc)
end

--------------------------------------------------------------------------------
-- Valid target check
--------------------------------------------------------------------------------
function HistoryHandler:isValidTarget(player)
    return player and player:IsAlive() and not player:IsDormant()
end

--------------------------------------------------------------------------------
-- updateAllValidTargets: main logic to fill history arrays and produce filtered results
--------------------------------------------------------------------------------
function HistoryHandler:updateAllValidTargets()
    local players = entities.FindByClass("CTFPlayer")

    for _, player in pairs(players) do
        if self:isValidTarget(player) then
            local entityIndex = player:GetIndex()
            local velocity = player:EstimateAbsVelocity()

            -- If we have no recorded velocity, initialize
            if not self.lastVelocities[entityIndex] then
                self.lastVelocities[entityIndex] = velocity:Angles().y
            end

            local currentVelocityAngle = velocity:Angles().y
            local strafeDelta = currentVelocityAngle - self.lastVelocities[entityIndex]
            self.lastVelocities[entityIndex] = currentVelocityAngle

            -- 1) Insert strafeDelta into history
            self.histories[entityIndex] = self.histories[entityIndex] or {}
            table.insert(self.histories[entityIndex], 1, { strafeDelta = strafeDelta })
            if #self.histories[entityIndex] > self.maxHistoryTicks then
                table.remove(self.histories[entityIndex])
            end

            -- 2) Compute acceleration = difference between the new strafeDelta and the last
            local prevDelta = self.lastDelta[entityIndex] or strafeDelta
            local acceleration = strafeDelta - prevDelta
            self.lastDelta[entityIndex] = strafeDelta

            -- Insert acceleration into its own history
            self.accHistories[entityIndex] = self.accHistories[entityIndex] or {}
            table.insert(self.accHistories[entityIndex], 1, { acc = acceleration })
            if #self.accHistories[entityIndex] > self.maxHistoryTicks then
                table.remove(self.accHistories[entityIndex])
            end

            -- 3) Get the Kalman-filtered values
            local filteredDelta = self:getWeightedStrafeDelta(entityIndex)
            local filteredAcc   = self:getAcceleration(entityIndex)

            -- 4) Store them in the global table (or wherever else you want)
            G.history[entityIndex] = {
                strafeDelta  = filteredDelta,
                acceleration = filteredAcc
            }
        end
    end
end

--------------------------------------------------------------------------------
-- Initialize the module
--------------------------------------------------------------------------------
local historyHandlerInstance = setmetatable({}, HistoryHandler)
historyHandlerInstance:init()

return historyHandlerInstance
