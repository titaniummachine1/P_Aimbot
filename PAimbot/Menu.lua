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
            -- Core Settings Section
            TimMenu.BeginSector("Core Settings")
            Config.main.enable = TimMenu.Checkbox("Enable Aimbot", Config.main.enable)
            TimMenu.NextLine()

            if Config.main.enable then
                Config.main.silent = TimMenu.Checkbox("Silent Aim", Config.main.silent)
                TimMenu.NextLine()

                Config.main.autoShoot = TimMenu.Checkbox("Auto Shoot", Config.main.autoShoot)
                TimMenu.NextLine()
            end
            TimMenu.EndSector()

            if Config.main.enable then
                TimMenu.NextLine()

                -- Targeting Settings Section
                TimMenu.BeginSector("Targeting Settings")
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
                TimMenu.EndSector()

                TimMenu.NextLine()

                -- Status Information Section
                TimMenu.BeginSector("Status Information")
                -- Display detailed motion analysis and predictability
                if G.Aimbot and G.Aimbot.MotionAnalysis then
                    local motion = G.Aimbot.MotionAnalysis
                    local predictabilityHitchance = G.Aimbot.PredictabilityHitchance or 0
                    local actualHitchance = G.Aimbot.HitChance or 0

                    TimMenu.Text(string.format("Predictability HC: %.1f%% | Actual HC: %.1f%%",
                        predictabilityHitchance, actualHitchance))
                    TimMenu.NextLine()

                    TimMenu.Text("Motion Analysis (current target):")
                    TimMenu.NextLine()

                    TimMenu.Text(string.format("Acceleration: %.1f | Jerk: %.1f",
                        motion.acceleration, motion.jerk))
                    TimMenu.NextLine()

                    TimMenu.Text(string.format("Snap: %.1f | Pop: %.1f | Strafe: %.1f",
                        motion.snap, motion.pop, motion.strafe))
                    TimMenu.NextLine()
                else
                    TimMenu.Text("No target selected")
                    TimMenu.NextLine()
                end
                TimMenu.EndSector()
            end
        end

        -- Advanced Tab with better organization
        if Config.menu.tabs.advanced then
            -- Targeting Mode Section
            TimMenu.BeginSector("Targeting Mode")
            TimMenu.Text("Select targeting behavior:")
            local targetingModes = { "Legit", "Blatant" }
            local currentMode = Config.advanced.targetingMode.legit and 1 or 2
            local selectedMode = TimMenu.TabControl("targeting_modes", targetingModes, currentMode)

            -- Update targeting mode based on selection
            Config.advanced.targetingMode.legit = (selectedMode == 1)
            Config.advanced.targetingMode.blatant = (selectedMode == 2)

            TimMenu.NextLine()
            if Config.advanced.targetingMode.legit then
                TimMenu.Text("Legit: Only targets visible enemies")
            else
                TimMenu.Text("Blatant: Can target enemies behind walls")
            end
            TimMenu.NextLine()
            TimMenu.EndSector()

            TimMenu.NextLine()

            -- Prediction Settings Section
            TimMenu.BeginSector("Prediction Settings")
            TimMenu.Text("Strafe Prediction: Always Enabled")
            TimMenu.NextLine()

            TimMenu.Text("Motion History: 500 ticks (for stable analysis)")
            TimMenu.NextLine()

            Config.advanced.predTicks = TimMenu.Slider("Prediction Ticks", Config.advanced.predTicks, 1, 200, 1)
            TimMenu.NextLine()

            Config.advanced.maxPredictionTicks = TimMenu.Slider("Max Prediction Ticks",
                Config.advanced.maxPredictionTicks or 132, 10, 300, 1)
            TimMenu.NextLine()
            TimMenu.EndSector()

            TimMenu.NextLine()

            -- Performance Settings Section
            TimMenu.BeginSector("Performance Settings")
            Config.advanced.projectileSegments = TimMenu.Slider("Projectile Segments", Config.advanced
                .projectileSegments, 3, 50, 1)
            TimMenu.NextLine()

            Config.advanced.maxTargetsToPredict = TimMenu.Slider("Max Targets to Predict",
                Config.advanced.maxTargetsToPredict or 4, 1, 8, 1)
            TimMenu.NextLine()

            Config.advanced.maxTrackedTargets = TimMenu.Slider("Max Tracked Targets",
                Config.advanced.maxTrackedTargets or 8, 4, 8, 1)
            TimMenu.NextLine()
            TimMenu.EndSector()

            TimMenu.NextLine()

            -- Splash Prediction Section
            TimMenu.BeginSector("Splash Prediction")
            Config.advanced.splashPrediction = TimMenu.Checkbox("Enable Splash Prediction",
                Config.advanced.splashPrediction)
            TimMenu.NextLine()

            if Config.advanced.splashPrediction then
                Config.advanced.splashAccuracy = TimMenu.Slider("Splash Accuracy", Config.advanced.splashAccuracy, 2, 20,
                    1)
                TimMenu.NextLine()
            end
            TimMenu.EndSector()

            TimMenu.NextLine()
        end

        -- Visuals Tab
        if Config.menu.tabs.visuals then
            -- Main Visual Settings
            TimMenu.BeginSector("Visual Settings")
            Config.visuals.active = TimMenu.Checkbox("Enable Visuals", Config.visuals.active)

            if Config.visuals.active then
                TimMenu.NextLine()
                Config.visuals.visualizePath = TimMenu.Checkbox("Player Path", Config.visuals.visualizePath)
                Config.visuals.visualizeProjectile = TimMenu.Checkbox("Projectile Path",
                    Config.visuals.visualizeProjectile)
                TimMenu.NextLine()
                Config.visuals.visualizeHitPos = TimMenu.Checkbox("Hit Position", Config.visuals.visualizeHitPos)
                Config.visuals.crosshair = TimMenu.Checkbox("Crosshair", Config.visuals.crosshair)
                TimMenu.NextLine()
                Config.visuals.visualizeHitchance = TimMenu.Checkbox("Hit Chance", Config.visuals.visualizeHitchance)
                Config.visuals.nccPred = TimMenu.Checkbox("NCC Style", Config.visuals.nccPred)

                if Config.visuals.visualizePath then
                    TimMenu.NextLine()
                    Config.visuals.path_styles_selected = TimMenu.Selector("Path Style",
                        Config.visuals.path_styles_selected, Config.visuals.path_styles)
                end
            end
            TimMenu.EndSector()

            if Config.visuals.active then
                TimMenu.NextLine()

                -- Path Line Settings
                TimMenu.BeginSector("Path Lines")
                Config.visuals.line.enabled = TimMenu.Checkbox("Enable Lines", Config.visuals.line.enabled)
                if Config.visuals.line.enabled then
                    TimMenu.NextLine()
                    Config.visuals.line.r = TimMenu.Slider("Red", Config.visuals.line.r, 0, 255, 1)
                    Config.visuals.line.g = TimMenu.Slider("Green", Config.visuals.line.g, 0, 255, 1)
                    TimMenu.NextLine()
                    Config.visuals.line.b = TimMenu.Slider("Blue", Config.visuals.line.b, 0, 255, 1)
                    Config.visuals.line.a = TimMenu.Slider("Alpha", Config.visuals.line.a, 0, 255, 1)
                end
                TimMenu.EndSector()

                TimMenu.NextLine()

                -- Impact Polygon Settings
                TimMenu.BeginSector("Impact Polygon")
                Config.visuals.polygon.enabled = TimMenu.Checkbox("Enable Polygon", Config.visuals.polygon.enabled)
                if Config.visuals.polygon.enabled then
                    TimMenu.NextLine()
                    Config.visuals.polygon.size = TimMenu.Slider("Size", Config.visuals.polygon.size, 5, 50, 1)
                    Config.visuals.polygon.segments = TimMenu.Slider("Segments", Config.visuals.polygon.segments, 8, 32,
                        1)
                    TimMenu.NextLine()
                    Config.visuals.polygon.r = TimMenu.Slider("Red", Config.visuals.polygon.r, 0, 255, 1)
                    Config.visuals.polygon.g = TimMenu.Slider("Green", Config.visuals.polygon.g, 0, 255, 1)
                    TimMenu.NextLine()
                    Config.visuals.polygon.b = TimMenu.Slider("Blue", Config.visuals.polygon.b, 0, 255, 1)
                    Config.visuals.polygon.a = TimMenu.Slider("Alpha", Config.visuals.polygon.a, 0, 255, 1)
                end
                TimMenu.EndSector()

                TimMenu.NextLine()

                -- Outline Settings
                TimMenu.BeginSector("Outlines")
                Config.visuals.outline.line_and_flags = TimMenu.Checkbox("Line Outline",
                    Config.visuals.outline.line_and_flags)
                Config.visuals.outline.polygon = TimMenu.Checkbox("Polygon Outline", Config.visuals.outline.polygon)

                if Config.visuals.outline.line_and_flags or Config.visuals.outline.polygon then
                    TimMenu.NextLine()
                    Config.visuals.outline.r = TimMenu.Slider("Red", Config.visuals.outline.r, 0, 255, 1)
                    Config.visuals.outline.g = TimMenu.Slider("Green", Config.visuals.outline.g, 0, 255, 1)
                    TimMenu.NextLine()
                    Config.visuals.outline.b = TimMenu.Slider("Blue", Config.visuals.outline.b, 0, 255, 1)
                    Config.visuals.outline.a = TimMenu.Slider("Alpha", Config.visuals.outline.a, 0, 255, 1)
                end
                TimMenu.EndSector()
            end
        end



        TimMenu.End()
    end
end

--[[ Callbacks ]]
callbacks.Unregister("Draw", G.scriptName .. "_Menu")
callbacks.Register("Draw", G.scriptName .. "_Menu", DrawMenu)

return Menu
