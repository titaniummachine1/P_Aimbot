--[[ WrappedPlayer.lua ]]
--
-- A proper wrapper for player entities that extends lnxLib's WPlayer

-- Get required modules
local Common = require("PAimbot.Common")

assert(Common, "Common is nil")
local WPlayer = Common.WPlayer
assert(WPlayer, "WPlayer is nil")

---@class WrappedPlayer
---@field _basePlayer table Base WPlayer from lnxLib
---@field _rawEntity Entity Raw entity object
local WrappedPlayer = {}
WrappedPlayer.__index = WrappedPlayer

--- Creates a new WrappedPlayer from a TF2 entity
---@param entity Entity The entity to wrap
---@return WrappedPlayer|nil The wrapped player or nil if invalid
function WrappedPlayer.FromEntity(entity)
    if not entity or not entity:IsValid() then
        return nil
    end

    local basePlayer = WPlayer.FromEntity(entity)
    if not basePlayer then
        return nil
    end

    local wrapped = setmetatable({}, WrappedPlayer)
    wrapped._basePlayer = basePlayer -- Store the lnxLib player wrapper
    wrapped._rawEntity = entity      -- Store the raw entity directly

    return wrapped
end

--- Create WrappedPlayer from index
---@param index number The entity index
---@return WrappedPlayer|nil The wrapped player or nil if invalid
function WrappedPlayer.FromIndex(index)
    local entity = entities.GetByIndex(index)
    return entity and WrappedPlayer.FromEntity(entity) or nil
end

--- Returns the underlying raw entity
function WrappedPlayer:GetRawEntity()
    return self._rawEntity
end

--- Returns the base WPlayer from lnxLib
function WrappedPlayer:GetBasePlayer()
    return self._basePlayer
end

--- Forward common WPlayer methods
function WrappedPlayer:IsAlive()
    return self._basePlayer:IsAlive()
end

function WrappedPlayer:IsDormant()
    return self._basePlayer:IsDormant()
end

function WrappedPlayer:GetTeamNumber()
    return self._basePlayer:GetTeamNumber()
end

function WrappedPlayer:GetAbsOrigin()
    return self._basePlayer:GetAbsOrigin()
end

function WrappedPlayer:GetIndex()
    return self._basePlayer:GetIndex()
end

function WrappedPlayer:InCond(cond)
    return self._basePlayer:InCond(cond)
end

--- Checks if a given entity is valid
---@param checkFriend boolean? Check if the entity is a friend
---@param checkDormant boolean? Check if the entity is dormant
---@param skipEntity Entity? Optional entity to skip
---@return boolean Whether the entity is valid
function WrappedPlayer:IsValidPlayer(checkFriend, checkDormant, skipEntity)
    return Common.IsValidPlayer(self._rawEntity, checkFriend, checkDormant, skipEntity)
end

--- Get SteamID64 for this player object
---@return string|number The player's SteamID64
function WrappedPlayer:GetSteamID64()
    return Common.GetSteamID64(self._basePlayer)
end

--- Check if player is on the ground via m_fFlags
---@return boolean Whether the player is on the ground
function WrappedPlayer:IsOnGround()
    local flags = self._basePlayer:GetPropInt("m_fFlags")
    return (flags & FL_ONGROUND) ~= 0
end

--- Returns the view offset from the player's origin as a Vector3
---@return Vector3 The player's view offset
function WrappedPlayer:GetViewOffset()
    return self._basePlayer:GetPropVector("localdata", "m_vecViewOffset[0]")
end

--- Returns the player's eye position in world coordinates
---@return Vector3 The player's eye position
function WrappedPlayer:GetEyePos()
    return self._basePlayer:GetAbsOrigin() + self:GetViewOffset()
end

--- Returns the player's eye angles as an EulerAngles object
---@return EulerAngles The player's eye angles
function WrappedPlayer:GetEyeAngles()
    local ang = self._basePlayer:GetPropVector("tfnonlocaldata", "m_angEyeAngles[0]")
    return EulerAngles(ang.x, ang.y, ang.z)
end

--- Returns the world position the player is looking at by tracing a ray
---@return Vector3|nil The look position or nil if trace failed
function WrappedPlayer:GetLookPos()
    local eyePos = self:GetEyePos()
    local eyeAng = self:GetEyeAngles()
    local targetPos = eyePos + eyeAng:Forward() * 8192
    local tr = engine.TraceLine(eyePos, targetPos, MASK_SHOT)
    return tr and tr.endpos or nil
end

--- Returns the currently active weapon wrapper
---@return table|nil The active weapon wrapper or nil
function WrappedPlayer:GetActiveWeapon()
    local w = self._basePlayer:GetPropEntity("m_hActiveWeapon")
    return w and Common.WWeapon.FromEntity(w) or nil
end

--- Returns the player's observer mode
---@return number The observer mode
function WrappedPlayer:GetObserverMode()
    return self._basePlayer:GetPropInt("m_iObserverMode")
end

--- Returns the player's observer target wrapper
---@return WrappedPlayer|nil The observer target or nil
function WrappedPlayer:GetObserverTarget()
    local target = self._basePlayer:GetPropEntity("m_hObserverTarget")
    return target and WrappedPlayer.FromEntity(target) or nil
end

--- Returns the next attack time
---@return number The next attack time
function WrappedPlayer:GetNextAttack()
    return self._basePlayer:GetPropFloat("m_flNextAttack")
end

return WrappedPlayer
