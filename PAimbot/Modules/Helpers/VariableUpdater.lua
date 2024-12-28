local G = require("PAimbot.Globals")

-- Fill the tables
local function D(x) return x, x end
for i = 1, 10 do G.KeyNames[i], G.KeyValues[i] = D(tostring(i - 1)) end -- 0 - 9
for i = KEY_A, KEY_Z do G.KeyNames[i], G.KeyValues[i] = D(string.char(i + 54)) end -- A - Z
for i = KEY_PAD_0, KEY_PAD_9 do G.KeyNames[i], G.KeyValues[i] = "KP_" .. (i - 37), tostring(i - 37) end -- KP_0 - KP_9
for i = 92, 103 do G.KeyNames[i] = "F" .. (i - 91) end
for i = 1, 10 do local mouseButtonName = "MOUSE_" .. i G.KeyNames[MOUSE_FIRST + i - 1] = mouseButtonName G.KeyValues[MOUSE_FIRST + i - 1] = "Mouse Button " .. i end

local function UpdateVariables()
    -- Update the variables
    G.TickCount = globals.TickCount()
    G.TickInterval = globals.TickInterval()

    if not G.Target then return end
end

local function UpdateVariablesSlow()
    G.StepUp = Vector3(0, 0, entities.GetLocalPlayer():GetPropFloat("localdata", "m_flStepSize"))
    G.gravity = client.GetConVar("sv_gravity") -- Example G.gravity value, adjust as needed
end

-- Register the drawing callback for rendering the trajectory
callbacks.Unregister("CreateMove", G.scriptName .. "_UpdateVariables")
-- Register the drawing callback for rendering the trajectory
callbacks.Register("CreateMove", G.scriptName .. "_UpdateVariables", UpdateVariables)

-- Register the drawing callback for rendering the trajectory
callbacks.Unregister("FireGameEvent", G.scriptName .. "_UpdateVariablesSlow")
-- Register the drawing callback for rendering the trajectory
callbacks.Register("FireGameEvent", G.scriptName .. "_UpdateVariablesSlow", UpdateVariablesSlow)
