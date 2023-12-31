--[[
    Custom projectile Aimbot for Lmaobox
    author:
    https://github.com/titaniummachine1

    credit for proof of concept:
    https://github.com/lnx00

    credit for help with config and visuals:
    https://github.com/Muqa1
]]

local Hitbox = {
    Head = 1,
    Neck = 2,
    Pelvis = 4,
    Body = 5,
    Chest = 7,
    Feet = 11,
}

local AimModes = {
    Leading = true,
    Trailing = false,
}

local Menu = { -- this is the config that will be loaded every time u load the script

    tabs = { -- dont touch this, this is just for managing the tabs in the menu
        Main = true,
        Advanced = false,
        Visuals = false,
        Config = false,
    },

    Main = {
        Active = true,
        AimKey = KEY_LSHIFT,
        AimkeyName = "LSHIFT",
        Is_Listening_For_Key = false,
        AutoShoot = true,
        Silent = true,
        AimPos = {
            Hitscan = Hitbox.Head,
            Projectile = Hitbox.Feet
        },
        AimFov = 60,
        MinHitchance = 40,
    },

    Advanced = {
        PredTicks = 77,
        Hitchance_Accuracy = 10,
        StrafePrediction = true,
        StrafeSamples = 4,
        ProjectileSegments = 10,
        Aim_Modes = {
            Leading = true,
            trailing = false,
        },
        DebugInfo = true,
    },

    Visuals = {
        Active = true,
        VisualizePath = true,
        Path_styles = {"Line", "Alt Line", "Dashed"},
        Path_styles_selected = 1,
        VisualizeHitchance = false,
        VisualizeProjectile = false,
        VisualizeHitPos = false,
        Crosshair = false,
        NccPred = false
    },
}

    -- Contains pairs of keys and their names
    ---@type table<integer, string>
    local KeyNames = {
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
    local KeyValues = {
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

local Lua__fullPath = GetScriptName()
local Lua__fileName = Lua__fullPath:match("\\([^\\]-)$"):gsub("%.lua$", "")

local function CreateCFG(folder_name, table)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.cfg")
    local file = io.open(filepath, "w")
    
    if file then
        local function serializeTable(tbl, level)
            level = level or 0
            local result = string.rep("    ", level) .. "{\n"
            for key, value in pairs(tbl) do
                result = result .. string.rep("    ", level + 1)
                if type(key) == "string" then
                    result = result .. '["' .. key .. '"] = '
                else
                    result = result .. "[" .. key .. "] = "
                end
                if type(value) == "table" then
                    result = result .. serializeTable(value, level + 1) .. ",\n"
                elseif type(value) == "string" then
                    result = result .. '"' .. value .. '",\n'
                else
                    result = result .. tostring(value) .. ",\n"
                end
            end
            result = result .. string.rep("    ", level) .. "}"
            return result
        end
        
        local serializedConfig = serializeTable(table)
        file:write(serializedConfig)
        file:close()
        printc( 255, 183, 0, 255, "["..os.date("%H:%M:%S").."] Saved Config to ".. tostring(fullPath))
    end
end

local function LoadCFG(folder_name)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.cfg")
    local file = io.open(filepath, "r")

    if file then
        local content = file:read("*a")
        file:close()
        local chunk, err = load("return " .. content)
        if chunk then
            printc( 0, 255, 140, 255, "["..os.date("%H:%M:%S").."] Loaded Config from ".. tostring(fullPath))
            return chunk()
        else
            CreateCFG(string.format([[Lua %s]], Lua__fileName), Menu) --saving the config
            print("Error loading configuration:", err)
        end
    end
end

local status, loadedMenu = pcall(function() return assert(LoadCFG(string.format([[Lua %s]], Lua__fileName))) end) --auto load config

if status then --ensure config is not causing errors
    local allFunctionsExist = true
    for k, v in pairs(Menu) do
        if type(v) == 'function' then
            if not loadedMenu[k] or type(loadedMenu[k]) ~= 'function' then
                allFunctionsExist = false
                break
            end
        end
    end

    if allFunctionsExist then
        Menu = loadedMenu
    else
        print("config is outdated")
        CreateCFG(string.format([[Lua %s]], Lua__fileName), Menu) --saving the config
    end
end

local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")

local lastToggleTime = 0
local Lbox_Menu_Open = true
local function toggleMenu()
    local currentTime = globals.RealTime()
    if currentTime - lastToggleTime >= 0.1 then
        if Lbox_Menu_Open == false then
            Lbox_Menu_Open = true
        elseif Lbox_Menu_Open == true then
            Lbox_Menu_Open = false
        end
        lastToggleTime = currentTime
    end
end

---@alias AimTarget { entity : Entity, angles : EulerAngles, factor : number }

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.987, "lnxLib version is too old, please update it!")

local Math, Conversion = lnxLib.Utils.Math, lnxLib.Utils.Conversion
local WPlayer, WWeapon = lnxLib.TF2.WPlayer, lnxLib.TF2.WWeapon
local Helpers = lnxLib.TF2.Helpers
local Prediction = lnxLib.TF2.Prediction
local Fonts = lnxLib.UI.Fonts
local Notify = lnxLib.UI.Notify


local vHitbox = { Vector3(-1, -1, -1), Vector3(1, 1, 1) }

local latency = 0
local lerp = 0
local lastAngles = {} ---@type EulerAngles[]
local strafeAngles = {} ---@type number[]
local hitChance = 0
local lastPosition = {}
local priorPrediction = {}
local vPath = {}
local MAX_ANGLE_HISTORY = Menu.Advanced.StrafeSamples  -- Number of past angles to consider for averaging
local MAX_CENTER_HISTORY = 5 -- Maximum number of center samples to consider for smoothing

local strafeAngleHistories = {} -- History of strafe angles for each player
local centerHistories = {} -- History of center directions for each player

--[[
        Input Utils
    ]]

    ---@class Input
    local Input = {}

    -- Fill the tables
    local function D(x) return x, x end
    for i = 1, 10 do KeyNames[i], KeyValues[i] = D(tostring(i - 1)) end -- 0 - 9
    for i = 11, 36 do KeyNames[i], KeyValues[i] = D(string.char(i + 54)) end -- A - Z
    for i = 37, 46 do KeyNames[i], KeyValues[i] = "KP_" .. (i - 37), tostring(i - 37) end -- KP_0 - KP_9
    for i = 92, 103 do KeyNames[i] = "F" .. (i - 91) end
    for i = 1, 10 do local mouseButtonName = "MOUSE_" .. i KeyNames[MOUSE_FIRST + i - 1] = mouseButtonName KeyValues[MOUSE_FIRST + i - 1] = "Mouse Button " .. i end

    -- Returns the name of a keycode
    ---@param key integer
    ---@return string|nil
    local function GetKeyName(key)
        return KeyNames[key]
    end

    -- Returns the string value of a keycode
    ---@param key integer
    ---@return string|nil
    local function KeyToChar(key)
        return KeyValues[key]
    end

    -- Returns the keycode of a string value
    ---@param char string
    ---@return integer|nil
    local function CharToKey(char)
        return table.find(KeyValues, string.upper(char))
    end

    -- Update the GetPressedKey function to check for these additional mouse buttons
    local function GetPressedKey()
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

    -- Returns all currently pressed keys as a table
    ---@return integer[]
    local function GetPressedKeys()
        local keys = {}
        for i = KEY_FIRST, KEY_LAST do
            if input.IsButtonDown(i) then table.insert(keys, i) end
        end

        return keys
    end

    -- Define a table for centralized storage
    local dataStorage = {}

    -- Function to set or get values from the storage
    function DataStorage(key, value)
        -- If a value is provided, set it
        if value ~= nil then
            dataStorage[key] = value
        else
            -- If no value is provided, return the stored value
            return dataStorage[key]
        end
    end

---@param me WPlayer
local function CalcStrafe(me)
    local players = entities.FindByClass("CTFPlayer")

    for idx, entity in ipairs(players) do
        -- Reset data for dormant or dead players and teammates
        if entity:IsDormant() or not entity:IsAlive() or entity:GetTeamNumber() == me:GetTeamNumber() then
            strafeAngleHistories[idx] = nil
            centerHistories[idx] = nil
        else
            local angle = entity:EstimateAbsVelocity():Angles() -- get angle of velocity vector

            -- Initialize angle history for the player if needed
            strafeAngleHistories[idx] = strafeAngleHistories[idx] or {}
            centerHistories[idx] = centerHistories[idx] or {}

            -- Calculate the delta angle
            local delta = angle.y - (strafeAngleHistories[idx][#strafeAngleHistories[idx]] or 0)
            delta = Math.NormalizeAngle(delta)

            -- Update the angle history
            table.insert(strafeAngleHistories[idx], angle.y)
            if #strafeAngleHistories[idx] > MAX_ANGLE_HISTORY then
                table.remove(strafeAngleHistories[idx], 1)
            end

            -- Calculate the center direction based on recent strafe angles
            if #strafeAngleHistories[idx] >= 3 then
                local center = angle.y  -- Use the most recent angle as the center
                table.insert(centerHistories[idx], center)

                if #centerHistories[idx] > MAX_CENTER_HISTORY then
                    table.remove(centerHistories[idx], 1)
                end

                -- Use the most recent center direction
                local mostRecentCenter = centerHistories[idx][#centerHistories[idx]]

                -- Do something with mostRecentCenter
            end
        end
    end
end

-- Clamp function
local function clamp(a, b, c)
    return (a < b) and b or (a > c) and c or a
end

--[[local function GetProjectileInformation(ent, is_ducking, case)
    local m_flChargeBeginTime = (ent:GetPropFloat("PipebombLauncherLocalData", "m_flChargeBeginTime") or 0)
    if m_flChargeBeginTime ~= 0 then
        m_flChargeBeginTime = globals.CurTime() - m_flChargeBeginTime
    end
    
    local vecOffset, vecMaxs, velForward

    if case == -1 then  -- RocketLauncher, DragonsFury, Pomson, Bison
        vecOffset, vecMaxs = Vector3(23.5, -8, is_ducking and 8 or -3), Vector3(1, 1, 1)
        velForward = 1200
    elseif case == 1 then  -- StickyBomb
        vecOffset, vecMaxs = Vector3(16, 8, -6), Vector3(3, 3, 3)
        velForward = 900 + clamp(m_flChargeBeginTime / 4, 0, 1) * 1500
    elseif case == 2 then  -- QuickieBomb
        vecOffset, vecMaxs = Vector3(16, 8, -6), Vector3(3, 3, 3)
        velForward = 900 + clamp(m_flChargeBeginTime / 1.2, 0, 1) * 1500
    elseif case == 3 then  -- ScottishResistance, StickyJumper
        vecOffset, vecMaxs = Vector3(16, 8, -6), Vector3(3, 3, 3)
        velForward = 900 + clamp(m_flChargeBeginTime / 4, 0, 1) * 1500
    elseif case == 4 then  -- TheIronBomber
        vecOffset, vecMaxs = Vector3(16, 8, -6), Vector3(3, 3, 3)
        velForward = 1200
    elseif case == 5 then  -- GrenadeLauncher, LochnLoad
        vecOffset, vecMaxs = Vector3(16, 8, -6), Vector3(3, 3, 3)
        velForward = 1200
    elseif case == 6 then  -- LooseCannon
        vecOffset, vecMaxs = Vector3(16, 8, -6), Vector3(3, 3, 3)
        velForward = 1440
    elseif case == 7 then  -- Huntsman
        vecOffset, vecMaxs = Vector3(16, 8, -6), Vector3(1, 1, 1)
        velForward = 1800 + clamp(m_flChargeBeginTime, 0, 1) * 800
    elseif case == 8 then  -- FlareGuns
        vecOffset, vecMaxs = Vector3(23.5, 12, is_ducking and 8 or -3), Vector3(1, 1, 1)
        velForward = 2000
    elseif case == 9 then  -- CrusadersCrossbow, RescueRanger
        vecOffset, vecMaxs = Vector3(16, 8, -6), Vector3(2, 2, 2)
        velForward = 2400
    elseif case == 10 then  -- SyringeGuns
        vecOffset, vecMaxs = Vector3(16, 8, -6), Vector3(1, 1, 1)
        velForward = 1000
    else
        return nil
    end

    return vecOffset, vecMaxs, velForward
end]]

local M_RADPI = 180 / math.pi
local normalHitbox = { Vector3(-4, -4, -4), Vector3(4, 4, 4), Vector3(4, 4, 4)  }
-- Preliminary large hull check
local largeHitbox = { Vector3(-4, -4, -4), Vector3(4, 4, 4), Vector3(4, 4, 50)  }

-- Cache API calls for optimization
local atan = math.atan
local cos = math.cos
local sin = math.sin
local sqrt = math.sqrt
local floor = math.floor
local TickInterval = globals.TickInterval
local TraceLine = engine.TraceLine
local TraceHull = engine.TraceHull
local function isNaN(x) return x ~= x end

local projectileSimulation = {}
-- Calculates the angle needed to hit a target with a projectile
---@param origin Vector3
---@param dest Vector3
---@param speed number
---@param gravity number
---@param sv_gravity number
---@return { angles: EulerAngles, time : number }?
local function SolveProjectile(origin, dest, speed, gravity, sv_gravity, target, timeToHit)
    local v = dest - origin
    local v0 = speed
    local v0_squared = v0 * v0
    local g = sv_gravity * gravity

    local initialTrace = engine.TraceHull(origin, dest, largeHitbox[1], largeHitbox[2], MASK_PLAYERSOLID)
    local shouldUseDetailedHullTrace = initialTrace.fraction < 1 and initialTrace.entity ~= target

    if g == 0 then
        -- No gravity case
        local time = v:Length() / v0
        if time > timeToHit then
            return false  -- Player will move out of range
        end

        -- Visibility and hull trace check
        if not Helpers.VisPos(target:Unwrap(), origin, dest) then
            return false  -- Target is not visible
        end

        local trace = engine.TraceHull(origin, dest, normalHitbox[1], normalHitbox[2], MASK_PLAYERSOLID)
        if trace.fraction < 1 and trace.entity ~= target then
            return false  -- Collision with an object before reaching the target
        end

        return { angles = Math.PositionAngles(origin, dest), time = time, Prediction = dest }
    else
        -- Ballistic arc calculation
        local dx = v:Length2D()
        local dy = v.z
        local root = v0_squared * v0_squared - g * (g * dx * dx + 2 * dy * v0_squared)
        if root < 0 then return nil end

        local pitch = math.atan((v0_squared - math.sqrt(root)) / (g * dx))
        local yaw = math.atan(v.y, v.x)

        if isNaN(pitch) or isNaN(yaw) then return nil end

        local angles = EulerAngles(pitch * -M_RADPI, yaw * M_RADPI)
        local timeToTarget = dx / (math.cos(pitch) * v0)

        -- Adjusted simulation with segments and drag
        local numSegments = Menu.Advanced.ProjectileSegments or 2
        local segmentLength = timeToTarget / numSegments
        local pos = origin
        local trace
        local currentVelocity = v0

        -- Drag data
        local drag = 1
        local drag_basis = { 0.003902, 0.009962, 0.009962 }
        local ang_drag_basis = { 0.003618, 0.001514, 0.001514 }

        -- Calculate drag coefficient
        local dragCoefficient = drag * (drag_basis[1] + drag_basis[2] + drag_basis[3] + ang_drag_basis[1] + ang_drag_basis[2] + ang_drag_basis[3])

        -- Table to store positions
        projectileSimulation = {pos}

        for segment = 1, numSegments do
            local t = segment * segmentLength

            -- Apply drag to the velocity
            currentVelocity = currentVelocity * (1 - dragCoefficient * t)

            local x = currentVelocity * math.cos(pitch) * t
            local y = currentVelocity * math.sin(pitch) * t - 0.5 * g * t * t
            local newPos = origin + Vector3(x * math.cos(yaw), x * math.sin(yaw), y)

            if segment <= 10 or not shouldUseDetailedHullTrace then
                trace = engine.TraceLine(pos, newPos, MASK_SHOT_HULL)
            else
                trace = engine.TraceHull(pos, newPos, normalHitbox[1], normalHitbox[2], MASK_SHOT_HULL)
            end

            -- Save position
            table.insert(projectileSimulation, newPos)
            if trace.fraction < 1 and trace.entity ~= target then
                return false  -- Collision detected
            end

            pos = newPos
        end

        return { angles = angles, time = timeToTarget, Prediction = pos, Positions = positions }
    end
end








-- Assuming GetLocalPlayer() returns the local player entity object
--[[ Assuming Vector3 is a 3D vector class
function GetProjectileFireSetup(player, vecOffset, isAlternative)
    -- Get eye position of the player
    local eyePos = player:GetAbsOrigin() + player:GetPropVector("localdata", "m_vecViewOffset[0]")
    
    -- Get the forward, right, and up vectors based on view angles
    local forward, right, up = engine.GetViewAngles():Forward(), engine.GetViewAngles():Right(), engine.GetViewAngles():Up()
    
    -- Apply ducking offset if player is ducking
    if player:GetPropInt("m_fFlags") & FL_DUCKING then
        vecOffset = vecOffset * 0.75
    end

    -- Handle alternative firing modes (e.g., left-handed or right-handed)
    local isRight = true  -- Assuming the weapon is on the right side by default
    if isAlternative then
        isRight = not isRight
    end
    
    -- Flip the y-coordinate offset if the weapon is on the left side
    if not isRight then
        vecOffset.y = -vecOffset.y
    end

    -- Calculate the starting position for the projectile
    local startPos = Vector3(
        eyePos.x + forward.x * vecOffset.x + right.x * vecOffset.y + up.x * vecOffset.z,
        eyePos.y + forward.y * vecOffset.x + right.y * vecOffset.y + up.y * vecOffset.z,
        eyePos.z + forward.z * vecOffset.x + right.z * vecOffset.y + up.z * vecOffset.z
    )

    return startPos
end]]


local function calculateHitChancePercentage(lastPredictedPos, currentPos)
    if not lastPredictedPos then
        print("lastPosiion is NiLL ~~!!!!")
        return 0
    end
    local horizontalDistance = math.sqrt((currentPos.x - lastPredictedPos.x)^2 + (currentPos.y - lastPredictedPos.y)^2)

    local verticalDistanceUp = currentPos.z - lastPredictedPos.z + 10

    local verticalDistanceDown = (lastPredictedPos.z - currentPos.z) - 10
    
    -- You can adjust these values based on game's mechanics
    local maxHorizontalDistance = 16
    local maxVerticalDistanceUp = 45
    local maxVerticalDistanceDown = 0
    
    if horizontalDistance > maxHorizontalDistance or verticalDistanceUp > maxVerticalDistanceUp or verticalDistanceDown > maxVerticalDistanceDown then
        return 0 -- No chance to hit
    else
        local horizontalHitChance = 100 - (horizontalDistance / maxHorizontalDistance) * 100
        local verticalHitChance = 100 - (verticalDistanceUp / maxVerticalDistanceUp) * 100
        local overallHitChance = (horizontalHitChance + verticalHitChance) / 2
        return overallHitChance
    end
end

-- Constants
local FORWARD_COLLISION_ANGLE = 55
local GROUND_COLLISION_ANGLE_LOW = 45
local GROUND_COLLISION_ANGLE_HIGH = 55

-- Helper function for forward collision
local function handleForwardCollision(vel, wallTrace, vUp)
    local normal = wallTrace.plane
    local angle = math.deg(math.acos(normal:Dot(vUp)))
    if angle > FORWARD_COLLISION_ANGLE then
        local dot = vel:Dot(normal)
        vel = vel - normal * dot
    end
    return wallTrace.endpos.x, wallTrace.endpos.y
end

-- Helper function for ground collision
local function handleGroundCollision(vel, groundTrace, vUp)
    local normal = groundTrace.plane
    local angle = math.deg(math.acos(normal:Dot(vUp)))
    local onGround = false
    if angle < GROUND_COLLISION_ANGLE_LOW then
        onGround = true
    elseif angle < GROUND_COLLISION_ANGLE_HIGH then
        vel.x, vel.y, vel.z = 0, 0, 0
    else
        local dot = vel:Dot(normal)
        vel = vel - normal * dot
        onGround = true
    end
    if onGround then vel.z = 0 end
    return groundTrace.endpos, onGround
end

local shouldPredict = true

-- Main function
local function CheckProjectileTarget(me, weapon, player)
    local tick_interval = globals.TickInterval()
    local shootPos = me:GetEyePos()
    local aimPos = player:GetAbsOrigin() + Vector3(0, 0, 10)
    local aimOffset = aimPos - player:GetAbsOrigin()
    local gravity = client.GetConVar("sv_gravity")
    local stepSize = player:GetPropFloat("localdata", "m_flStepSize")
    local strafeAngle = Menu.Advanced.StrafePrediction and strafeAngles[player:GetIndex()] or nil
    local vUp = Vector3(0, 0, 1)
    vHitbox = { Vector3(-20, -20, 0), Vector3(20, 20, 80) }
    local vStep = Vector3(0, 0, stepSize / 2)
    vPath = {}
    local lastP, lastV, lastG = player:GetAbsOrigin(), player:EstimateAbsVelocity(), player:IsOnGround()
    local currpos
    local shouldHitEntity = shouldHitEntity or function(entity) return entity:GetIndex() ~= player:GetIndex() end --trace ignore simulated player 

    -- Check initial conditions
    local projInfo = weapon:GetProjectileInfo()
    if not projInfo or not gravity or not stepSize then return nil end

    local PredTicks = Menu.Advanced.PredTicks
    local speed = projInfo[1]
    if me:DistTo(player) > PredTicks * speed then return nil end

    local targetAngles, fov

    --[[if lastPosition[player:GetIndex()] and priorPrediction[player:GetIndex()] then
        hitChance = calculateHitChancePercentage(lastPosition[player:GetIndex()], priorPrediction[player:GetIndex()])
        if hitChance < Menu.Main.MinHitchance then
            shouldPredict = false
        else
            shouldPredict = true
        end
    end]]

    -- Main Loop for Prediction and Projectile Calculations
    for i = 1, PredTicks * 2 do
        local pos = lastP + lastV * tick_interval
        local vel = lastV
        local onGround = lastG

        -- Apply strafeAngle
        if strafeAngle then
            local ang = vel:Angles()
            ang.y = ang.y + strafeAngle
            vel = ang:Forward() * vel:Length()
        end

        -- Forward Collision
        local wallTrace = engine.TraceHull(lastP + vStep, pos + vStep, vHitbox[1], vHitbox[2], MASK_PLAYERSOLID, shouldHitEntity)
        if wallTrace.fraction < 1 then
            pos.x, pos.y = handleForwardCollision(vel, wallTrace, vUp)
        end

        -- Ground Collision
        local downStep = onGround and vStep or Vector3()
        local groundTrace = engine.TraceHull(pos + vStep, pos - downStep, vHitbox[1], vHitbox[2], MASK_PLAYERSOLID, shouldHitEntity)
        if groundTrace.fraction < 1 then
            pos, onGround = handleGroundCollision(vel, groundTrace, vUp)
        else
            onGround = false
        end

        -- Apply gravity if not on ground
        if not onGround then
            vel.z = vel.z - gravity * tick_interval
        end

        lastP, lastV, lastG = pos, vel, onGround

        -- Projectile Targeting Logic
        pos = lastP + aimOffset
        vPath[i] = pos --save path for visuals
    
        -- Hitchance check
        if i == Menu.Advanced.Hitchance_Accuracy or i == PredTicks then
            lastPosition[player:GetIndex()] = priorPrediction[player:GetIndex()]
            priorPrediction[player:GetIndex()] = pos

            hitChance = calculateHitChancePercentage(lastPosition[player:GetIndex()], priorPrediction[player:GetIndex()])
            shouldPredict = hitChance >= Menu.Main.MinHitchance

            if not shouldPredict then
                return nil
            end
        end

        local solution = SolveProjectile(shootPos, pos, projInfo[1], projInfo[2], gravity, player, PredTicks * tick_interval)
        if not solution then goto continue end
        if solution == false then return nil end

        fov = Math.AngleFov(solution.angles, engine.GetViewAngles())
        if fov > Menu.Main.AimFov then goto continue end

        local time = solution.time + latency + lerp
        local ticks = Conversion.Time_to_Ticks(time) + 1
        if ticks > i then goto continue end
        
        --if (solution.prediction - pos):Length() > 150 then goto continue end
        targetAngles = solution.angles
        break
        ::continue::
    end

    if not targetAngles or (player:GetAbsOrigin() - me:GetAbsOrigin()):Length() < 100 or not lastPosition[player:GetIndex()] then
        return nil
    end

    return { entity = player, angles = targetAngles, factor = fov, Prediction = vPath[#vPath] }
end

-- Finds the best position for hitscan weapons
---@param me WPlayer
---@param weapon WWeapon
---@param player WPlayer
---@return AimTarget?
local function CheckHitscanTarget(me, weapon, player)
    -- FOV Check
    local aimPos = player:GetHitboxPos(Menu.Main.AimPos.Hitscan)
    if not aimPos then return nil end
    local angles = Math.PositionAngles(me:GetEyePos(), aimPos)
    local fov = Math.AngleFov(angles, engine.GetViewAngles())

    -- Visiblity Check
    if not Helpers.VisPos(player:Unwrap(), me:GetEyePos(), aimPos) then return nil end

    -- The target is valid
    local target = { entity = player, angles = angles, factor = fov }
    return target
end

-- Checks the given target for the given weapon
---@param me WPlayer
---@param weapon WWeapon
---@param entity Entity
---@return AimTarget?
local function CheckTarget(me, weapon, entity)
    if not entity then return nil end
    if not entity:IsAlive() then return nil end
    if entity:GetTeamNumber() == me:GetTeamNumber() then return nil end

    local player = WPlayer.FromEntity(entity)

    if weapon:IsShootingWeapon() then
        -- TODO: Improve this

        local projType = weapon:GetWeaponProjectileType()
        if projType == 1 then
            -- Hitscan weapon
            return CheckHitscanTarget(me, weapon, player)
        else
            -- Projectile weapon
            return CheckProjectileTarget(me, weapon, player)
        end
    --[[elseif weapon:IsMeleeWeapon() then
        -- TODO: Melee Aimbot]]
    end

    return nil
end

local function GetBestTarget(me, weapon)
    local players = entities.FindByClass("CTFPlayer")
    local bestTarget = nil
    local bestFov = 360

    for _, player in pairs(players) do
        if player == nil or not player:IsAlive()
        or player:IsDormant()
        or player == me or player:GetTeamNumber() == me:GetTeamNumber()
        or gui.GetValue("ignore cloaked") == 1 and player:InCond(4) then
            goto continue
        end
        
        local angles = Math.PositionAngles(me:GetAbsOrigin(), player:GetAbsOrigin())
        local fov = Math.AngleFov(angles, engine.GetViewAngles())
        
        if fov > Menu.Main.AimFov then
            goto continue
        end

        if fov <= bestFov then
            bestTarget = player
            bestFov = fov
        end

        ::continue::
    end

    if bestTarget then
        bestTarget = CheckTarget(me, weapon, bestTarget)
    else
        return nil
    end
    
    return bestTarget
end

---@param userCmd UserCmd
local function OnCreateMove(userCmd)
    if Menu.AimKey == MOUSE_1 and Menu.Main.AutoShoot then
        userCmd:SetButtons(userCmd:GetButtons() & ~IN_ATTACK)
    end
    if not input.IsButtonDown(Menu.Main.AimKey) then
        return
    end

    local me = WPlayer.GetLocal()
    local pLocal = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end

    -- Calculate strafe angles (optional)
    if Menu.Advanced.StrafePrediction then
        CalcStrafe(me)
    end

    local weapon = me:GetActiveWeapon()
    if not weapon then return end

    -- Get current latency
    local latIn, latOut = clientstate.GetLatencyIn(), clientstate.GetLatencyOut()
    latency = (latIn or 0) + (latOut or 0)

    -- Get current lerp
    lerp = client.GetConVar("cl_interp") or 0

    -- Get the best target
    local currentTarget = GetBestTarget(me, weapon)
    if currentTarget == nil then
        return
    end

    --[[validate aimpos

    local angles = Math.PositionAngles(me:GetAbsOrigin(), currentTarget.Prediction)
    local fov = Math.AngleFov(angles, currentTarget.angles)
    
    if fov > 20 then return nil end -- skip if shooting random stuff]] 

    -- Aim at the target
    userCmd:SetViewAngles(currentTarget.angles:Unpack())
    if not Menu.Main.Silent then
        engine.SetViewAngles(currentTarget.angles)
    end

    -- Auto Shoot
    if Menu.Main.AutoShoot then
        if currentTarget == nil then return end

        if weapon:GetWeaponID() == TF_WEAPON_COMPOUND_BOW
        or weapon:GetWeaponID() == TF_WEAPON_PIPEBOMBLAUNCHER then
            -- Huntsman
            if weapon:GetChargeBeginTime() > 0 then
                userCmd.buttons = userCmd.buttons & ~IN_ATTACK
            else
                userCmd.buttons = userCmd.buttons | IN_ATTACK
            end
        else
            -- Normal weapon
            userCmd.buttons = userCmd.buttons | IN_ATTACK
        end
    end
    currentTarget = nil
end

local function convertPercentageToRGB(percentage)
    local value = math.floor(percentage / 100 * 255)
    return math.max(0, math.min(255, value))
end

local current_fps = 0
local last_fps_check = 0
local fps_check_interval = 8 -- check FPS every 100 frames
local fps_threshold = 59 -- increase values if FPS is equal to or higher than 59
local last_increase_frame = 0 -- last frame when values were increased

local font = draw.CreateFont( "Verdana", 12, 400, FONTFLAG_OUTLINE )

local function L_line(start_pos, end_pos, secondary_line_size)
    if not (start_pos and end_pos) then
        return
    end
    local direction = end_pos - start_pos
    local direction_length = direction:Length()
    if direction_length == 0 then
        return
    end
    local normalized_direction = direction / direction_length
    local perpendicular = Vector3(normalized_direction.y, -normalized_direction.x, 0) * secondary_line_size
    local w2s_start_pos = client.WorldToScreen(start_pos)
    local w2s_end_pos = client.WorldToScreen(end_pos)
    if not (w2s_start_pos and w2s_end_pos) then
        return
    end
    local secondary_line_end_pos = start_pos + perpendicular
    local w2s_secondary_line_end_pos = client.WorldToScreen(secondary_line_end_pos)
    if w2s_secondary_line_end_pos then
        draw.Line(w2s_start_pos[1], w2s_start_pos[2], w2s_end_pos[1], w2s_end_pos[2])
        draw.Line(w2s_start_pos[1], w2s_start_pos[2], w2s_secondary_line_end_pos[1], w2s_secondary_line_end_pos[2])
    end
end

local hitPos = {}
local function PlayerHurtEvent(event)
    if (event:GetName() == 'player_hurt' ) and Menu.Visuals.VisualizeHitPos then
        local localPlayer = entities.GetLocalPlayer();
        local victim = entities.GetByUserID(event:GetInt("userid"))
        local attacker = entities.GetByUserID(event:GetInt("attacker"))
        if (attacker == nil or localPlayer:GetIndex() ~= attacker:GetIndex()) then
            return
        end
        table.insert(hitPos, 1, {box = victim:HitboxSurroundingBox(), time = globals.RealTime()})
    end
    if #hitPos > 1 then 
        table.remove(hitPos)
    end
end
callbacks.Register("FireGameEvent", "PlayerHurtEvent", PlayerHurtEvent)

local clear_lines = 0
local bindTimer = 0
local bindDelay = 0.15  -- Delay of 0.2 seconds


local function OnDraw()
    local PredTicks = Menu.Advanced.PredTicks
    draw.SetFont(Fonts.Verdana)
    draw.Color(255, 255, 255, 255)

    if input.IsButtonPressed( KEY_INSERT )then
        toggleMenu()
    end
    --[[ Dynamic optymisator
    if globals.FrameCount() % fps_check_interval == 0 then
        current_fps = math.floor(1 / globals.FrameTime())
        last_fps_check = globals.FrameCount()

        if input.IsButtonDown(Menu.Main.AimKey) and targetFound then
            -- decrease values by 5 if FPS is less than 59
            if current_fps < 59 then
                --PredTicks = math.max(PredTicks - 1, 1)
                --Menu.Advanced.StrafeSamples = math.max(Menu.Advanced.StrafeSamples - 5, 4)
            end
            -- increase values every 100 frames if FPS is equal to or higher than 59 and aim key is pressed
            if current_fps >= fps_threshold and globals.FrameCount() - last_increase_frame >= 100 then
                PredTicks = PredTicks + 1
                Menu.Advanced.StrafeSamples = Menu.Advanced.StrafeSamples + 1
                last_increase_frame = globals.FrameCount()
            end
        end
    end]]

    
    if not input.IsButtonDown( Menu.Main.AimKey ) then
        if (globals.RealTime() > (clear_lines + 5)) then
            vPath = {}
            clear_lines = globals.RealTime()
        end
    else
        clear_lines = globals.RealTime()
    end
    -- Draw lines between the predicted positions
    if Menu.Visuals.Active and vPath then
        local startPos
        draw.SetFont(font)
        for i = 1, #vPath - 1 do
            local pos1 = vPath[i]
            local pos2 = vPath[i + 1]

            if i == 1 then 
                startPos = pos1
            end
                
            draw.Color(255 - math.floor((hitChance / 100) * 255), math.floor((hitChance / 100) * 255), 0, 255)

            if Menu.Visuals.VisualizeHitchance or Menu.Visuals.Crosshair or Menu.Visuals.NccPred then 
                if i == #vPath - 1 then 
                    local screenPos1 = client.WorldToScreen(pos1)
                    local screenPos2 = client.WorldToScreen(pos2)
            
                    if screenPos1 ~= nil and screenPos2 ~= nil then
                        if Menu.Visuals.VisualizeHitchance then
                            local width = draw.GetTextSize(math.floor(hitChance))
                            draw.Text(screenPos2[1] - math.floor(width / 2), screenPos2[2], math.floor(hitChance))
                        end
                        if Menu.Visuals.Crosshair then 
                            local c_size = 8
                            draw.Line(screenPos2[1] - c_size, screenPos2[2], screenPos2[1] + c_size, screenPos2[2])
                            draw.Line(screenPos2[1], screenPos2[2] - c_size, screenPos2[1], screenPos2[2] + c_size)
                        end
                        if Menu.Visuals.NccPred then 
                            local c_size = 5
                            draw.FilledRect(screenPos2[1] - c_size, screenPos2[2]  - c_size, screenPos2[1] + c_size, screenPos2[2]  + c_size)
                            local w2s = client.WorldToScreen(startPos)
                            if w2s and some_condition then  -- Replace `some_condition` with your actual condition.
                                draw.Line(w2s[1], w2s[2], screenPos2[1], screenPos2[2])
                            end
                        end                        
                    end
                end
            end

            if Menu.Visuals.VisualizePath then
                if Menu.Visuals.Path_styles_selected == 1 or Menu.Visuals.Path_styles_selected == 3 then 
                    local screenPos1 = client.WorldToScreen(pos1)
                    local screenPos2 = client.WorldToScreen(pos2)
            
                    if screenPos1 ~= nil and screenPos2 ~= nil and (not (Menu.Visuals.Path_styles_selected == 3) or i % 2 == 1) then
                        draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
                    end
                end
    
                if Menu.Visuals.Path_styles_selected == 2 then
                    L_line(pos1, pos2, 10)
                end

                if projectileSimulation and Menu.Visuals.VisualizeProjectile then
                    for i = 1, #projectileSimulation - 1 do
                        local pos1 = projectileSimulation[i]
                        local pos2 = projectileSimulation[i + 1]

                        if pos1 and pos2 then
                            if Menu.Visuals.Path_styles_selected == 1 or Menu.Visuals.Path_styles_selected == 3 then 
                                local screenPos1 = client.WorldToScreen(pos1)
                                local screenPos2 = client.WorldToScreen(pos2)
                        
                                if screenPos1 ~= nil and screenPos2 ~= nil and (not (Menu.Visuals.Path_styles_selected == 3) or i % 2 == 1) then
                                    draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
                                end
                            end
                            if Menu.Visuals.Path_styles_selected == 2 then
                                L_line(pos1, pos2, 10)
                            end
                        end
                    end
                end
            end
        end

        if Menu.Visuals.VisualizeHitPos then
            for i,v in pairs(hitPos) do 
                if globals.RealTime() - v.time > 1 then
                    table.remove(hitPos, i)
                else
                    draw.Color( 255,255,255,255 )
                    local hitboxes = v.box
                    local min = hitboxes[1]
                    local max = hitboxes[2]
                    local vertices = {
                        Vector3(min.x, min.y, min.z),
                        Vector3(min.x, max.y, min.z),
                        Vector3(max.x, max.y, min.z),
                        Vector3(max.x, min.y, min.z),
                        Vector3(min.x, min.y, max.z),
                        Vector3(min.x, max.y, max.z),
                        Vector3(max.x, max.y, max.z),
                        Vector3(max.x, min.y, max.z)
                    }
                    local screenVertices = {}
                    for j, vertex in ipairs(vertices) do
                        local screenPos = client.WorldToScreen(vertex)
                        if screenPos ~= nil then
                            screenVertices[j] = {x = screenPos[1], y = screenPos[2]}
                        end
                    end
                    for j = 1, 4 do
                        local vertex1 = screenVertices[j]
                        local vertex2 = screenVertices[j % 4 + 1]
                        local vertex3 = screenVertices[j + 4]
                        local vertex4 = screenVertices[(j + 4) % 4 + 5]
                        if vertex1 ~= nil and vertex2 ~= nil and vertex3 ~= nil and vertex4 ~= nil then
                            draw.Line(vertex1.x, vertex1.y, vertex2.x, vertex2.y)
                            draw.Line(vertex3.x, vertex3.y, vertex4.x, vertex4.y)
                        end
                    end
                    for j = 1, 4 do
                        local vertex1 = screenVertices[j]
                        local vertex2 = screenVertices[j + 4]
                        if vertex1 ~= nil and vertex2 ~= nil then
                            draw.Line(vertex1.x, vertex1.y, vertex2.x, vertex2.y)
                        end
                    end
                end   
            end
        end
    end

    if not Menu.Visuals.DebugInfo then
        draw.SetFont(Fonts.Verdana)
        draw.Color(255, 255, 255, 255)

        draw.Text(20, 120, "Pred Ticks: " .. PredTicks)
        draw.Text(20, 140, "Strafe Samples: " .. Menu.Advanced.StrafeSamples)
        draw.Text(20, 160, "fps: " .. current_fps)
        -- Draw current latency and lerp
        draw.Text(20, 180, string.format("Latency: %.2f", latency))
        draw.Text(20, 200, string.format("Lerp: %.2f", lerp))

        local me = WPlayer.GetLocal()
        if not me or not me:IsAlive() then goto continue end

        local weapon = me:GetActiveWeapon()
        if not weapon then goto continue end

            -- Draw current weapon
        draw.Text(20, 220, string.format("Weapon: %s", weapon:GetName()))
        draw.Text(20, 240, string.format("Weapon ID: %d", weapon:GetWeaponID()))
        draw.Text(20, 260, string.format("Weapon DefIndex: %d", weapon:GetDefIndex()))

        local greenValue = convertPercentageToRGB(hitChance)
        local blueValue = convertPercentageToRGB(hitChance)
        draw.Color(255, greenValue, blueValue, 255)
        draw.Text(20, 280, string.format("%.2f", hitChance) .. "% Hitchance")
    end
    

    --if Menu.Visuals.VisualizeProjectile then
    --draw predicted local position with strafe prediction
        -- local screenPos = client.WorldToScreen(shootpos1)
        -- if screenPos ~= nil then
        --     draw.Line( screenPos[1] + 10, screenPos[2], screenPos[1] - 10, screenPos[2])
        --     draw.Line( screenPos[1], screenPos[2] - 10, screenPos[1], screenPos[2] + 10)
        -- end
    --end
    ::continue::
    
    --if Menu.Visuals.VisualizeProjectile then
    --[[draw predicted local position with strafe prediction
        local screenPos = client.WorldToScreen(shootpos1)
        if screenPos ~= nil then
            draw.Line( screenPos[1] + 10, screenPos[2], screenPos[1] - 10, screenPos[2])
            draw.Line( screenPos[1], screenPos[2] - 10, screenPos[1], screenPos[2] + 10)
        end
    --end]]

    if Lbox_Menu_Open == true and ImMenu.Begin("Custom Projectile Aimbot", true) then -- managing the menu
        --local menuWidth, menuHeight = 2500, 3000
        ImMenu.BeginFrame(1) -- tabs
        if ImMenu.Button("Main") then
            Menu.tabs.Main = true
            Menu.tabs.Advanced = false
            Menu.tabs.Visuals = false
            Menu.tabs.Config = false
        end

        if ImMenu.Button("Advanced") then
            Menu.tabs.Main = false
            Menu.tabs.Advanced = true
            Menu.tabs.Visuals = false
            Menu.tabs.Config = false
        end

        if ImMenu.Button("Visuals") then
            Menu.tabs.Main = false
            Menu.tabs.Advanced = false
            Menu.tabs.Visuals = true
            Menu.tabs.Config = false
        end

        if ImMenu.Button("Config") then
            Menu.tabs.Main = false
            Menu.tabs.Advanced = false
            Menu.tabs.Visuals = false
            Menu.tabs.Config = true
        end
        ImMenu.EndFrame()

        if Menu.tabs.Main then
            ImMenu.BeginFrame(1)
            ImMenu.Text("Keybind: ")
            if Menu.Main.AimkeyName ~= "Press The Key" and ImMenu.Button(Menu.Main.AimkeyName) then
                Menu.Main.Is_Listening_For_Key = not Menu.Main.Is_Listening_For_Key
                if Menu.Main.Is_Listening_For_Key then
                    bindTimer = os.clock() + bindDelay
                    Menu.Main.AimkeyName = "Press The Key"
                else
                    Menu.Main.AimkeyName = "Always On"
                end
            elseif Menu.Main.AimkeyName == "Press The Key" then
                ImMenu.Text("Press the key")
            end

            if Menu.Main.Is_Listening_For_Key then
                if os.clock() >= bindTimer then
                    local pressedKey = GetPressedKey()
                    print("Pressed key: ", pressedKey)
                    if pressedKey then
                        if pressedKey == KEY_ESCAPE then
                            -- Reset keybind if the Escape key is pressed
                            Menu.Main.AimkeyName = "Always On"
                            Menu.Main.Is_Listening_For_Key = false
                        else
                            -- Update keybind with the pressed key
                            local keyName = GetKeyName(pressedKey) or ""
                            print("Key name: ", keyName)
                            Menu.Main.AimkeyName = string.gsub(keyName, "Key_", "")
                            Menu.Main.AimKey = pressedKey
                            print("Keybind Success", "Bound Key: " .. Menu.Main.AimKey)
                            Menu.Main.Is_Listening_For_Key = false
                        end
                    end
                end
            end
            ImMenu.EndFrame()

            --[[ImMenu.BeginFrame(1)
            Menu.Main.Active = ImMenu.Checkbox("Active", Menu.Main.Active)
            ImMenu.EndFrame()]]

            ImMenu.BeginFrame(1)
            Menu.Main.Silent = ImMenu.Checkbox("Silent", Menu.Main.Silent)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Main.AutoShoot = ImMenu.Checkbox("AutoShoot", Menu.Main.AutoShoot)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Main.AimFov = ImMenu.Slider("Fov", Menu.Main.AimFov , 0.1, 360)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Main.MinHitchance = ImMenu.Slider("Min Hitchance", Menu.Main.MinHitchance , 1, 100)
            ImMenu.EndFrame()

            --[[ImMenu.BeginFrame(1)
            ImMenu.Text("Hitbox")
            Menu.Main.AimPos.projectile = ImMenu.Option(Menu.Main.AimPos.projectile, Hitbox)
            ImMenu.EndFrame()]]
        end

        if Menu.tabs.Advanced then

            ImMenu.BeginFrame(1)
            Menu.Advanced.StrafePrediction = ImMenu.Checkbox("Strafe Pred", Menu.Advanced.StrafePrediction)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Advanced.PredTicks = ImMenu.Slider("PredTicks", Menu.Advanced.PredTicks , 1, 200)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Advanced.Hitchance_Accuracy = ImMenu.Slider("Accuracy", Menu.Advanced.Hitchance_Accuracy , 1, Menu.Advanced.PredTicks)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Advanced.StrafeSamples = ImMenu.Slider("Strafe Samples", Menu.Advanced.StrafeSamples , 2, 49)
            ImMenu.EndFrame()
    
            ImMenu.BeginFrame(1)
            Menu.Advanced.ProjectileSegments = ImMenu.Slider("projectile Simulation Segments", Menu.Advanced.ProjectileSegments, 3, 50)
            ImMenu.EndFrame()



            --[[ImMenu.BeginFrame(1)
            ImMenu.Text("Aim Mode")
            Menu.Advanced.Aim_Modes.projectiles = ImMenu.Option(Menu.Advanced.Aim_Modes.projectiles, AimModes)
            ImMenu.EndFrame()]]
        end

        if Menu.tabs.Visuals then 
            ImMenu.BeginFrame(1)
            Menu.Visuals.Active = ImMenu.Checkbox("Enable", Menu.Visuals.Active )
            ImMenu.EndFrame()

            if  Menu.Visuals.Active then 
                ImMenu.BeginFrame(1)
                Menu.Visuals.VisualizePath = ImMenu.Checkbox("Player Path", Menu.Visuals.VisualizePath)
                Menu.Visuals.VisualizeProjectile = ImMenu.Checkbox("Projectile Simulation", Menu.Visuals.VisualizeProjectile)
                ImMenu.EndFrame()
    
                ImMenu.BeginFrame(1)
                Menu.Visuals.VisualizeHitPos = ImMenu.Checkbox("Visualize Hit Pos", Menu.Visuals.VisualizeHitPos)
                Menu.Visuals.Crosshair = ImMenu.Checkbox("Crosshair", Menu.Visuals.Crosshair)
                Menu.Visuals.NccPred = ImMenu.Checkbox("Nullcore Pred Visuals", Menu.Visuals.NccPred)
                ImMenu.EndFrame()
    
                ImMenu.BeginFrame(1)
                Menu.Visuals.VisualizeHitchance = ImMenu.Checkbox("Visualize Hitchance", Menu.Visuals.VisualizeHitchance)
                ImMenu.EndFrame()

                if Menu.Visuals.VisualizePath then 
                    ImMenu.BeginFrame(1)
                    ImMenu.Text("Visualize Path Settings")
                    ImMenu.EndFrame()
                    ImMenu.BeginFrame(1)
                    Menu.Visuals.Path_styles_selected = ImMenu.Option(Menu.Visuals.Path_styles_selected, Menu.Visuals.Path_styles)
                    ImMenu.EndFrame()
                end
            end
        end

        if Menu.tabs.Config then 
            ImMenu.BeginFrame(1)
            if ImMenu.Button("Create/Save CFG") then
                CreateCFG( [[LBOX aimbot lua]] , Menu )
            end

            if ImMenu.Button("Load CFG") then
                Menu = LoadCFG( [[LBOX aimbot lua]] )
            end

            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            ImMenu.Text("Dont load a config if you havent saved one.")
            ImMenu.EndFrame()
        end

        ImMenu.End()
    end
end

local function PropUpdate()
    local pLocal = entities.GetLocalPlayer()
    if not input.IsButtonDown(KEY_RSHIFT) then
        return
    end
    --[143 and 210 are indle for unscoped and scoped


    for i = 1, entities.GetHighestEntityIndex() do -- index 1 is world entity
        local entity = entities.GetByIndex( i )
        if entity then
            --print( i, entity:GetClass() )
            local position = entity:GetPropVector("m_vecOrigin") -- Same assumption as above
            entity:SetPropVector(pLocal:GetAbsOrigin(), "m_vecOrigin")
            print(entity:GetClass(), position)
        end
    end

    local viewmodels = entities.FindByClass("CTFViewModel")

    for _, viewmodel in ipairs(viewmodels) do

    end


    local viewmodel = entities.FindByClass("CTFViewModel")[54]
    --print(viewmodel)

    --[[for i = 0, 23 do
        pLocal:SetPropDataTableFloat(100, i, "m_flPoseParameter")
    end]]
    local viewmodelData =  pLocal:GetPropDataTableFloat("m_flPoseParameter") --213 reload no scope , 211 reload scope, 
    --printLuaTable(viewmodelData)

    --viewmodel:GetPropDataTableFloat("m_vecOrigin")
    --print(viewmodel)


    --pLocal:SetPropDataTableFloat(1000, 0, 0)    
    --pLocal:SetPropVector(Vector3(10000, 10000, 100000), "m_bDrawViewmodel")
 
    --pLocal:SetPropInt(1000, "m_Resolution")
    --local resolution =  pLocal:GetPropVector("m_Resolution") --213 reload no scope , 211 reload scope, 
 
end

--[[ Remove the menu when unloaded ]]--
local function OnUnload()                                -- Called when the script is unloaded
    CreateCFG(string.format([[Lua %s]], Lua__fileName), Menu) --saving the config
    UnloadLib() --unloading lualib
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("PostPropUpdate","ProjCamProp")
callbacks.Register("PostPropUpdate","ProjCamProp", PropUpdate)

callbacks.Unregister("CreateMove", "LNX.Aimbot.CreateMove")
callbacks.Register("CreateMove", "LNX.Aimbot.CreateMove", OnCreateMove)

callbacks.Unregister("Unload", "LNX.Aimbot.OnUnload")
callbacks.Register("Unload", "LNX.Aimbot.OnUnload", OnUnload)

callbacks.Unregister("Draw", "LNX.Aimbot.Draw")
callbacks.Register("Draw", "LNX.Aimbot.Draw", OnDraw)
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded