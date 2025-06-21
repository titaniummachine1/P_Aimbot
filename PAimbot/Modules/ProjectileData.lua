--[[           ProjectileData Module         ]] --
--[[        Updated to include all           ]] --
--[[          projectile types               ]] --

-- Required modules or APIs
local Common = require("PAimbot.Common") -- Ensure this module contains the CLAMP function

-- ProjectileData Module
local ProjectileData = {}

-- Constants
local FL_DUCKING = 2 -- Adjust based on your environment
local UP_VECTOR = Vector3(0, 0, 1)

-- Projectile types
local PROJECTILE_TYPE_BASIC = 0
local PROJECTILE_TYPE_PSEUDO = 1
local PROJECTILE_TYPE_SIMUL = 2

-- Weapon definition mappings
local aItemDefinitions = {}
local function AppendItemDefinitions(iType, ...)
    for _, i in pairs({ ... }) do
        aItemDefinitions[i] = iType
    end
end

local function DefineProjectileDefinition(tbl)
    return {
        m_iType = PROJECTILE_TYPE_BASIC,
        m_vecOffset = tbl.vecOffset or Vector3(0, 0, 0),
        m_vecAbsoluteOffset = tbl.vecAbsoluteOffset or Vector3(0, 0, 0),
        m_vecAngleOffset = tbl.vecAngleOffset or Vector3(0, 0, 0),
        m_vecVelocity = tbl.vecVelocity or Vector3(0, 0, 0),
        m_vecAngularVelocity = tbl.vecAngularVelocity or Vector3(0, 0, 0),
        m_vecMins = tbl.vecMins or (not tbl.vecMaxs) and Vector3(0, 0, 0) or -tbl.vecMaxs,
        m_vecMaxs = tbl.vecMaxs or (not tbl.vecMins) and Vector3(0, 0, 0) or -tbl.vecMins,
        m_flGravity = tbl.flGravity or 0.001,
        m_flDrag = tbl.flDrag or 0,
        m_iAlignDistance = tbl.iAlignDistance or 0,
        m_sModelName = tbl.sModelName or "",

        GetOffset = not tbl.GetOffset
            and function(self, bDucking, bIsFlipped)
                return bIsFlipped and Vector3(self.m_vecOffset.x, -self.m_vecOffset.y, self.m_vecOffset.z)
                    or self.m_vecOffset
            end
            or tbl.GetOffset,

        GetFirePosition = tbl.GetFirePosition
            or function(self, pLocalPlayer, vecLocalView, vecViewAngles, bIsFlipped)
                local resultTrace = engine.TraceHull(
                    vecLocalView,
                    vecLocalView
                    + Common.VEC_ROT(
                        self:GetOffset((pLocalPlayer:GetPropInt("m_fFlags") & FL_DUCKING) ~= 0, bIsFlipped),
                        vecViewAngles
                    ),
                    -Vector3(8, 8, 8),
                    Vector3(8, 8, 8),
                    G.Constants.MASK_PLAYERSOLID
                )
                return (not resultTrace.startsolid) and resultTrace.endpos or nil
            end,

        GetVelocity = (not tbl.GetVelocity) and function(self, ...)
            return self.m_vecVelocity
        end or tbl.GetVelocity,

        GetAngularVelocity = (not tbl.GetAngularVelocity) and function(self, ...)
            return self.m_vecAngularVelocity
        end or tbl.GetAngularVelocity,

        GetGravity = (not tbl.GetGravity) and function(self, ...)
            return self.m_flGravity
        end or tbl.GetGravity,
    }
end

local function DefineBasicProjectileDefinition(tbl)
    local stReturned = DefineProjectileDefinition(tbl)
    stReturned.m_iType = PROJECTILE_TYPE_BASIC
    return stReturned
end

local function DefinePseudoProjectileDefinition(tbl)
    local stReturned = DefineProjectileDefinition(tbl)
    stReturned.m_iType = PROJECTILE_TYPE_PSEUDO
    return stReturned
end

local function DefineSimulProjectileDefinition(tbl)
    local stReturned = DefineProjectileDefinition(tbl)
    stReturned.m_iType = PROJECTILE_TYPE_SIMUL
    return stReturned
end

local function DefineDerivedProjectileDefinition(def, tbl)
    local stReturned = {}
    for k, v in pairs(def) do
        stReturned[k] = v
    end
    for k, v in pairs(tbl) do
        stReturned[((type(v) ~= "function") and "m_" or "") .. k] = v
    end

    if not tbl.GetOffset and tbl.vecOffset then
        stReturned.GetOffset = function(self, bDucking, bIsFlipped)
            return bIsFlipped and Vector3(self.m_vecOffset.x, -self.m_vecOffset.y, self.m_vecOffset.z)
                or self.m_vecOffset
        end
    end

    if not tbl.GetVelocity and tbl.vecVelocity then
        stReturned.GetVelocity = function(self, ...)
            return self.m_vecVelocity
        end
    end

    if not tbl.GetAngularVelocity and tbl.vecAngularVelocity then
        stReturned.GetAngularVelocity = function(self, ...)
            return self.m_vecAngularVelocity
        end
    end

    if not tbl.GetGravity and tbl.flGravity then
        stReturned.GetGravity = function(self, ...)
            return self.m_flGravity
        end
    end

    return stReturned
end

-- Initialize projectile definitions
local aProjectileInfo = {}

-- Rocket Launcher family
AppendItemDefinitions(1, 18, 205, 228, 237, 658, 730, 800, 809, 889, 898, 907, 916, 965, 974, 1085, 1104, 15006, 15014,
    15028, 15043, 15052, 15057, 15081, 15104, 15105, 15129, 15130, 15150)
aProjectileInfo[1] = DefineBasicProjectileDefinition({
    vecVelocity = Vector3(1100, 0, 0),
    vecMaxs = Vector3(0, 0, 0),
    iAlignDistance = 2000,
    GetOffset = function(self, bDucking, bIsFlipped)
        return Vector3(23.5, 12 * (bIsFlipped and -1 or 1), bDucking and 8 or -3)
    end,
})

-- Direct Hit
AppendItemDefinitions(2, 127)
aProjectileInfo[2] = DefineDerivedProjectileDefinition(aProjectileInfo[1], {
    vecVelocity = Vector3(2000, 0, 0),
})

-- Liberty Launcher
AppendItemDefinitions(3, 414)
aProjectileInfo[3] = DefineDerivedProjectileDefinition(aProjectileInfo[1], {
    vecVelocity = Vector3(1550, 0, 0),
})

-- The Original
AppendItemDefinitions(4, 513)
aProjectileInfo[4] = DefineDerivedProjectileDefinition(aProjectileInfo[1], {
    GetOffset = function(self, bDucking)
        return Vector3(23.5, 0, bDucking and 8 or -3)
    end,
})

-- Dragon's Fury
AppendItemDefinitions(5, 1178)
aProjectileInfo[5] = DefineBasicProjectileDefinition({
    vecVelocity = Vector3(600, 0, 0),
    vecMaxs = Vector3(1, 1, 1),
    GetOffset = function(self, bDucking, bIsFlipped)
        return Vector3(3, 7, -9)
    end,
})

-- Stickybomb Launcher family
AppendItemDefinitions(7, 20, 207, 661, 797, 806, 886, 895, 904, 913, 962, 971, 15009, 15012, 15024, 15038, 15045, 15048,
    15082, 15083, 15084, 15113, 15137, 15138, 15155)
aProjectileInfo[7] = DefineSimulProjectileDefinition({
    vecOffset = Vector3(16, 8, -6),
    vecAngularVelocity = Vector3(600, 0, 0),
    vecMaxs = Vector3(2, 2, 2),
    sModelName = "models/weapons/w_models/w_stickybomb.mdl",
    GetVelocity = function(self, flChargeBeginTime)
        return Vector3(900 + Common.CLAMP(flChargeBeginTime / 4, 0, 1) * 1500, 0, 200)
    end,
})

-- Grenade Launcher family
AppendItemDefinitions(10, 19, 206, 1007, 1151, 15077, 15079, 15091, 15092, 15116, 15117, 15142, 15158)
aProjectileInfo[10] = DefinePseudoProjectileDefinition({
    vecOffset = Vector3(16, 8, -6),
    vecVelocity = Vector3(1200, 0, 200),
    vecMaxs = Vector3(2, 2, 2),
    flGravity = 1,
    flDrag = 0.45,
})

-- Huntsman
AppendItemDefinitions(13, 56, 1005, 1092)
aProjectileInfo[13] = DefinePseudoProjectileDefinition({
    vecOffset = Vector3(23.5, -8, -3),
    vecMaxs = Vector3(0, 0, 0),
    iAlignDistance = 2000,
    GetVelocity = function(self, flChargeBeginTime)
        return Vector3(1800 + Common.CLAMP(flChargeBeginTime, 0, 1) * 800, 0, 0)
    end,
    GetGravity = function(self, flChargeBeginTime)
        return 0.5 - Common.CLAMP(flChargeBeginTime, 0, 1) * 0.4
    end,
})

-- Flare Gun family
AppendItemDefinitions(14, 39, 595, 740, 1081)
aProjectileInfo[14] = DefinePseudoProjectileDefinition({
    vecVelocity = Vector3(2000, 0, 0),
    vecMaxs = Vector3(0, 0, 0),
    flGravity = 0.3,
    iAlignDistance = 2000,
    GetOffset = function(self, bDucking, bIsFlipped)
        return Vector3(23.5, 12 * (bIsFlipped and -1 or 1), bDucking and 8 or -3)
    end,
})

-- Crossbow
AppendItemDefinitions(15, 305, 1079)
aProjectileInfo[15] = DefinePseudoProjectileDefinition({
    vecOffset = Vector3(23.5, -8, -3),
    vecVelocity = Vector3(2400, 0, 0),
    vecMaxs = Vector3(3, 3, 3),
    flGravity = 0.2,
    iAlignDistance = 2000,
})

-- Main function to get projectile data
function ProjectileData.GetProjectileData(player, weapon)
    if not player or not weapon then
        return nil
    end

    local weaponDefIndex = weapon:GetPropInt("m_iItemDefinitionIndex")
    local projectileType = aItemDefinitions[weaponDefIndex]

    if not projectileType or not aProjectileInfo[projectileType] then
        return nil
    end

    local projInfo = aProjectileInfo[projectileType]
    local chargeBeginTime = weapon:GetPropFloat("PipebombLauncherLocalData", "m_flChargeBeginTime") or 0

    if chargeBeginTime > 0 then
        chargeBeginTime = globals.CurTime() - chargeBeginTime
    end

    return {
        Type = projInfo.m_iType,
        Speed = projInfo:GetVelocity(chargeBeginTime).x,
        Gravity = projInfo:GetGravity(chargeBeginTime),
        Drag = projInfo.m_flDrag,
        Offset = projInfo:GetOffset((player:GetPropInt("m_fFlags") & FL_DUCKING) ~= 0, weapon:IsViewModelFlipped()),
        Mins = projInfo.m_vecMins,
        Maxs = projInfo.m_vecMaxs,
        ModelName = projInfo.m_sModelName,
        ProjectileInfo = projInfo,
        ChargeTime = chargeBeginTime,
    }
end

return ProjectileData
