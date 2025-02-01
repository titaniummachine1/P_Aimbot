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

    --strafe angle history
    HistoryHandler:update()

    --finds best target
    G.Target = BestTarget.Get()

    --print(pLocal:EstimateAbsVelocity():Length())
    --if not G.Target then return end

    Prediction:update(pLocal)
    Prediction:predict(132)

    G.PredictionData.PredPath = Prediction:history()
end

-- Register the drawing callback for rendering the trajectory
callbacks.Unregister("CreateMove", "PAimbot_ProjectileAimbot")

-- Register the drawing callback for rendering the trajectory
callbacks.Register("CreateMove", "PAimbot_ProjectileAimbot", CalcualteShots)
