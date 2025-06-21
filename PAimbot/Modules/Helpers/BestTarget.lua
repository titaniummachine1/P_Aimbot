local BestTarget = {}

local Common = require("PAimbot.Common")
local Config = require("PAimbot.Config")
local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")

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
    -- Check if gui.GetValue exists and is callable, otherwise default to 0
    local ignoreCloaked = 0
    if gui and gui.GetValue and type(gui.GetValue) == "function" then
        ignoreCloaked = gui.GetValue("ignore cloaked") or 0
    end

    return player and player:IsAlive()
        and not player:IsDormant()
        and player ~= me
        and (ignoreCloaked == 0 or not player:InCond(4))
end

-- Logarithmic scaling for distance
local function LogarithmicDistanceFactor(distance)
    return math.log(distance + 1) -- Ensures we don't hit log(0)
end

-- Sophisticated target scoring with health, visibility priority, and movement predictability
local function CalculateTargetFactor(player, localPlayerOrigin, localPlayerViewAngles)
    local playerOrigin = player:GetAbsOrigin()
    local distance = (playerOrigin - localPlayerOrigin):Length2D()

    local angles = Common.Math.PositionAngles(localPlayerOrigin, playerOrigin)
    local fov = Common.Math.AngleFov(angles, localPlayerViewAngles)

    if fov > Config.main.aimfov then
        return 0
    end

    -- Distance factor (closer is better, but not too close)
    local distanceFactor = Common.Math.RemapValClamped(distance,
        Config.main.minDistance or 100,
        Config.main.maxDistance or 3000,
        1.0, 0.1)

    -- FOV factor (smaller FOV is much better)
    local fovFactor = Common.Math.RemapValClamped(fov, 0, Config.main.aimfov, 1.0, 0.3)

    -- Visibility factor (HEAVILY prioritize visible targets)
    local isVisible = Common.Helpers.VisPos(player, localPlayerOrigin + eyeOffset, playerOrigin + eyeOffset)
    local visibilityFactor = isVisible and 1.0 or 0.2 -- Drastic shift for non-visible

    -- Health factor (lower health = higher priority)
    local health = player:GetHealth()
    local maxHealth = player:GetMaxHealth()
    local healthFactor = Common.Math.RemapValClamped(health, 0, maxHealth, 1.2, 0.8)

    -- Movement predictability from history (if available)
    local predictabilityFactor = 1.0
    local playerIndex = player:GetIndex()
    if G.predictionDelta[playerIndex] and G.predictionDelta[playerIndex].entropy then
        local entropy = G.predictionDelta[playerIndex].entropy
        predictabilityFactor = 1.0 - (entropy * 0.3) -- Less penalty for unpredictable movement
    end

    -- Combine factors with sophisticated weighting
    local totalFactor = (distanceFactor * 0.25 + -- Distance: 25%
        fovFactor * 0.30 +                       -- FOV: 30%
        visibilityFactor * 0.30 +                -- Visibility: 30%
        healthFactor * 0.10 +                    -- Health: 10%
        predictabilityFactor * 0.05)             -- Predictability: 5%

    return totalFactor
end

-- Main function to find the best target (backward compatible)
function BestTarget.Get()
    local me = FastPlayers.GetLocal()
    if not me then return nil end

    local players = FastPlayers.GetEnemies()
    local bestTarget = nil
    local bestFactor = 0
    local localPlayerOrigin = me:GetAbsOrigin()
    local localPlayerViewAngles = engine.GetViewAngles()

    for _, player in pairs(players) do
        -- Use the WrappedPlayer instances directly, convert to raw entity only when needed
        local meRaw = me._rawEntity
        local playerRaw = player._rawEntity
        if IsValidTarget(meRaw, playerRaw) then
            local factor = CalculateTargetFactor(playerRaw, localPlayerOrigin, localPlayerViewAngles)
            if factor > bestFactor then
                bestTarget = playerRaw
                bestFactor = factor
            end
        end
    end

    G.Target = bestTarget --visuals and updater data
    return bestTarget
end

-- Advanced entropy calculation with trust factor based on history depth
local function CalculateAdvancedEntropy(player)
    local playerIndex = player:GetIndex()
    if not G.predictionDelta[playerIndex] or not G.predictionDelta[playerIndex].history then
        return { entropy = 0.7, trustFactor = 0.0, samples = 0 } -- Default high entropy, no trust
    end

    local history = G.predictionDelta[playerIndex].history
    local historySize = #history

    if historySize < 3 then
        return { entropy = 0.7, trustFactor = 0.1, samples = historySize }
    end

    -- Use more history for better fidelity (up to 30 frames for very high trust)
    local maxSamples = math.min(historySize, 30)
    local minSamples = math.max(3, maxSamples)

    -- Calculate multiple entropy metrics
    local velocityDeltas = {}
    local angleDeltas = {}
    local accelerationDeltas = {}
    local strafeConsistency = {}

    for i = 2, minSamples do
        local prev = history[i - 1]
        local curr = history[i]

        if prev.velocity and curr.velocity then
            -- Velocity delta (speed changes)
            local velDelta = (curr.velocity - prev.velocity):Length()
            table.insert(velocityDeltas, velDelta)

            -- Acceleration delta (rate of speed change)
            if i > 2 and history[i - 2].velocity then
                local prevVelDelta = (prev.velocity - history[i - 2].velocity):Length()
                local accelDelta = math.abs(velDelta - prevVelDelta)
                table.insert(accelerationDeltas, accelDelta)
            end

            -- Strafe consistency (how consistent is their strafing)
            local currSpeed = curr.velocity:Length2D()
            local prevSpeed = prev.velocity:Length2D()
            if currSpeed > 50 and prevSpeed > 50 then -- Only when actually moving
                local strafeChange = math.abs(currSpeed - prevSpeed) / math.max(currSpeed, prevSpeed)
                table.insert(strafeConsistency, strafeChange)
            end
        end

        if prev.viewAngle and curr.viewAngle then
            -- View angle entropy (mouse movement patterns)
            local yawDelta = math.abs(Common.Math.AngleDifference(curr.viewAngle.y, prev.viewAngle.y))
            local pitchDelta = math.abs(Common.Math.AngleDifference(curr.viewAngle.x, prev.viewAngle.x)) * 0.3
            table.insert(angleDeltas, yawDelta + pitchDelta)
        end
    end

    -- Enhanced standard deviation calculation with outlier detection
    local function calculateAdvancedStdDev(values)
        if #values < 2 then return 0 end

        -- Calculate mean
        local mean = 0
        for _, v in ipairs(values) do
            mean = mean + v
        end
        mean = mean / #values

        -- Calculate variance, but weight recent samples more heavily
        local weightedVariance = 0
        local totalWeight = 0
        for i, v in ipairs(values) do
            local weight = i / #values -- Recent samples get higher weight
            local deviation = (v - mean) ^ 2
            weightedVariance = weightedVariance + (deviation * weight)
            totalWeight = totalWeight + weight
        end
        weightedVariance = weightedVariance / totalWeight

        return math.sqrt(weightedVariance)
    end

    -- Calculate individual entropy components
    local velEntropy = calculateAdvancedStdDev(velocityDeltas) / 150       -- Normalized
    local angleEntropy = calculateAdvancedStdDev(angleDeltas) / 60         -- Normalized
    local accelEntropy = calculateAdvancedStdDev(accelerationDeltas) / 100 -- Normalized
    local strafeEntropy = calculateAdvancedStdDev(strafeConsistency)       -- Already normalized 0-1

    -- Combine entropies with sophisticated weighting
    local combinedEntropy = (
        velEntropy * 0.35 +   -- Movement speed changes: 35%
        angleEntropy * 0.30 + -- View angle changes: 30%
        accelEntropy * 0.20 + -- Acceleration patterns: 20%
        strafeEntropy * 0.15  -- Strafe consistency: 15%
    )

    -- Clamp entropy to reasonable bounds
    combinedEntropy = Common.clamp(combinedEntropy, 0.0, 1.0)

    -- Trust factor based on sample size (more samples = higher trust)
    -- Exponential curve: starts low, rises quickly, then plateaus
    local trustFactor = 1.0 - math.exp(-historySize / 12.0) -- 63% trust at 12 samples, 95% at 36 samples
    trustFactor = Common.clamp(trustFactor, 0.0, 1.0)

    return {
        entropy = combinedEntropy,
        trustFactor = trustFactor,
        samples = historySize,
        components = {
            velocity = velEntropy,
            angle = angleEntropy,
            acceleration = accelEntropy,
            strafe = strafeEntropy
        }
    }
end

-- Sophisticated hit chance calculation based on movement entropy
function BestTarget.CalculateHitChance(player, predictionTicks)
    local playerIndex = player:GetIndex()

    -- Calculate movement entropy (how unpredictable the player is)
    local entropy = CalculateMovementEntropy(player)

    -- Store entropy for target selection
    if not G.predictionDelta[playerIndex] then
        G.predictionDelta[playerIndex] = {}
    end
    G.predictionDelta[playerIndex].entropy = entropy

    -- Base hit chance factors
    local baseHitChance = 80

    -- Distance factor
    local me = entities.GetLocalPlayer()
    local distance = me and (player:GetAbsOrigin() - me:GetAbsOrigin()):Length() or 1000
    local distanceFactor = Common.Math.RemapValClamped(distance, 100, 2000, 15, -10)

    -- Visibility factor
    local eyeOffset = Vector3(0, 0, 75)
    local isVisible = me and
        Common.Helpers.VisPos(player, me:GetAbsOrigin() + eyeOffset, player:GetAbsOrigin() + eyeOffset)
    local visibilityBonus = isVisible and 10 or -15

    -- FOV factor
    if me then
        local angles = Common.Math.PositionAngles(me:GetAbsOrigin(), player:GetAbsOrigin())
        local fov = Common.Math.AngleFov(angles, engine.GetViewAngles())
        local fovBonus = Common.Math.RemapValClamped(fov, 0, Config.main.aimfov or 60, 10, -5)

        -- Entropy penalty (higher entropy = more unpredictable = lower hit chance)
        local entropyPenalty = entropy * 25

        -- Prediction time penalty (longer prediction = less accurate)
        local predictionPenalty = (predictionTicks or 0) * 0.2

        local finalHitChance = baseHitChance + distanceFactor + visibilityBonus + fovBonus - entropyPenalty -
            predictionPenalty
        return Common.clamp(finalHitChance, 10, 95)
    end

    return 50 -- Default if no local player
end

-- Enhanced history update for configurable number of targets (4-8)
function BestTarget.UpdateHistory(me)
    local players = FastPlayers.GetEnemies()
    local localPlayerOrigin = me:GetAbsOrigin()
    local topTargets = {}

    -- Get max targets from config (4-8)
    local maxTargets = Config.advanced.maxTrackedTargets or 8
    maxTargets = Common.clamp(maxTargets, 4, 8)

    -- Iterate through all players to determine valid targets
    for _, player in pairs(players) do
        local playerRaw = player._rawEntity
        if IsValidTarget(me, playerRaw) then
            local factor = CalculateTargetFactor(playerRaw, localPlayerOrigin, engine.GetViewAngles())
            table.insert(topTargets, { player = playerRaw, factor = factor })
        end
    end

    -- Sort targets based on their calculated factor (descending)
    table.sort(topTargets, function(a, b) return a.factor > b.factor end)

    -- Keep only the top N targets
    while #topTargets > maxTargets do
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
        G.predictionDelta[playerIndex] = G.predictionDelta[playerIndex] or {}
        G.predictionDelta[playerIndex].strafeDelta = weightedStrafeDelta
        G.predictionDelta[playerIndex].accelDelta = weightedAccelDelta
    end

    -- Clear history for any player not in the top targets
    for _, player in pairs(players) do
        local playerRaw = player._rawEntity
        if not TableContains(topPlayers, playerRaw:GetIndex()) then
            HistoryHandler:clearHistory(playerRaw)
            -- Clear prediction data for non-tracked players
            if G.predictionDelta[playerRaw:GetIndex()] then
                G.predictionDelta[playerRaw:GetIndex()] = nil
            end
        end
    end

    -- Return the top players for reference
    return topPlayers
end

-- Function to get top N best targets (for optimized prediction)
function BestTarget.GetTopTargets(maxTargets)
    local me = FastPlayers.GetLocal()
    if not me then return {} end

    local players = FastPlayers.GetEnemies()
    local targets = {}
    local localPlayerOrigin = me:GetAbsOrigin()
    local localPlayerViewAngles = engine.GetViewAngles()

    for _, player in pairs(players) do
        -- Use the WrappedPlayer instances directly, convert to raw entity only when needed
        local meRaw = me._rawEntity
        local playerRaw = player._rawEntity
        if IsValidTarget(meRaw, playerRaw) then
            local factor = CalculateTargetFactor(playerRaw, localPlayerOrigin, localPlayerViewAngles)
            if factor > 0 then
                table.insert(targets, { player = playerRaw, factor = factor })
            end
        end
    end

    -- Sort targets by factor (best first)
    table.sort(targets, function(a, b) return a.factor > b.factor end)

    -- Return only the top N targets
    local topTargets = {}
    for i = 1, math.min(maxTargets, #targets) do
        table.insert(topTargets, targets[i].player)
    end

    return topTargets
end

return BestTarget
