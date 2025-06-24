local G = {}

G.scriptName = GetScriptName():match("([^/\\]+)%.lua$")

G.Hitbox = { Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82) }
G.TickInterval = globals.TickInterval()
G.TickCount = globals.TickCount()

G.history = {}
G.predictionDelta = {}

G.PredictionData = {
    PredPath = {},
}

-- Aimbot specific data
G.Aimbot = {
    Target = nil,
    CurrentAngles = nil,
    HitChance = 0,
    PredictabilityHitchance = 0, -- Hitchance based on motion predictability
    CanEngage = false,           -- Whether aimbot can engage based on predictability
    ReadyToShoot = false,        -- Whether we're ready to shoot (aim key + predictable target)
    MotionAnalysis = {           -- Detailed motion analysis for current target
        acceleration = 0,
        jerk = 0,
        snap = 0,
        pop = 0,
        strafe = 0,
        hitchance = 0
    },
    ProjectilePath = {},
    TargetPredictionPath = {},
    LatencyData = {
        latency = 0,
        lerp = 0,
    },
    TargetData = {},
}

-- Projectile simulation data
G.ProjectileSimulation = {
    TrajectoryPath = {},
    SplashPosition = nil,
    ImpactPosition = nil,
    TimeToTarget = 0,
}

-- Hit chance tracking
G.HitChanceData = {
    lastPositions = {},
    priorPredictions = {},
    hitChanceRecords = {},
}

local Hitbox = {
    Head = 1,
    Body = 5,
    Feet = 11,
}

-- Contains pairs of keys and their names
---@type table<integer, string>
G.KeyNames = {
    [KEY_SEMICOLON] = "SEMICOLON",
    [KEY_APOSTROPHE] = "APOSTROPHE",
    [KEY_BACKQUOTE] = "BACKQUOTE",
    [KEY_COMMA] = "COMMA",
    [KEY_PERIOD] = "PERIOD",
    [KEY_SLASH] = "SLASH",
    [KEY_BACKSLASH] = "BACKSLASH",
    [KEY_MINUS] = "MINUS",
    [KEY_EQUAL] = "EQUAL",
    [KEY_ENTER] = "ENTER",
    [KEY_SPACE] = "SPACE",
    [KEY_BACKSPACE] = "BACKSPACE",
    [KEY_TAB] = "TAB",
    [KEY_CAPSLOCK] = "CAPSLOCK",
    [KEY_NUMLOCK] = "NUMLOCK",
    [KEY_ESCAPE] = "ESCAPE",
    [KEY_SCROLLLOCK] = "SCROLLLOCK",
    [KEY_INSERT] = "INSERT",
    [KEY_DELETE] = "DELETE",
    [KEY_HOME] = "HOME",
    [KEY_END] = "END",
    [KEY_PAGEUP] = "PAGEUP",
    [KEY_PAGEDOWN] = "PAGEDOWN",
    [KEY_BREAK] = "BREAK",
    [KEY_LSHIFT] = "LSHIFT",
    [KEY_RSHIFT] = "RSHIFT",
    [KEY_LALT] = "LALT",
    [KEY_RALT] = "RALT",
    [KEY_LCONTROL] = "LCONTROL",
    [KEY_RCONTROL] = "RCONTROL",
    [KEY_UP] = "UP",
    [KEY_LEFT] = "LEFT",
    [KEY_DOWN] = "DOWN",
    [KEY_RIGHT] = "RIGHT",
}

-- Contains pairs of keys and their values
---@type table<integer, string>
G.KeyValues = {
    [KEY_LBRACKET] = "[",
    [KEY_RBRACKET] = "]",
    [KEY_SEMICOLON] = ";",
    [KEY_APOSTROPHE] = "'",
    [KEY_BACKQUOTE] = "`",
    [KEY_COMMA] = ",",
    [KEY_PERIOD] = ".",
    [KEY_SLASH] = "/",
    [KEY_BACKSLASH] = "\\",
    [KEY_MINUS] = "-",
    [KEY_EQUAL] = "=",
    [KEY_SPACE] = " ",
}

-- Constants for projectile simulation
G.Constants = {
    MASK_PLAYERSOLID = 100679691,
    FULL_HIT_FRACTION = 1.0,
    DRAG_COEFFICIENT = 0.029374,
    M_RADPI = 180 / math.pi,
    EMPTY_VECTOR = Vector3(0, 0, 0),
}

G.Menu = G.Default_Menu

return G
