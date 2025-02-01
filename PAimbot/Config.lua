-- Config.lua

-- Require the JSON library from the modules folder.
local json = require("PAimbot.Modules.Json")

local Hitbox = {
    Head = 1,
    Body = 5,
    Feet = 11,
}

local Config = {}
Config.__index = Config

-- Default configuration table.
-- (Keys are in lower-case for easier access, e.g. config.main.enable)
local defaultConfig = {
    currentTab = 1,  -- Top-level tab, if needed
    main = {
        enable = true,  -- Added enable flag for the main module as requested
        aimKey = {
            key = KEY_LSHIFT,
            aimKeyName = "LSHIFT",
        },
        aimFov = 180,
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

-- Recursively checks that every key in 'expected' exists in 'loaded'.
-- If any key is missing or if a value expected to be a table is not one, returns false.
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

-- Creates a new Config instance.
-- @param scriptName The name of your script (used for folder and file naming)
function Config:new(scriptName)
    local self = setmetatable({}, Config)
    self.scriptName = scriptName or "DefaultScript"

    -- Define folder name and ensure it exists.
    self.folderName = string.format("Lua %s", self.scriptName)
    filesystem.CreateDirectory(self.folderName)

    -- Config file path (using JSON file extension)
    self.filePath = self.folderName .. "/" .. self.scriptName .. "_config.json"

    -- This will hold the loaded configuration.
    self.config = {}

    -- Attempt to load existing config (or create a new one if needed)
    self:Load()

    return self
end

-- Loads configuration from file.
-- If the file does not exist or if the structure is outdated, the default config is saved.
function Config:Load()
    local file = io.open(self.filePath, "r")
    if file then
        local content = file:read("*a")
        file:close()

        local loadedConfig, decodeErr = json.decode(content)
        if loadedConfig and deepCheck(defaultConfig, loadedConfig) and not input.IsButtonDown(KEY_LSHIFT) then
            self.config = loadedConfig
            printc(100, 183, 0, 255, "Success Loading Config: " .. self.filePath)
            -- Notify.Simple("Success! Loaded Config from", self.filePath, 5)
        else
            local warnMsg = decodeErr or "Config is outdated or invalid. Creating a new config."
            printc(255, 0, 0, 255, warnMsg)
            -- Notify.Simple("Warning", warnMsg, 5)
            self.config = defaultConfig
            self:Save()
        end
    else
        local warnMsg = "Config file not found. Creating a new config."
        printc(255, 0, 0, 255, warnMsg)
        -- Notify.Simple("Warning", warnMsg, 5)
        self.config = defaultConfig
        self:Save()
    end
end

-- Saves the current configuration to file in JSON format.
function Config:Save()
    local file = io.open(self.filePath, "w")
    if file then
        local content = json.encode(self.config)
        file:write(content)
        file:close()
        printc(100, 183, 0, 255, "Success Saving Config: " .. self.filePath)
        -- Notify.Simple("Success! Saved Config to:", self.filePath, 5)
    else
        local errMsg = "Failed to open file for writing: " .. self.filePath
        printc(255, 0, 0, 255, errMsg)
        -- Notify.Simple("Error", errMsg, 5)
    end
end

---------------------------------------------------
-- UNIT TESTING FUNCTION
-- Uncomment the call to run this function at the bottom if you want to test the module.
---------------------------------------------------
function Config:UnitTest()
    print("----- Running Config Unit Test -----")

    -- Create a new config instance for testing.
    local testScriptName = "UnitTestScript"
    local testConfigInstance = Config:new(testScriptName)

    -- Print the original config.
    print("Original config:")
    print(json.encode(testConfigInstance.config))

    -- Modify one value: change aimFov from 180 to 200.
    testConfigInstance.config.main.aimFov = 200
    print("Modified aimFov to:", testConfigInstance.config.main.aimFov)

    -- Save the modified config.
    testConfigInstance:Save()

    -- Create a new instance to force reload from file.
    local reloadConfigInstance = Config:new(testScriptName)
    print("Reloaded config:")
    print(json.encode(reloadConfigInstance.config))

    if reloadConfigInstance.config.main.aimFov == 200 then
        print("Unit Test Passed: aimFov correctly saved and loaded.")
    else
        print("Unit Test Failed: aimFov did not persist correctly.")
    end

    print("----- End of Unit Test -----")
end

---------------------------------------------------
-- Uncomment the following line to run the unit test when this module is executed.
--Config:UnitTest()

return Config
