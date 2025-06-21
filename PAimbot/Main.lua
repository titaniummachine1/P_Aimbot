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

-- Minimal history update (run only when needed)
local lastHistoryUpdate = 0
local function Main()
    -- Only run if aimbot is enabled to save performance
    if not Config.main.enable then
        return
    end

    local pLocal = FastPlayers.GetLocal()
    if not pLocal or not pLocal:IsAlive() or pLocal:InCond(7) then return end

    -- Only update history every 5 ticks to reduce overhead significantly
    local currentTick = globals.TickCount()
    if currentTick - lastHistoryUpdate < 5 then
        return
    end
    lastHistoryUpdate = currentTick

    -- Minimal updates only when aiming
    if input.IsButtonDown(Config.main.aimKey.key) then
        HistoryHandler:update()

        -- Only update prediction for current target if one exists
        if G.Target then
            Prediction:update(G.Target)
        end
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
