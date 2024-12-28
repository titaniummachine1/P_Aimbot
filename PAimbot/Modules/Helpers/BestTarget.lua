local BestTarget = {}

local Common = require("PAimbot.Common")
local G = require("PAimbot.Globals")
local eyeOffset = Vector3(0, 0, 75)

-- Utility function to check if a table contains a specific value
local function TableContains(tbl, value)
    for _, v in ipairs(tbl) do
        if v == value then
            return true
        end
    end
    return false
end

-- Checks if a player should be considered as a valid target
local function IsValidTarget(me, player)
    return player and player:IsAlive()
        and not player:IsDormant()
        and player == me
        and (gui.GetValue("ignore cloaked") == 0 or not player:InCond(4))
end

-- Logarithmic scaling for distance
local function LogarithmicDistanceFactor(distance)
    return math.log(distance + 1) -- Ensures we don't hit log(0)
end

-- Calculates the selection factor for a potential target based on distance, FOV, and visibility
local function CalculateTargetFactor(player, localPlayerOrigin, localPlayerViewAngles)
    local playerOrigin = player:GetAbsOrigin()
    local distance = (playerOrigin - localPlayerOrigin):Length2D()

    local angles = Common.Math.PositionAngles(localPlayerOrigin, playerOrigin)
    local fov = Common.Math.AngleFov(angles, localPlayerViewAngles)

    if fov > G.Menu.Main.AimFov then
        return 0
    end

    local distanceFactor = 1 / LogarithmicDistanceFactor(distance)
    local fovFactor = Common.Math.RemapValClamped(fov, 0, G.Menu.Main.AimFov, 1, 0.7)
    local isVisible = Common.Helpers.VisPos(player, localPlayerOrigin + eyeOffset, playerOrigin + eyeOffset)
    local visibilityFactor = isVisible and 1 or 0.5

    return fovFactor * visibilityFactor * distanceFactor
end

-- Main function to find the best target (backward compatible)
function BestTarget.Get(me)
    local players = entities.FindByClass("CTFPlayer")
    local bestTarget = nil
    local bestFactor = 0
    local localPlayerOrigin = me:GetAbsOrigin()
    local localPlayerViewAngles = engine.GetViewAngles()

    for _, player in pairs(players) do
        if IsValidTarget(me, player) then
            local factor = CalculateTargetFactor(player, localPlayerOrigin, localPlayerViewAngles)
            if factor > bestFactor then
                bestTarget = player
                bestFactor = factor
            end
        end
    end

    G.Target = bestTarget --visuals and updater data
    return bestTarget
end

-- Function to find the top 3 best targets for history update
function BestTarget.UpdateHistory(me)
    local players = entities.FindByClass("CTFPlayer")
    local localPlayerOrigin = me:GetAbsOrigin()
    local topTargets = {}

    -- Iterate through all players to determine valid targets
    for _, player in pairs(players) do
        if IsValidTarget(me, player) then
            local factor = CalculateTargetFactor(player, localPlayerOrigin, engine.GetViewAngles())
            table.insert(topTargets, { player = player, factor = factor })
        end
    end

    -- Sort targets based on their calculated factor (descending)
    table.sort(topTargets, function(a, b) return a.factor > b.factor end)

    -- Keep only the top 3 targets
    while #topTargets > 3 do
        table.remove(topTargets)
    end

    -- Get the list of top players
    local topPlayers = {}
    for _, target in ipairs(topTargets) do
        local player = target.player
        local playerIndex = player:GetIndex()

        table.insert(topPlayers, playerIndex)

        -- Update the history for the top players
        HistoryHandler:update(player, topPlayers)

        -- Calculate the weighted deltas from the history
        local weightedStrafeDelta, weightedAccelDelta = HistoryHandler:getWeightedDeltas(player)

        -- Store the calculated deltas in G.predictionDelta without overwriting the history
        G.predictionDelta[playerIndex] = {
            strafeDelta = weightedStrafeDelta,
            accelDelta = weightedAccelDelta
        }
    end

    -- Clear history for any player not in the top 3
    for _, player in pairs(players) do
        if not TableContains(topPlayers, player:GetIndex()) then
            HistoryHandler:clearHistory(player)
        end
    end

    -- Optionally print or return the top players
    return topPlayers
end

return BestTarget
