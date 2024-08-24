-- BestTarget.lua

local BestTarget = {}

local Common = require("PAimbot.Common")
local G = require("PAimbot.Globals")

local eyeOffset = Vector3(0, 0, 75)

-- Checks if a player should be considered as a valid target
local function IsValidTarget(me, player)
    return player and player:IsAlive() 
        and not player:IsDormant() 
        and player ~= me 
        and player:GetTeamNumber() ~= me:GetTeamNumber() 
        and (gui.GetValue("ignore cloaked") == 0 or not player:InCond(4))
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

    local distanceFactor = Common.Math.RemapValClamped(distance, 50, 2500, 1, 0.09)
    local fovFactor = Common.Math.RemapValClamped(fov, 0, G.Menu.Main.AimFov, 1, 0.7)
    local isVisible = Common.Helpers.VisPos(player, localPlayerOrigin + eyeOffset, playerOrigin + eyeOffset)
    local visibilityFactor = isVisible and 1 or 0.5

    return fovFactor * visibilityFactor * distanceFactor
end

-- Main function to find the best target
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

return BestTarget
