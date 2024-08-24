-- Import the Common module for utility functions
local Common = require("PAimbot.Common")
local aItemDefinitions = require("PAimbot.Modules.laDefinitions")

-- Define the ProjectileInfo module
local ProjectileInfo = {}
ProjectileInfo.__index = ProjectileInfo

-- Precache static data: offsets and collision sizes
local OFFSET_TABLE = {
    stickyBomb = Vector3(16, 8, -6),
    huntsman = Vector3(23.5, -8, -3),
    flareGun = Vector3(23.5, 12, -3),
    syringeGun = Vector3(16, 6, -8)
}

local COLLISION_MAX_TABLE = {
    none = Vector3(0, 0, 0),
    small = Vector3(1, 1, 1),
    medium = Vector3(3.2, 3.2, 3.2),
    large = Vector3(3, 3, 3)
}

-- Local function to calculate the current charge time based on when the charge began
local function GetCurrentChargeTime(pWeapon)
    local fChargeBeginTime = (pWeapon:GetPropFloat("m_flChargeBeginTime") or 0)
    if fChargeBeginTime ~= 0 then
        fChargeBeginTime = globals.CurTime() - fChargeBeginTime
    end
    return fChargeBeginTime
end

-- Constructor for the ProjectileInfo class
function ProjectileInfo:new()
    self = setmetatable({}, ProjectileInfo)
    -- Initialize default properties
    self.pLocal = nil
    self.bDucking = false
    self.iCase = 0
    self.iDefIndex = 0
    self.iWepID = 0
    self.fChargeBeginTime = 0
    return self
end

-- Method to initialize or update the ProjectileInfo instance with new data
function ProjectileInfo:Update(data)
    self.pLocal = data.pLocal
    self.bDucking = data.bDucking
    self.iCase = data.iCase
    self.iDefIndex = data.iDefIndex
    self.iWepID = data.iWepID
    self.fChargeBeginTime = GetCurrentChargeTime(data.pWeapon)
end

-- Method to destroy the ProjectileInfo instance
function ProjectileInfo:Destroy()
    self.pLocal = nil
    self.bDucking = nil
    self.iCase = nil
    self.iDefIndex = nil
    self.iWepID = nil
    self.fChargeBeginTime = nil
end

-- Standardized method for handling projectile information retrieval
function ProjectileInfo:GetProjectileInfo(offsetType, forwardVelocity, upwardVelocity, collisionType, gravity, drag)
    return {
        OFFSET_TABLE[offsetType],
        forwardVelocity,
        upwardVelocity or 0,
        COLLISION_MAX_TABLE[collisionType],
        gravity or 0,
        drag or 0
    }
end

-- Weapon-specific configuration functions
local projectileConfigurations = {
    -- Rocket Launcher Info
    [-1] = function(self)
        local vOffset = Vector3(23.5, -8, self.bDucking and 8 or -3)
        local fForwardVelocity = 1200

        if self.iWepID == 22 or self.iWepID == 65 then
            vOffset.y, fForwardVelocity =
                (self.iDefIndex == 513) and 0 or 12,
                (self.iWepID == 65) and 2000 or (self.iDefIndex == 414) and 1550 or 1100
        elseif self.iWepID == 109 then
            vOffset.y, vOffset.z = 6, -3
        end

        return {
            vOffset,
            fForwardVelocity,
            0,
            COLLISION_MAX_TABLE.small,
            0
        }
    end,

    -- Sticky Bomb Info
    [1] = function(self)
        local baseVelocity = 900
        local maxVelocityIncrease = 1500
        local velocity = baseVelocity + Common.CLAMP(self.fChargeBeginTime / 4, 0, 1) * maxVelocityIncrease

        return self:GetProjectileInfo("stickyBomb", velocity, 200, "medium")
    end,

    -- Iron Bomber Info
    [4] = function(self)
        return self:GetProjectileInfo("stickyBomb", 1200, 200, "medium", 400, 0.45)
    end,

    -- Grenade Launcher Info
    [5] = function(self)
        local forwardVelocity = (self.iDefIndex == 308) and 1500 or 1200
        local drag = (self.iDefIndex == 308) and 0.225 or 0.45
        return self:GetProjectileInfo("stickyBomb", forwardVelocity, 200, "medium", 400, drag)
    end,

    -- Loose Cannon Info
    [6] = function(self)
        return self:GetProjectileInfo("stickyBomb", 1440, 200, "medium", 560, 0.5)
    end,

    -- Huntsman Info
    [7] = function(self)
        local baseVelocity = 1800
        local maxVelocityIncrease = 800
        local velocity = baseVelocity + Common.CLAMP(self.fChargeBeginTime, 0, 1) * maxVelocityIncrease
        local gravity = 200 - Common.CLAMP(self.fChargeBeginTime, 0, 1) * 160
        return self:GetProjectileInfo("huntsman", velocity, 0, "small", gravity)
    end,

    -- Flare Gun Info
    [8] = function(self)
        return self:GetProjectileInfo("flareGun", 2000, 0, "none", 120)
    end,

    -- Crossbow Info
    [9] = function(self)
        local collisionType = (self.iDefIndex == 997) and "small" or "large"
        return self:GetProjectileInfo("huntsman", 2400, 0, collisionType, 80)
    end,

    -- Syringe Gun Info
    [10] = function(self)
        return self:GetProjectileInfo("syringeGun", 1000, 0, "small", 120)
    end,

    -- Jarate Info
    [11] = function(self)
        return self:GetProjectileInfo("huntsman", 1000, 200, "large", 450)
    end,

    -- Guillotine Info
    [12] = function(self)
        return self:GetProjectileInfo("flareGun", 3000, 300, "medium", 900, 1.3)
    end
}

-- Method to retrieve the correct projectile information based on the weapon type
function ProjectileInfo:GetProjectileInformation()
    local configFunction = projectileConfigurations[self.iCase]
    if configFunction then
        return configFunction(self)
    else
        return nil
    end
end

-- Initialize the ProjectileInfo instance once
local projectileInfoInstance = ProjectileInfo:new()

-- Retrieve the projectile information object
function ProjectileInfo.GetProjectileInformationObject(pLocal, pWeapon)
    -- Get the item definition index from the weapon
    local iItemDefinitionIndex = pWeapon:GetPropInt("m_iItemDefinitionIndex")

    -- Determine the type of item definition from the predefined table
    local iItemDefinitionType = aItemDefinitions[iItemDefinitionIndex] or 0
    if iItemDefinitionType == 0 then return nil end  -- Return nil if the item is not valid

    -- Determine if the player is ducking
    local isDucking = (pLocal:GetPropInt("m_fFlags") & FL_DUCKING) == 2

    -- Prepare the data table for updating the projectile info instance
    local data = {
        pLocal = pLocal,
        bDucking = isDucking,
        iCase = iItemDefinitionType,
        iDefIndex = iItemDefinitionIndex,
        iWepID = pWeapon:GetWeaponID(),
        pWeapon = pWeapon
    }

    -- Update the existing ProjectileInfo instance with new data
    projectileInfoInstance:Update(data)

    -- Retrieve the correct configuration function based on the item type
    local configFunction = projectileConfigurations[iItemDefinitionType]
    if configFunction then
        -- Call the function to get the projectile information
        return configFunction(projectileInfoInstance), iItemDefinitionType
    else
        -- Return nil if no configuration function exists for the item type
        return nil
    end
end

return ProjectileInfo