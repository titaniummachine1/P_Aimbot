--[[           ProjectileData Module         ]]--
--[[        Updated to include all           ]]--
--[[          projectile types               ]]--

-- Required modules or APIs
local Common = require("PAimbot.Common")  -- Ensure this module contains the CLAMP function

-- ProjectileData Module
local ProjectileData = {}

-- Constants
local FL_DUCKING = 2  -- Adjust based on your environment
local UP_VECTOR = Vector3(0, 0, 1)

-- Predefined offsets and collision sizes for projectiles
local OFFSET_TABLE = {
    stickyBomb = Vector3(16, 8, -6),
    huntsman = Vector3(23.5, -8, -3),
    flareGun = Vector3(23.5, 12, -3),
    syringeGun = Vector3(16, 6, -8),
    rocketLauncher = Vector3(23.5, -8, -3),
    jarate = Vector3(23.5, -8, -3),
    grenadeLauncher = Vector3(16, 8, -6),
    flamethrower = Vector3(0, 0, 0),  -- Adjust as necessary
    energyBall = Vector3(23.5, -8, -3),
    throwable = Vector3(23.5, -8, -3),
    grapplingHook = Vector3(23.5, -8, -3)
}

local COLLISION_SIZE_TABLE = {
    none = Vector3(0, 0, 0),
    small = Vector3(1, 1, 1),
    medium = Vector3(3.2, 3.2, 3.2),
    large = Vector3(3, 3, 3)
}

-- Projectile Types Enumeration
local E_ProjectileType = {
    TF_PROJECTILE_NONE = 0,
    TF_PROJECTILE_BULLET = 1,
    TF_PROJECTILE_ROCKET = 2,
    TF_PROJECTILE_PIPEBOMB = 3,
    TF_PROJECTILE_PIPEBOMB_REMOTE = 4,
    TF_PROJECTILE_SYRINGE = 5,
    TF_PROJECTILE_FLARE = 6,
    TF_PROJECTILE_JAR = 7,
    TF_PROJECTILE_ARROW = 8,
    TF_PROJECTILE_FLAME_ROCKET = 9,
    TF_PROJECTILE_JAR_MILK = 10,
    TF_PROJECTILE_HEALING_BOLT = 11,
    TF_PROJECTILE_ENERGY_BALL = 12,
    TF_PROJECTILE_ENERGY_RING = 13,
    TF_PROJECTILE_PIPEBOMB_PRACTICE = 14,
    TF_PROJECTILE_CLEAVER = 15,
    TF_PROJECTILE_STICKY_BALL = 16,
    TF_PROJECTILE_CANNONBALL = 17,
    TF_PROJECTILE_BUILDING_REPAIR_BOLT = 18,
    TF_PROJECTILE_FESTIVE_ARROW = 19,
    TF_PROJECTILE_THROWABLE = 20,
    TF_PROJECTILE_SPELL = 21,
    TF_PROJECTILE_FESTIVE_JAR = 22,
    TF_PROJECTILE_FESTIVE_HEALING_BOLT = 23,
    TF_PROJECTILE_BREADMONSTER_JARATE = 24,
    TF_PROJECTILE_BREADMONSTER_MADMILK = 25,
    TF_PROJECTILE_GRAPPLINGHOOK = 26,
    TF_PROJECTILE_SENTRY_ROCKET = 27,
    TF_PROJECTILE_BREAD_MONSTER = 28
}

-- Function to get the current charge time of a weapon
local function GetCurrentChargeTime(weapon)
    local chargeBeginTime = weapon:GetChargeBeginTime() or 0
    if chargeBeginTime ~= 0 then
        chargeBeginTime = globals.CurTime() - chargeBeginTime
    end
    return chargeBeginTime
end

-- Main function to get projectile data
function ProjectileData.GetProjectileData(pLocal, weapon)
    -- Initialize the table to return
    local projData = {}

    -- Get weapon data
    local weaponID = weapon:GetWeaponID()
    local itemDefIndex = weapon:GetPropInt("m_iItemDefinitionIndex") or 0
    local weaponData = weapon:GetWeaponData() or {}
    local projectileType = weaponData.projectile or 0
    local baseSpeed = weaponData.projectileSpeed or 0
    local gravity = weapon:GetProjectileGravity() or 0
    local drag = weapon:GetProjectileSpread() or 0

    -- Determine if player is ducking
    local isDucking = (pLocal:GetPropInt("m_fFlags") & FL_DUCKING) == FL_DUCKING

    -- Get charge time if applicable
    local chargeTime = GetCurrentChargeTime(weapon)

    -- Initialize default values
    projData.Offset = Vector3(0, 0, 0)
    projData.ForwardVelocity = baseSpeed
    projData.UpwardVelocity = 0
    projData.CollisionSize = Vector3(0, 0, 0)
    projData.Gravity = gravity
    projData.Drag = drag
    projData.ProjectileType = projectileType

    -- Handle specific projectile types
    if projectileType == E_ProjectileType.TF_PROJECTILE_BULLET then
        -- Hitscan weapons
        return nil  -- Hitscan weapons don't have projectile data

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_ROCKET then
        -- Rocket Launcher
        projData.Offset = Vector3(23.5, -8, isDucking and 8 or -3)
        projData.ForwardVelocity = baseSpeed > 0 and baseSpeed or 1100
        projData.CollisionSize = COLLISION_SIZE_TABLE.small

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_PIPEBOMB or
           projectileType == E_ProjectileType.TF_PROJECTILE_PIPEBOMB_REMOTE or
           projectileType == E_ProjectileType.TF_PROJECTILE_PIPEBOMB_PRACTICE then
        -- Stickybomb Launcher and practice bombs
        projData.Offset = OFFSET_TABLE.stickyBomb
        local chargeFactor = Common.CLAMP(chargeTime / 4, 0, 1)
        projData.ForwardVelocity = 900 + chargeFactor * 1500
        projData.UpwardVelocity = 200
        projData.CollisionSize = COLLISION_SIZE_TABLE.medium
        projData.Gravity = 400
        projData.Drag = 0.5

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_SYRINGE then
        -- Syringe Gun
        projData.Offset = OFFSET_TABLE.syringeGun
        projData.ForwardVelocity = 1000
        projData.Gravity = 120
        projData.CollisionSize = COLLISION_SIZE_TABLE.small

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_FLARE then
        -- Flare Gun
        projData.Offset = OFFSET_TABLE.flareGun
        projData.ForwardVelocity = 2000
        projData.Gravity = 120
        projData.CollisionSize = COLLISION_SIZE_TABLE.none

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_JAR or
           projectileType == E_ProjectileType.TF_PROJECTILE_JAR_MILK or
           projectileType == E_ProjectileType.TF_PROJECTILE_FESTIVE_JAR or
           projectileType == E_ProjectileType.TF_PROJECTILE_BREADMONSTER_JARATE or
           projectileType == E_ProjectileType.TF_PROJECTILE_BREADMONSTER_MADMILK then
        -- Jarate / Mad Milk and variants
        projData.Offset = OFFSET_TABLE.jarate
        projData.ForwardVelocity = 1000
        projData.UpwardVelocity = 200
        projData.Gravity = 450
        projData.CollisionSize = COLLISION_SIZE_TABLE.large

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_ARROW or
           projectileType == E_ProjectileType.TF_PROJECTILE_FESTIVE_ARROW then
        -- Huntsman / Crossbow and festive variants
        projData.Offset = OFFSET_TABLE.huntsman
        local chargeFactor = Common.CLAMP(chargeTime, 0, 1)
        projData.ForwardVelocity = 1800 + chargeFactor * 800
        projData.Gravity = 200 - chargeFactor * 160
        projData.CollisionSize = COLLISION_SIZE_TABLE.small

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_FLAME_ROCKET then
        -- Flamethrower
        projData.Offset = OFFSET_TABLE.flamethrower
        projData.ForwardVelocity = 2300
        projData.Gravity = 0
        projData.CollisionSize = COLLISION_SIZE_TABLE.none

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_HEALING_BOLT or
           projectileType == E_ProjectileType.TF_PROJECTILE_FESTIVE_HEALING_BOLT then
        -- Crusader's Crossbow and festive variant
        projData.Offset = OFFSET_TABLE.huntsman
        projData.ForwardVelocity = 2400
        projData.Gravity = 80
        projData.CollisionSize = COLLISION_SIZE_TABLE.small

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_ENERGY_BALL then
        -- Cow Mangler / Righteous Bison
        projData.Offset = OFFSET_TABLE.energyBall
        projData.ForwardVelocity = 1200
        projData.Gravity = 0
        projData.CollisionSize = COLLISION_SIZE_TABLE.small

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_CLEAVER then
        -- Flying Guillotine
        projData.Offset = OFFSET_TABLE.flareGun
        projData.ForwardVelocity = 3000
        projData.UpwardVelocity = 300
        projData.Gravity = 900
        projData.CollisionSize = COLLISION_SIZE_TABLE.medium
        projData.Drag = 1.3

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_STICKY_BALL then
        -- Wrap Assassin Ball
        projData.Offset = OFFSET_TABLE.stickyBomb
        projData.ForwardVelocity = 2000
        projData.Gravity = 1000
        projData.CollisionSize = COLLISION_SIZE_TABLE.small

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_CANNONBALL then
        -- Loose Cannon
        projData.Offset = OFFSET_TABLE.stickyBomb
        projData.ForwardVelocity = 1453  -- Based on game data
        projData.UpwardVelocity = 200
        projData.CollisionSize = COLLISION_SIZE_TABLE.medium
        projData.Gravity = 560
        projData.Drag = 0.5

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_BUILDING_REPAIR_BOLT then
        -- Rescue Ranger Bolt
        projData.Offset = OFFSET_TABLE.huntsman
        projData.ForwardVelocity = 2400
        projData.Gravity = 0
        projData.CollisionSize = COLLISION_SIZE_TABLE.small

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_THROWABLE then
        -- Throwable items like Gas Passer
        projData.Offset = OFFSET_TABLE.throwable
        projData.ForwardVelocity = 1000
        projData.UpwardVelocity = 200
        projData.Gravity = 450
        projData.CollisionSize = COLLISION_SIZE_TABLE.large

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_SPELL then
        -- Spells from Halloween events
        projData.Offset = OFFSET_TABLE.throwable
        projData.ForwardVelocity = 1200
        projData.Gravity = 400
        projData.CollisionSize = COLLISION_SIZE_TABLE.medium

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_GRAPPLINGHOOK then
        -- Grappling Hook
        projData.Offset = OFFSET_TABLE.grapplingHook
        projData.ForwardVelocity = 3000
        projData.Gravity = 0
        projData.CollisionSize = COLLISION_SIZE_TABLE.small

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_SENTRY_ROCKET then
        -- Sentry Rocket
        projData.Offset = OFFSET_TABLE.rocketLauncher
        projData.ForwardVelocity = 1100
        projData.CollisionSize = COLLISION_SIZE_TABLE.small

    elseif projectileType == E_ProjectileType.TF_PROJECTILE_BREAD_MONSTER then
        -- Bread Monster
        projData.Offset = OFFSET_TABLE.throwable
        projData.ForwardVelocity = 1000
        projData.Gravity = 400
        projData.CollisionSize = COLLISION_SIZE_TABLE.medium

    -- Add any additional projectile types here as needed

    else
        -- Handle unknown or unsupported projectile types
        return nil
    end

    -- Return the projectile data table
    return projData
end

return ProjectileData
