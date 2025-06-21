--[[require modules]] --
local G = require("PAimbot.Globals")
local Common = require("PAimbot.Common")
local Config = require("PAimbot.Config")

local Menu = {}

local Lib = Common.Lib
local Fonts = Lib.UI.Fonts

---@type boolean, TimMenu
local menuLoaded, TimMenu = pcall(require, "TimMenu")
assert(menuLoaded, "TimMenu not found, please install it!")

Menu.lastToggleTime = 0
Menu.toggleCooldown = 0.1

-- Key binding helper
local bindTimer = 0
local bindDelay = 0.15

local function handleKeybind(noKeyText, keybind, keybindName)
    if keybindName ~= "Press The Key" and TimMenu.Button(keybindName or noKeyText) then
        bindTimer = os.clock() + bindDelay
        keybindName = "Press The Key"
    elseif keybindName == "Press The Key" then
        TimMenu.Text("Press the key")
    end

    if keybindName == "Press The Key" then
        if os.clock() >= bindTimer then
            local pressedKey = Common.GetPressedKey()
            if pressedKey then
                if pressedKey == KEY_ESCAPE then
                    keybind = 0
                    keybindName = "Always On"
                else
                    keybind = pressedKey
                    keybindName = Common.GetKeyName(pressedKey)
                    Common.Notify.Simple("Keybind Success", "Bound Key: " .. keybindName, 2)
                end
            end
        end
    end
    return keybind, keybindName
end



local function DrawMenu()
    -- Only show menu when GUI is visible and menu is open
    if not (gui.GetValue("Clean Screenshots") and engine.IsTakingScreenshot()) and gui.IsMenuOpen() and TimMenu.Begin("PAimbot - Projectile Aimbot", true) then
        draw.SetFont(Fonts.Verdana)
        draw.Color(255, 255, 255, 255)

        -- Tab system
        local tabNames = { "Main", "Advanced", "Visuals" }
        local currentTab = 1
        if Config.menu.tabs.main then
            currentTab = 1
        elseif Config.menu.tabs.advanced then
            currentTab = 2
        elseif Config.menu.tabs.visuals then
            currentTab = 3
        end

        local selectedTab = TimMenu.TabControl("main_tabs", tabNames, currentTab)

        -- Update tab states
        Config.menu.tabs.main = (selectedTab == 1)
        Config.menu.tabs.advanced = (selectedTab == 2)
        Config.menu.tabs.visuals = (selectedTab == 3)

        TimMenu.NextLine()

        -- Main Tab
        if Config.menu.tabs.main then
            Config.main.enable = TimMenu.Checkbox("Enable Aimbot", Config.main.enable)
            TimMenu.NextLine()

            if Config.main.enable then
                Config.main.silent = TimMenu.Checkbox("Silent Aim", Config.main.silent)
                TimMenu.NextLine()

                Config.main.autoShoot = TimMenu.Checkbox("Auto Shoot", Config.main.autoShoot)
                TimMenu.NextLine()

                Config.main.aimfov = TimMenu.Slider("Aim FOV", Config.main.aimfov, 0.1, 360, 0.1)
                TimMenu.NextLine()

                Config.main.minHitchance = TimMenu.Slider("Min Hit Chance", Config.main.minHitchance, 1, 100, 1)
                TimMenu.NextLine()

                Config.main.minDistance = TimMenu.Slider("Min Distance", Config.main.minDistance, 50, 500, 10)
                TimMenu.NextLine()

                Config.main.maxDistance = TimMenu.Slider("Max Distance", Config.main.maxDistance, 500, 3000, 50)
                TimMenu.NextLine()

                Config.main.aimKey.key = TimMenu.Keybind("Aim Key", Config.main.aimKey.key)
                TimMenu.NextLine()
            end
        end

        -- Advanced Tab with Sectors
        if Config.menu.tabs.advanced then
            -- Left Sector
            TimMenu.BeginSector("Prediction Settings")
            Config.advanced.strafePrediction = TimMenu.Checkbox("Strafe Prediction", Config.advanced.strafePrediction)
            TimMenu.NextLine()

            Config.advanced.splashPrediction = TimMenu.Checkbox("Splash Prediction", Config.advanced.splashPrediction)
            TimMenu.NextLine()

            if Config.advanced.splashPrediction then
                Config.advanced.splashAccuracy = TimMenu.Slider("Splash Accuracy", Config.advanced.splashAccuracy, 2, 20,
                    1)
                TimMenu.NextLine()
            end

            if Config.advanced.strafePrediction then
                Config.advanced.strafeSamples = TimMenu.Slider("Strafe Samples", Config.advanced.strafeSamples, 2, 20, 1)
                TimMenu.NextLine()
            end

            Config.advanced.predTicks = TimMenu.Slider("Prediction Ticks", Config.advanced.predTicks, 1, 200, 1)
            TimMenu.NextLine()
            TimMenu.EndSector()

            -- Right Sector
            TimMenu.BeginSector("Performance Settings")
            Config.advanced.hitchanceAccuracy = TimMenu.Slider("Hit Chance Accuracy", Config.advanced.hitchanceAccuracy,
                1, Config.advanced.predTicks, 1)
            TimMenu.NextLine()

            Config.advanced.accuracyWeight = TimMenu.Slider("Accuracy Weight", Config.advanced.accuracyWeight, 1, 10, 1)
            TimMenu.NextLine()

            Config.advanced.projectileSegments = TimMenu.Slider("Projectile Segments", Config.advanced
                .projectileSegments, 3, 50, 1)
            TimMenu.NextLine()

            Config.advanced.maxPredictionTicks = TimMenu.Slider("Max Prediction Ticks",
                Config.advanced.maxPredictionTicks or 132, 10, 300, 1)
            TimMenu.NextLine()

            Config.advanced.maxTargetsToPredict = TimMenu.Slider("Max Targets to Predict",
                Config.advanced.maxTargetsToPredict or 4, 1, 8, 1)
            TimMenu.NextLine()

            Config.advanced.maxTrackedTargets = TimMenu.Slider("Max Tracked Targets",
                Config.advanced.maxTrackedTargets or 8, 4, 8, 1)
            TimMenu.NextLine()
            TimMenu.EndSector()

            TimMenu.NextLine()
        end

        -- Visuals Tab
        if Config.menu.tabs.visuals then
            Config.visuals.active = TimMenu.Checkbox("Enable Visuals", Config.visuals.active)
            TimMenu.NextLine()

            if Config.visuals.active then
                Config.visuals.visualizePath = TimMenu.Checkbox("Visualize Player Path", Config.visuals.visualizePath)
                TimMenu.NextLine()

                Config.visuals.visualizeProjectile = TimMenu.Checkbox("Visualize Projectile Path",
                    Config.visuals.visualizeProjectile)
                TimMenu.NextLine()

                Config.visuals.visualizeHitPos = TimMenu.Checkbox("Visualize Hit Position",
                    Config.visuals.visualizeHitPos)
                TimMenu.NextLine()

                Config.visuals.crosshair = TimMenu.Checkbox("Crosshair", Config.visuals.crosshair)
                TimMenu.NextLine()

                Config.visuals.visualizeHitchance = TimMenu.Checkbox("Visualize Hit Chance",
                    Config.visuals.visualizeHitchance)
                TimMenu.NextLine()

                Config.visuals.nccPred = TimMenu.Checkbox("Nullcore Style Prediction", Config.visuals.nccPred)
                TimMenu.NextLine()

                if Config.visuals.visualizePath then
                    TimMenu.Text("Path Style:")
                    Config.visuals.path_styles_selected = TimMenu.Selector("Path Style",
                        Config.visuals.path_styles_selected, Config.visuals.path_styles)
                    TimMenu.NextLine()
                end

                TimMenu.Separator()
                TimMenu.NextLine()

                -- Polygon settings
                Config.visuals.polygon.enabled = TimMenu.Checkbox("Impact Polygon", Config.visuals.polygon.enabled)
                TimMenu.NextLine()

                if Config.visuals.polygon.enabled then
                    Config.visuals.polygon.size = TimMenu.Slider("Polygon Size", Config.visuals.polygon.size, 5, 50, 1)
                    TimMenu.NextLine()

                    Config.visuals.polygon.segments = TimMenu.Slider("Polygon Segments", Config.visuals.polygon.segments,
                        8, 32, 1)
                    TimMenu.NextLine()

                    Config.visuals.polygon.r = TimMenu.Slider("Polygon Red", Config.visuals.polygon.r, 0, 255, 1)
                    TimMenu.NextLine()

                    Config.visuals.polygon.g = TimMenu.Slider("Polygon Green", Config.visuals.polygon.g, 0, 255, 1)
                    TimMenu.NextLine()

                    Config.visuals.polygon.b = TimMenu.Slider("Polygon Blue", Config.visuals.polygon.b, 0, 255, 1)
                    TimMenu.NextLine()

                    Config.visuals.polygon.a = TimMenu.Slider("Polygon Alpha", Config.visuals.polygon.a, 0, 255, 1)
                    TimMenu.NextLine()
                end

                -- Line settings
                Config.visuals.line.enabled = TimMenu.Checkbox("Path Lines", Config.visuals.line.enabled)
                TimMenu.NextLine()

                if Config.visuals.line.enabled then
                    Config.visuals.line.r = TimMenu.Slider("Line Red", Config.visuals.line.r, 0, 255, 1)
                    TimMenu.NextLine()

                    Config.visuals.line.g = TimMenu.Slider("Line Green", Config.visuals.line.g, 0, 255, 1)
                    TimMenu.NextLine()

                    Config.visuals.line.b = TimMenu.Slider("Line Blue", Config.visuals.line.b, 0, 255, 1)
                    TimMenu.NextLine()

                    Config.visuals.line.a = TimMenu.Slider("Line Alpha", Config.visuals.line.a, 0, 255, 1)
                    TimMenu.NextLine()
                end
            end
        end



        TimMenu.End()
    end
end

--[[ Callbacks ]]
callbacks.Unregister("Draw", G.scriptName .. "_Menu")
callbacks.Register("Draw", G.scriptName .. "_Menu", DrawMenu)

return Menu
