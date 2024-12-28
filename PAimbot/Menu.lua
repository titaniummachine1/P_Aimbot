
--[[require modules]]--
local G = require("Projectile_Visualizer.Globals")
local Common = require("Projectile_Visualizer.Common")

local Menu = {}


local Lib = Common.Lib
local Fonts = Lib.UI.Fonts

---@type boolean, ImMenu
local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")

Menu.lastToggleTime = 0
Menu.Lbox_Menu_Open = true
Menu.toggleCooldown = 0.1  -- 200 milliseconds

function Menu.HandleMenuShow()
    if input.IsButtonPressed(KEY_INSERT) then
        local currentTime = globals.RealTime()
        if currentTime - Menu.lastToggleTime >= Menu.toggleCooldown then
            Menu.Lbox_Menu_Open = not Menu.Lbox_Menu_Open  -- Toggle the state
            Menu.lastToggleTime = currentTime  -- Reset the last toggle time
        end
    end
end

local function DrawMenu()
    Menu.HandleMenuShow()

    if Menu.Lbox_Menu_Open == true and ImMenu.Begin("Movement", true) then
        draw.SetFont(Fonts.Verdana)
        draw.Color(255, 255, 255, 255)

        -- Enable_bhop
        ImMenu.BeginFrame(1)
            G.Menu.Enable = ImMenu.Checkbox("Enable", G.Menu.Enable)
        ImMenu.EndFrame()

        -- Enable_SmartJump
        ImMenu.BeginFrame(1)
            G.Menu.SmartJump = ImMenu.Checkbox("SmartJump", G.Menu.SmartJump)
        ImMenu.EndFrame()

        -- Enable_Visuals
        ImMenu.BeginFrame(1)
            --G.Menu.EdgeJump = true = ImMenu.Checkbox("bhop    ", Main.BhopDetection.Enable)
            G.Menu.Visuals = ImMenu.Checkbox("Visuals", G.Menu.Visuals)
        ImMenu.EndFrame()
    ImMenu.End()
    end
end

--[[ Callbacks ]]
callbacks.Unregister("Draw", G.Lua__fileName .. "_Menu")                                   -- unregister the "Draw" callback
callbacks.Register("Draw", G.Lua__fileName .. "_Menu", DrawMenu)                              -- Register the "Draw" callback 

return Menu