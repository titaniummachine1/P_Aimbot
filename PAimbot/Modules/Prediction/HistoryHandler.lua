---@class HistoryHandler
local HistoryHandler = {}
HistoryHandler.__index = HistoryHandler

local G = require("PAimbot.Globals")

-- Initialize the module and prepare storage for history
function HistoryHandler:init()
    self.histories = {} ---@type table<number, table<number, {strafeDelta: number, accelDelta: number}>>
    self.maxHistoryTicks = G.Menu.Advanced.HistoryTicks or 4 -- Number of history ticks to consider
    self.lastSpeeds = {} ---@type table<number, number>
    self.lastVelocities = {} ---@type table<number, number> -- Stores the last velocity angle.y
    G.history = {} -- Initialize the global history table
end

-- Logarithmic scaling function for smoothing strafe delta
local function logarithmicWeight(index, maxIndex)
    if maxIndex <= 1 then return 1 end
    local scale = math.log(maxIndex) - math.log(index + 1)
    return scale / math.log(maxIndex)
end

-- Calculate weighted strafe deltas using logarithmic scaling for a specific entity
function HistoryHandler:getWeightedStrafeDelta(entityIndex)
    local weightedStrafeDelta = 0
    local history = self.histories[entityIndex]

    if not history then return 0 end

    local maxIndex = #history

    for i, delta in ipairs(history) do
        local weight = logarithmicWeight(i, maxIndex)
        weightedStrafeDelta = weightedStrafeDelta + (delta.strafeDelta * weight)
    end

    return weightedStrafeDelta
end

-- Check if a player is a valid target (alive, not dormant)
function HistoryHandler:isValidTarget(player)
    return player and player:IsAlive() and not player:IsDormant()
end

-- Update history with new deltas for all valid targets
function HistoryHandler:updateAllValidTargets()
    local players = entities.FindByClass("CTFPlayer")

    -- Iterate through all players to determine valid targets and update their history
    for _, player in pairs(players) do
        if self:isValidTarget(player) then
            local entityIndex = player:GetIndex()
            local velocity = player:EstimateAbsVelocity()
            local speed = velocity:Length()

            -- Initialize last recorded speed and velocity if not already set
            if not self.lastSpeeds[entityIndex] then
                self.lastSpeeds[entityIndex] = speed
                self.lastVelocities[entityIndex] = velocity:Angles().y
            end

            -- Calculate acceleration delta (speed difference from the last tick)
            local accelDelta = speed - self.lastSpeeds[entityIndex]
            self.lastSpeeds[entityIndex] = speed

            -- Handle edge case for deceleration (when player is stopping)
            if speed == 0 then
                accelDelta = -self.lastSpeeds[entityIndex] -- Deceleration to a full stop
            end

            -- Ensure small deltas are handled properly (optional)
            if math.abs(accelDelta) < 0.01 then
                accelDelta = 0
            end

            -- Calculate strafe delta (angle difference from the last tick)
            local currentVelocityAngle = velocity:Angles().y
            local strafeDelta = currentVelocityAngle - self.lastVelocities[entityIndex]
            self.lastVelocities[entityIndex] = currentVelocityAngle

            -- Initialize history for this entity if it doesn't exist
            if not self.histories[entityIndex] then
                self.histories[entityIndex] = {}
            end

            -- Insert new strafe delta and accel delta into history for this entity
            table.insert(self.histories[entityIndex], 1, { strafeDelta = strafeDelta, accelDelta = accelDelta })
            if #self.histories[entityIndex] > self.maxHistoryTicks then
                table.remove(self.histories[entityIndex])
            end

            -- Calculate the weighted strafe delta
            local weightedStrafeDelta = self:getWeightedStrafeDelta(entityIndex)

            -- Store the weighted strafe delta and raw accel delta in the global history
            G.history[entityIndex] = {
                strafeDelta = weightedStrafeDelta,
                accelDelta = math.max(0, accelDelta) -- No smoothing for accelDelta
            }
        end
    end
end

-- Initialize the module
local historyHandlerInstance = setmetatable({}, HistoryHandler)
historyHandlerInstance:init()

return historyHandlerInstance
