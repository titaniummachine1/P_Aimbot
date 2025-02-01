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
Config:Initialize() -- Initialize the config with the script name

--[[Classes]]--
local BestTarget = require("PAimbot.Modules.Helpers.BestTarget")
local HistoryHandler = require("PAimbot.Modules.Prediction.HistoryHandler")
local Prediction = require("PAimbot.Modules.Prediction.Prediction")
--local ProjectileData = require("PAimbot.Modules.ProjectileData")

require("PAimbot.Modules.Helpers.VariableUpdater")
require("PAimbot.Visuals")

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

-- Function to draw the trajectory
local function CalcualteShots()
    local pLocal = entities.GetLocalPlayer()
        if not IsValidLocalPlayer(pLocal) then return end
    local weapon = pLocal:GetPropEntity("m_hActiveWeapon")
        if not IsValidWeapon(weapon) then return end

    --local ProjData = ProjectileData.GetProjectileData(pLocal, weapon)
    --if not ProjData then return end

    --strafe angle history and accel and viewwangle stuff
    HistoryHandler:updateAllValidTargets()

    --finds best target
    G.Target = BestTarget.Get(pLocal)
    --if not G.Target then return end

    Prediction:update(pLocal)
    Prediction:predict(132)

    G.PredictionData.PredPath = Prediction:history()
end

local function OnUnload()
    Config:SaveConfig(G.Menu)
end

-- Register the drawing callback for rendering the trajectory
callbacks.Unregister("CreateMove", G.scriptName .. "_ProjectileAimbot")
callbacks.Unregister("Unload", G.scriptName .. "_CleanupObjects")

-- Register the drawing callback for rendering the trajectory
callbacks.Register("CreateMove", G.scriptName .. "_ProjectileAimbot", CalcualteShots)
callbacks.Register("Unload", G.scriptName .. "_CleanupObjects", OnUnload)