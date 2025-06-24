---@diagnostic disable: unused-function
---@diagnostic disable: undefined-global
---@class engine

--[[
    PAimbot lua
    Autor: Titaniummachine1
    Github: https://github.com/Titaniummachine1

    pasted stuff from GoodEveningFellOff - (https://github.com/GoodEveningFellOff/lmaobox-visualize-arc-trajectories)
]]

--[[ Activate the script Modules ]]
local G = require("PAimbot.Globals")
local Common = require("PAimbot.Common")
local Config = require("PAimbot.Config")

--[[Classes]] --
local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")
local BestTarget = require("PAimbot.Modules.Helpers.BestTarget")
local HistoryHandler = require("PAimbot.Modules.Prediction.HistoryHandler")
local Prediction = require("PAimbot.Modules.Prediction.Prediction")
local ProjectileData = require("PAimbot.Modules.ProjectileData")
local ProjectileAimbot = require("PAimbot.Modules.ProjectileAimbot")

require("PAimbot.Modules.Helpers.VariableUpdater")
require("PAimbot.Visuals")
require("PAimbot.Menu")

-- Load configuration
Config:Load()

-- Validate the local player
local function IsValidLocalPlayer(pLocal)
    return pLocal and not pLocal:InCond(7) and pLocal:IsAlive()
end

-- Validate the weapon
local function IsValidWeapon(pWeapon)
    return pWeapon
        and (pWeapon:GetWeaponProjectileType() or 0) > 1
        and (pWeapon:IsShootingWeapon() ~= 1)
end

-- Simple target finder fallback
local function GetSimpleTarget(pLocal)
    local players = FastPlayers.GetEnemies()
    for _, player in pairs(players) do
        local playerRaw = player._rawEntity
        if playerRaw and playerRaw:IsAlive() and not playerRaw:IsDormant() and playerRaw ~= pLocal then
            return playerRaw
        end
    end
    return nil
end

-- Check if player is actively trying to shoot (not just aim key pressed)
local function IsPlayerShooting(userCmd)
    if not userCmd then return false end
    return (userCmd:GetButtons() & IN_ATTACK) ~= 0
end

-- Calculate improved predictability-based hitchance using motion derivatives
local function CalculatePredictabilityHitchance(player)
    if not player then return 0 end

    local playerIndex = player:GetIndex()
    local history = G.history[playerIndex]

    if not history then return 0 end

    -- Start at 100% hitchance and decrease based on motion unpredictability
    local hitchance = 100.0

    -- Get motion derivative values from history
    local acceleration = history.acceleration or Vector3(0, 0, 0)
    local jerk = history.jerk or Vector3(0, 0, 0)
    local snap = history.snap or Vector3(0, 0, 0)
    local pop = history.pop or Vector3(0, 0, 0)
    local strafeDelta = history.strafeDelta or 0

    -- Calculate motion magnitudes (deviations from linear motion)
    local accelMagnitude = acceleration:Length()
    local jerkMagnitude = jerk:Length()
    local snapMagnitude = snap:Length()
    local popMagnitude = pop:Length()
    local strafeMagnitude = math.abs(strafeDelta)

    -- Apply penalties based on motion unpredictability (most to least important)
    -- Acceleration is most important (40% max penalty)
    if accelMagnitude > 5 then
        local accelPenalty = math.min(40, accelMagnitude * 2)
        hitchance = hitchance - accelPenalty
    end

    -- Jerk (rate of acceleration change) is very important (30% max penalty)
    if jerkMagnitude > 10 then
        local jerkPenalty = math.min(30, jerkMagnitude * 1.5)
        hitchance = hitchance - jerkPenalty
    end

    -- Strafe delta is important for direction changes (20% max penalty)
    if strafeMagnitude > 2 then
        local strafePenalty = math.min(20, strafeMagnitude * 5)
        hitchance = hitchance - strafePenalty
    end

    -- Snap (rate of jerk change) is less important (15% max penalty)
    if snapMagnitude > 20 then
        local snapPenalty = math.min(15, snapMagnitude * 0.5)
        hitchance = hitchance - snapPenalty
    end

    -- Pop (rate of snap change) is least important (10% max penalty)
    if popMagnitude > 30 then
        local popPenalty = math.min(10, popMagnitude * 0.25)
        hitchance = hitchance - popPenalty
    end

    -- Ensure hitchance doesn't go below 0
    hitchance = math.max(0, hitchance)

    -- Store detailed motion data for status display
    G.Aimbot.MotionAnalysis = {
        acceleration = accelMagnitude,
        jerk = jerkMagnitude,
        snap = snapMagnitude,
        pop = popMagnitude,
        strafe = strafeMagnitude,
        hitchance = hitchance
    }

    return hitchance
end

-- Real prediction for visuals when player is predictable enough
local function GetRealPrediction(player)
    if not player then return nil end

    -- Update prediction system with current player
    Prediction:update(player)

    -- Build prediction path tick by tick (33 ticks by default)
    local predictionPath = {}
    local currentState = Prediction:predict(0) -- Get current state

    if currentState and currentState.pos then
        table.insert(predictionPath, currentState.pos)

        -- Predict forward 33 ticks (standard simulation length)
        for tick = 1, 33 do
            local nextState = Prediction:predictTick()
            if nextState and nextState.pos then
                table.insert(predictionPath, nextState.pos)
            else
                break
            end
        end
    end

    return predictionPath
end

-- History update (history stored every tick, heavy calculations limited)
local lastPredictionUpdate = 0
local function Main()
    local pLocal = FastPlayers.GetLocal()
    if not pLocal or not pLocal:IsAlive() or pLocal:InCond(7) then return end

    -- Only run any calculations if aimbot is enabled
    if not Config.main.enable then
        return
    end

    -- ALWAYS update history for the 8 best targets (constantly track them for immediate accuracy)
    BestTarget.UpdateHistory(pLocal._rawEntity)

    -- Always find best target when aimbot is enabled for visuals
    local currentTarget = BestTarget.Get()
    G.Target = currentTarget -- Store for visuals

    -- When aim key is pressed, show target prediction visuals
    if input.IsButtonDown(Config.main.aimKey.key) then
        if currentTarget then
            -- Calculate predictability-based hitchance for display purposes
            local predictabilityHitchance = CalculatePredictabilityHitchance(currentTarget)
            G.Aimbot.PredictabilityHitchance = predictabilityHitchance -- Store for visuals/debug

            -- Always show real prediction when aiming (for visuals)
            local predictionPath = GetRealPrediction(currentTarget)
            if predictionPath then
                G.Aimbot.TargetPredictionPath = predictionPath
            end
        end
    end

    -- Update prediction for visuals if enabled
    if Config.visuals.active and currentTarget then
        Prediction:update(currentTarget)
    end
end

-- Main aimbot function for CreateMove
local function OnCreateMove(userCmd)
    -- Only run aimbot if enabled and key is pressed
    if not Config.main.enable or not input.IsButtonDown(Config.main.aimKey.key) then
        return
    end

    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end

    local weapon = me:GetPropEntity("m_hActiveWeapon")
    if not weapon then return end

    -- Check if weapon is projectile-based
    local projType = weapon:GetWeaponProjectileType()
    if not projType or projType <= 1 then return end

    -- Check if player is actively shooting vs just aiming
    local isActivelyShooting = IsPlayerShooting(userCmd)

    -- Always try to run the aimbot to get accurate hitchance calculation
    ProjectileAimbot.UpdateLatency()
    local currentTarget = BestTarget.Get()
    if not currentTarget then
        return
    end

    -- Always run the projectile calculation for aiming (even if hitchance is low)
    local aimResult = nil

    if isActivelyShooting then
        -- For manual shooting, use direct method that bypasses hitchance validation
        aimResult = ProjectileAimbot.CheckProjectileTargetDirect(me, weapon, currentTarget)
    else
        -- For auto-shooting, use normal method that respects hitchance
        aimResult = ProjectileAimbot.CheckProjectileTarget(me, weapon, currentTarget)
    end

    -- If we still don't have a solution, try the direct method as fallback for aiming
    if not aimResult and not isActivelyShooting then
        aimResult = ProjectileAimbot.CheckProjectileTargetDirect(me, weapon, currentTarget)
    end

    if not aimResult then
        return -- No valid solution found at all
    end

    -- Store current target and angles
    G.Aimbot.Target = currentTarget
    G.Aimbot.CurrentAngles = aimResult.angles

    -- Apply aim
    userCmd:SetViewAngles(aimResult.angles:Unpack())
    if not Config.main.silent then
        engine.SetViewAngles(aimResult.angles)
    end

    -- Determine if we should shoot based on different scenarios:
    local actualHitchance = G.Aimbot.HitChance or 0
    local shouldShoot = false

    if isActivelyShooting then
        -- Player is manually shooting - always allow (regardless of auto-shoot setting or hitchance)
        shouldShoot = true
    elseif Config.main.autoShoot then
        -- Auto-shoot is enabled - only shoot if hitchance threshold is met
        shouldShoot = actualHitchance >= Config.main.minHitchance
    end

    if shouldShoot then
        -- Apply shooting logic
        if weapon:GetWeaponID() == TF_WEAPON_COMPOUND_BOW then
            local chargeBeginTime = weapon:GetPropFloat("PipebombLauncherLocalData", "m_flChargeBeginTime") or 0
            if chargeBeginTime > 0 then
                userCmd.buttons = userCmd.buttons & ~IN_ATTACK
            else
                userCmd.buttons = userCmd.buttons | IN_ATTACK
            end
        else
            -- Normal weapon - shoot
            userCmd.buttons = userCmd.buttons | IN_ATTACK
        end
    end
end

-- Save config on unload
local function OnUnload()
    Config:Save()
    Common.Log:Info("PAimbot unloaded and config saved")
end

-- Register the drawing callback for rendering the trajectory
callbacks.Unregister("CreateMove", "PAimbot_ProjectileAimbot")
callbacks.Unregister("CreateMove", "PAimbot_OnCreateMove")
callbacks.Unregister("Unload", "PAimbot_OnUnload")

-- Register the drawing callback for rendering the trajectory
callbacks.Register("CreateMove", "PAimbot_ProjectileAimbot", Main)
callbacks.Register("CreateMove", "PAimbot_OnCreateMove", OnCreateMove)
callbacks.Register("Unload", "PAimbot_OnUnload", OnUnload)

-- Log successful load
Common.Log:Info("PAimbot loaded successfully!")
