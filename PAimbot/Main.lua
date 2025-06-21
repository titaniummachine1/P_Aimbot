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
    local players = entities.FindByClass("CTFPlayer")
    for _, player in pairs(players) do
        if player and player:IsAlive() and not player:IsDormant() and player ~= pLocal then
            return player
        end
    end
    return nil
end

-- Function to draw the trajectory
local function Main()
    local pLocal = FastPlayers.GetLocal()
    if not pLocal or not pLocal:IsAlive() or pLocal:InCond(7) then return end

    local weaponEntity = pLocal._rawEntity:GetPropEntity("m_hActiveWeapon")
    if not IsValidWeapon(weaponEntity) then return end

    local ProjData = ProjectileData.GetProjectileData(pLocal._rawEntity, weaponEntity)
    if not ProjData then return end

    -- Update derivative tracking for all players (for advanced prediction)
    Prediction:updateDerivativeTracking()

    --strafe angle history
    HistoryHandler:update()

    --finds best target (use actual target finding instead of local player)
    G.Target = BestTarget.Get() -- Use proper target finding
    if not G.Target then
        return
    end

    Prediction:update(G.Target)

    -- Predict more ticks for better visibility
    local result = Prediction:predict(Config.advanced.predTicks or 66)

    local predictionHistory = Prediction:history()
    G.PredictionData.PredPath = predictionHistory
end

-- Main aimbot function for CreateMove
local function OnCreateMove(userCmd)
    -- Only run aimbot if enabled
    if not Config.main.enable then
        return
    end

    -- Run the aimbot
    ProjectileAimbot.Run(userCmd)
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
