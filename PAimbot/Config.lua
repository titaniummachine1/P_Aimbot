-- Config.lua

-- Require the JSON library from the modules folder.
local json = require("PAimbot.Modules.Json")
local G = require("PAimbot.Globals")

local Hitbox = {
    Head = 1,
    Body = 5,
    Feet = 11,
}

-- Default configuration table.
-- (Keys are in lower-case for easier access, e.g. Config.main.enable)
local defaultConfig = {
    currentTab = 1,  -- Top-level tab, if needed
    main = {
        enable = true,  -- Enable flag for the main module
        aimKey = {
            key = KEY_LSHIFT,
            aimKeyName = "LSHIFT",
        },
        aimfov = 180,
        minHitchance = 40,
        autoShoot = true,
        silent = true,
        aimPos = {
            currentAimPos = Hitbox.Feet,
            arrow = Hitbox.Head,
            projectile = Hitbox.Feet,
        },
        aimModes = {
            legit = 1,
            rage = 2,
        },
    },
    advanced = {
        splashBot = true,
        splashAccuracy = 5,
        predTicks = 132,
        historyTicks = 66,
        hitchanceAccuracy = 10,
        strafePrediction = true,
        strafeSamples = 17,
        -- 0.5 to 8, determines the size of the segments traced; lower values = worse performance (default 2.5)
        projectileSegments = 2.5,
        debugInfo = true,
    },
    visuals = {
        active = true,
        visualizePath = true,
        path_styles = {"Line", "Alt Line", "Dashed"},
        path_styles_selected = 2,
        visualizeHitchance = true,
        visualizeProjectile = true,
        visualizeHitPos = true,
        crosshair = true,
        nccPred = true,
        polygon = {
            enabled = true,
            r = 255,
            g = 200,
            b = 155,
            a = 50,
            size = 10,
            segments = 20,
        },
        line = {
            enabled = true,
            r = 255,
            g = 255,
            b = 255,
            a = 255,
        },
        flags = {
            enabled = true,
            r = 255,
            g = 0,
            b = 0,
            a = 255,
            size = 5,
        },
        outline = {
            line_and_flags = true,
            polygon = true,
            r = 0,
            g = 0,
            b = 0,
            a = 155,
        },
    },
}

-- Create our singleton Config table.
local Config = {}
Config.__index = Config

-- Merge default configuration values into our Config table.
for key, value in pairs(defaultConfig) do
    Config[key] = value
end

-- Private variables for file handling.
local scriptName = G.scriptName or "DefaultScript"
local folderName = string.format("Lua %s", scriptName)
filesystem.CreateDirectory(folderName)
local filePath = folderName .. "/" .. scriptName .. "_config.json"

--------------------------------------------------------------------------------
-- Helper function: copyMatchingKeys
-- Creates a deep copy of the source table using only the keys defined in 'filter'.
-- This avoids copying extra keys that may introduce cycles.
--------------------------------------------------------------------------------
local function copyMatchingKeys(src, filter, copies)
    copies = copies or {}
    if type(src) ~= "table" then
        return src
    end
    if copies[src] then
        return copies[src]
    end
    local result = {}
    copies[src] = result
    for key, fval in pairs(filter) do
        local sval = src[key]
        if type(fval) == "table" then
            if type(sval) == "table" then
                result[key] = copyMatchingKeys(sval, fval, copies)
            else
                result[key] = sval
            end
        else
            if type(sval) ~= "function" then
                result[key] = sval
            end
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Utility: recursively check that every key in 'expected' exists in 'loaded'.
--------------------------------------------------------------------------------
local function deepCheck(expected, loaded)
    for key, value in pairs(expected) do
        if loaded[key] == nil then
            return false
        end
        if type(value) == "table" then
            if type(loaded[key]) ~= "table" then
                return false
            end
            if not deepCheck(value, loaded[key]) then
                return false
            end
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- Save the current configuration to file (in JSON format)
-- Only the data is saved (functions are excluded) using a filtered deep copy.
--------------------------------------------------------------------------------
function Config:Save()
    local file = io.open(filePath, "w")
    if file then
        -- Create a deep copy of the configuration data using defaultConfig as a filter.
        local dataToSave = copyMatchingKeys(self, defaultConfig)
        local content = json.encode(dataToSave)
        file:write(content)
        file:close()
        printc(100, 183, 0, 255, "Success Saving Config: " .. filePath)
    else
        printc(255, 0, 0, 255, "Failed to open file for writing: " .. filePath)
    end
end

--------------------------------------------------------------------------------
-- Load configuration from file.
-- If the file does not exist or if the structure is outdated, the default config is saved.
--------------------------------------------------------------------------------
function Config:Load()
    local file = io.open(filePath, "r")
    if file then
        local content = file:read("*a")
        file:close()
        local loadedConfig, decodeErr = json.decode(content)
        if loadedConfig and deepCheck(defaultConfig, loadedConfig) and not input.IsButtonDown(KEY_LSHIFT) then
            -- Overwrite our configuration values with those from the file.
            for key, value in pairs(loadedConfig) do
                self[key] = value
            end
            printc(100, 183, 0, 255, "Success Loading Config: " .. filePath)
        else
            local warnMsg = decodeErr or "Config is outdated or invalid. Creating a new config."
            printc(255, 0, 0, 255, warnMsg)
            self:Save()
        end
    else
        local warnMsg = "Config file not found. Creating a new config."
        printc(255, 0, 0, 255, warnMsg)
        self:Save()
    end
end

local function OnUnload()
    Config:Save()
end

callbacks.Unregister("Unload", G.scriptName .. "_CleanupObjects")
callbacks.Register("Unload", G.scriptName .. "_CleanupObjects", OnUnload)

--------------------------------------------------------------------------------
-- Optional unit test function for verifying saving and loading.
--------------------------------------------------------------------------------
function Config:UnitTest()
    print("----- Running Config Unit Test -----")
    print("Original config:")
    print(json.encode(copyMatchingKeys(self, defaultConfig)))
    -- Modify one value: change aimfov from 180 to 200.
    self.main.aimfov = 200
    print("Modified aimfov to:", self.main.aimfov)
    self:Save()
    self:Load()
    print("Reloaded config:")
    print(json.encode(copyMatchingKeys(self, defaultConfig)))
    if self.main.aimfov == 200 then
        print("Unit Test Passed: aimfov correctly saved and loaded.")
    else
        print("Unit Test Failed: aimfov did not persist correctly.")
    end
    print("----- End of Unit Test -----")
end

-- Auto-load the configuration when the module is required.
Config:Load()

return Config
