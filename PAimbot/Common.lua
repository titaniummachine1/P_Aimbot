---@diagnostic disable: duplicate-set-field, undefined-field
---@class Common
local Common = {}

--[[require modules]]--
local G = require("PAimbot.Globals")

pcall(UnloadLib) -- if it fails then forget about it it means it wasnt loaded in first place and were clean

-- Unload the module if it's already loaded
if package.loaded["ImMenu"] then
    package.loaded["ImMenu"] = nil
end

local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 1.0, "LNXlib version is too old, please update it!")

Common.Lib = Lib
Common.Log = Lib.Utils.Logger.new(G.scriptName)
Common.UI = Lib.UI
Common.Fonts = Common.UI.Fonts
Common.Notify = Common.UI.Notify
Common.TF2 = Common.Lib.TF2
Common.Utils = Common.Lib.Utils
Common.Math, Common.Conversion = Common.Utils.Math, Common.Utils.Conversion
Common.WPlayer, Common.PR = Common.TF2.WPlayer, Common.TF2.PlayerResource
Common.Helpers = Common.TF2.Helpers
Common.Prediction = Common.TF2.Prediction

-- Boring shit ahead!
Common.CROSS = (function(a, b, c) return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]); end);
Common.CLAMP = (function(a, b, c) return (a<b) and b or (a>c) and c or a; end);
Common.TRACE_HULL = engine.TraceHull;
Common.TRACE_Line = engine.TraceLine;
Common.WORLD2SCREEN = client.WorldToScreen;
Common.POLYGON = draw.TexturedPolygon;
Common.LINE = draw.Line;
Common.COLOR = draw.Color;

-- Function to normalize a vector
function Common.Normalize(vector)
    return vector / vector:Length()
end

--Returns whether the player is on the ground
---@return boolean
function Common.IsOnGround(player)
    local pFlags = player:GetPropInt("m_fFlags")
    return (pFlags & FL_ONGROUND) == 1
end

-- Helper functions can be defined here if needed
function Common.GetHitboxPos(player, hitboxID)
    local hitbox = player:GetHitboxes()[hitboxID]
    if not hitbox then return nil end

    return (hitbox[1] + hitbox[2]) * 0.5
end

-- Returns the name of a keycode
    ---@param key integer
    ---@return string|nil
    function Common.GetKeyName(key)
        return G.KeyNames[key]
    end

    -- Returns the string value of a keycode
    ---@param key integer
    ---@return string|nil
    function Common.KeyToChar(key)
        return G.KeyValues[key]
    end

    -- Returns the keycode of a string value
    ---@param char string
    ---@return integer|nil
    function Common.CharToKey(char)
        return table.find(G.KeyValues, string.upper(char))
    end

    -- Returns all currently pressed keys as a table
    ---@return integer[]
    function Common.GetPressedKeys()
        local keys = {}
        for i = KEY_FIRST, KEY_LAST do
            if input.IsButtonDown(i) then table.insert(keys, i) end
        end

        return keys
    end

    -- Update the GetPressedKey function to check for these additional mouse buttons
    function Common.GetPressedKey()
        for i = KEY_FIRST, KEY_LAST do
            if input.IsButtonDown(i) then return i end
        end

        -- Check for standard mouse buttons
        if input.IsButtonDown(MOUSE_LEFT) then return MOUSE_LEFT end
        if input.IsButtonDown(MOUSE_RIGHT) then return MOUSE_RIGHT end
        if input.IsButtonDown(MOUSE_MIDDLE) then return MOUSE_MIDDLE end

        -- Check for additional mouse buttons
        for i = 1, 10 do
            if input.IsButtonDown(MOUSE_FIRST + i - 1) then return MOUSE_FIRST + i - 1 end
        end

        return nil
    end

--[[ Callbacks ]]
local function OnUnload() -- Called when the script is unloaded
    pcall(UnloadLib) --unloading lualib
    engine.PlaySound("hl1/fvox/deactivated.wav") --deactivated
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("Unload", G.scriptName .. "_Unload")                                -- unregister the "Unload" callback
--[[ Register callbacks ]]--
callbacks.Register("Unload", G.scriptName .. "_Unload", OnUnload)                         -- Register the "Unload" callback

--[[ Play sound when loaded ]]--
engine.PlaySound("hl1/fvox/activated.wav")

return Common
