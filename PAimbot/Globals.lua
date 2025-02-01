local G = {}

G.scriptName = GetScriptName():match("([^/\\]+)%.lua$")

G.Hitbox = { Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82) }
G.TickInterval = globals.TickInterval()
G.TickCount = globals.TickCount()

G.history = {}
G.predictionDelta = {}

G.PredictionData = {
    PredPath = {};
}

local Hitbox = {
    Head = 1,
    Body = 5,
    Feet = 11,
}

G.Default_Menu = {
	CurrentTab = 1,

    Main = {
        AimKey = {
			key = KEY_LSHIFT,
			AimkeyName = "LSHIFT",
		},
		AimFov = 180,
		MinHitchance = 40,
        AutoShoot = true,
        Silent = true,
        AimPos = {
            CurrentAimPos = Hitbox.Feet;
			Arrow = Hitbox.Head;
            Projectile = Hitbox.Feet;
        },
		Aim_Modes = {
            Legit = 1,
            Rage = 2,
        },
    },

	Advanced = {
        SplashBot = true,
        SplashAccuracy = 5,
        PredTicks = 132,
        HistoryTicks = 66,
        Hitchance_Accuracy = 10,

        StrafePrediction = true,
        StrafeSamples = 17,

		-- 0.5 to 8, determines the size of the segments traced, lower values = worse performance (default 2.5)
		ProjectileSegments = 2.5,
        DebugInfo = true,
    },

	Visuals = {
		Active = true,
        VisualizePath = true,
        Path_styles = {"Line", "Alt Line", "Dashed"},
        Path_styles_selected = 2,
        VisualizeHitchance = true,
        VisualizeProjectile = true,
        VisualizeHitPos = true,
        Crosshair = true,
        NccPred = true,

		polygon = {
			enabled = true;
			r = 255;
			g = 200;
			b = 155;
			a = 50;

			size = 10;
			segments = 20;
		},

		line = {
			enabled = true;
			r = 255;
			g = 255;
			b = 255;
			a = 255;
		},

		flags = {
			enabled = true;
			r = 255;
			g = 0;
			b = 0;
			a = 255;

			size = 5;
		},

		outline = {
			line_and_flags = true;
			polygon = true;
			r = 0;
			g = 0;
			b = 0;
			a = 155;
		},
	},
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

G.Menu = G.Default_Menu

return G