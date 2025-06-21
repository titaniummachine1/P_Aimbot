-- FastPlayers.lua ─────────────────────────────────────────────────────────
-- FastPlayers: Simplified per-tick cached player lists.
-- On each CreateMove tick, caches reset; lists built on demand.

--[[ Imports ]]
local G = require("PAimbot.Globals")
local Common = require("PAimbot.Common")
local WrappedPlayer = require("PAimbot.Modules.Helpers.WrappedPlayer")

--[[ Module Declaration ]]
local FastPlayers = {}

--[[ Local Caches ]]
local cachedAllPlayers
local cachedTeammates
local cachedEnemies
local cachedLocal

FastPlayers.AllUpdated = false
FastPlayers.TeammatesUpdated = false
FastPlayers.EnemiesUpdated = false

--[[ Private: Reset per-tick caches ]]
local function ResetCaches()
    cachedAllPlayers = nil
    cachedTeammates = nil
    cachedEnemies = nil
    cachedLocal = nil
    FastPlayers.AllUpdated = false
    FastPlayers.TeammatesUpdated = false
    FastPlayers.EnemiesUpdated = false
end

--[[ Public API ]]

--- Returns list of valid, non-dormant players once per tick.
---@return WrappedPlayer[]
function FastPlayers.GetAll(excludelocal)
    if FastPlayers.AllUpdated then
        return cachedAllPlayers
    end
    excludelocal = excludelocal and FastPlayers.GetLocal() or nil
    cachedAllPlayers = {}
    for _, ent in pairs(entities.FindByClass("CTFPlayer") or {}) do
        if Common.IsValidPlayer(ent, false, true, excludelocal and excludelocal:GetRawEntity()) then
            local wrapped = WrappedPlayer.FromEntity(ent)
            if wrapped then
                cachedAllPlayers[#cachedAllPlayers + 1] = wrapped
            end
        end
    end
    FastPlayers.AllUpdated = true
    return cachedAllPlayers
end

--- Returns the local player as a WrappedPlayer instance, cached after first wrap.
---@return WrappedPlayer?
function FastPlayers.GetLocal()
    if not cachedLocal then
        local rawLocal = entities.GetLocalPlayer()
        cachedLocal = rawLocal and WrappedPlayer.FromEntity(rawLocal) or nil
    end
    return cachedLocal
end

--- Returns list of teammates, optionally excluding a player (or the local player).
---@param exclude boolean|WrappedPlayer? Pass `true` to exclude the local player, or a WrappedPlayer instance to exclude that specific teammate. Omit/nil to include everyone.
---@return WrappedPlayer[]
function FastPlayers.GetTeammates(exclude)
    if not FastPlayers.TeammatesUpdated then
        if not FastPlayers.AllUpdated then
            FastPlayers.GetAll()
        end

        cachedTeammates = {}

        -- Determine which player (if any) to exclude
        local localPlayer = FastPlayers.GetLocal()
        local excludePlayer = nil
        if exclude == true then
            excludePlayer = localPlayer -- explicitly exclude self
        elseif type(exclude) == "table" then
            excludePlayer = exclude
        end

        -- Use local player's team for filtering
        local myTeam = localPlayer and localPlayer:GetTeamNumber() or nil
        if myTeam then
            for _, wp in ipairs(cachedAllPlayers) do
                if wp:GetTeamNumber() == myTeam and wp ~= excludePlayer then
                    cachedTeammates[#cachedTeammates + 1] = wp
                end
            end
        end

        FastPlayers.TeammatesUpdated = true
    end
    return cachedTeammates
end

--- Returns list of enemies (players on a different team).
---@return WrappedPlayer[]
function FastPlayers.GetEnemies()
    if not FastPlayers.EnemiesUpdated then
        if not FastPlayers.AllUpdated then
            FastPlayers.GetAll()
        end
        cachedEnemies = {}
        local pLocal = FastPlayers.GetLocal()
        if pLocal then
            local myTeam = pLocal:GetTeamNumber()
            for _, wp in ipairs(cachedAllPlayers) do
                if wp:GetTeamNumber() ~= myTeam then
                    cachedEnemies[#cachedEnemies + 1] = wp
                end
            end
        end
        FastPlayers.EnemiesUpdated = true
    end
    return cachedEnemies
end

--[[ Initialization ]]
-- Reset caches at the start of every CreateMove tick.
callbacks.Register("CreateMove", "FastPlayers_ResetCaches", ResetCaches)

return FastPlayers
