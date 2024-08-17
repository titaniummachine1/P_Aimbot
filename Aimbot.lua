--[[
    Custom projectile Aimbot for Lmaobox
    author:
    https://github.com/titaniummachine1

    credit for proof of concept:
    https://github.com/lnx00

    credit for help with config and visuals:
    https://github.com/Muqa1
]]

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
local Input = lnxLib.Utils.Input
local Notify = lnxLib.UI.Notify

local Hitbox = {
    Head = 1,
    Neck = 2,
    Pelvis = 4,
    Body = 5,
    Chest = 7,
    Feet = 11,
}

local Menu = { -- this is the config that will be loaded every time u load the script

    tabs = { -- dont touch this, this is just for managing the tabs in the menu
        Main = true,
        Advanced = false,
        Visuals = false,
    },

    Main = {
        Active = true,
        AimKey = KEY_LSHIFT,
        AimkeyName = "LSHIFT",
        AutoShoot = true,
        Silent = true,
        AimPos = {
            CurrentAimPos = Hitbox.Head,
            Hitscan = Hitbox.Head,
            Projectile = Hitbox.Feet
        },
        AimFov = 60,
        MinDistance = 100,
        MaxDistance = 1500,
        MinHitchance = 40,
        closeHitChance = 40,
    },

    Advanced = {
        SplashPrediction = true,
        SplashAccuracy = 4,
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

local status, loadedMenu = pcall(function() 
    return assert(LoadCFG(string.format([[Lua %s]], Lua__fileName))) 
end) -- Auto-load config

-- Function to check if all expected functions exist in the loaded config
local function checkAllFunctionsExist(expectedMenu, loadedMenu)
    for key, value in pairs(expectedMenu) do
        if type(value) == 'function' then
            -- Check if the function exists in the loaded menu and has the correct type
            if not loadedMenu[key] or type(loadedMenu[key]) ~= 'function' then
                return false
            end
        end
    end
    for key, value in pairs(expectedMenu) do
        if not loadedMenu[key] or type(loadedMenu[key]) ~= type(value) then
            return false
        end
    end
    return true
end

-- Execute this block only if loading the config was successful
if status then
    if checkAllFunctionsExist(Menu, loadedMenu) and not input.IsButtonDown(KEY_LSHIFT) then
        Menu = loadedMenu
    else
        print("Config is outdated or invalid. Creating a new config.")
        CreateCFG(string.format([[Lua %s]], Lua__fileName), Menu) -- Save the config
    end
else
    print("Failed to load config. Creating a new config.")
    CreateCFG(string.format([[Lua %s]], Lua__fileName), Menu) -- Save the config
end

local latency = 0
local lerp = 0
local lastAngles = {} ---@type EulerAngles[]
local strafeAngles = {} ---@type number[]
local hitChance = 0
local lastPosition = {}
local priorPrediction = {}
local vPath = {}
local vHitbox = { Vector3(-22, -22, 0), Vector3(22, 22, 80) }
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

    function Normalize(vec)
        local length = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
        return Vector3(vec.x / length, vec.y / length, vec.z / length)
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
local DefaultHitbox = { Vector3(-0.2, -0.2, -0.2), Vector3(0.2, 0.2, 0.2)}
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

-- Normalize vector function
local function NormalizeVector(vector)
    local length = math.sqrt(vector.x * vector.x + vector.y * vector.y)
    if length == 0 then
        return Vector3(0, 0, vector.z)
    else
        return Vector3(vector.x / length, vector.y / length, vector.z / length)
    end
end

-- Rotate vector function
local function RotateVector(vector, angle)
    local rad = math.rad(angle)
    local cosAngle = math.cos(rad)
    local sinAngle = math.sin(rad)
    return Vector3(
        vector.x * cosAngle - vector.y * sinAngle,
        vector.x * sinAngle + vector.y * cosAngle,
        vector.z
    )
end

-- Define the necessary variables
local groundTrace = {}  -- Replace with the actual ground trace
local vUp = Vector3(0, 0, 1)  -- Replace with the actual up vector
local GROUND_COLLISION_ANGLE_LOW = 45  -- Replace with the actual value
local GROUND_COLLISION_ANGLE_HIGH = 60  -- Replace with the actual value
local FORWARD_COLLISION_ANGLE = 55 

local projectileSimulation = {}
local projectileSimulation2 = Vector3(0, 0, 0)

-- Helper function for forward collision
local function handleForwardCollision(vel, wallTrace)
    local normal = wallTrace.plane
    local angle = math.deg(math.acos(normal:Dot(vUp)))
    if angle > FORWARD_COLLISION_ANGLE then
        local dot = vel:Dot(normal)
        vel = vel - normal * dot
    end
    return wallTrace.endpos.x, wallTrace.endpos.y
end

-- Helper function for ground collision
local function handleGroundCollision(vel, groundTrace)
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
        print("lastPosition is NIL ~~!!!!")
        return 0
    end
    
    -- Calculate horizontal distance (2D distance on the X-Y plane)
    local horizontalDistance = math.sqrt((currentPos.x - lastPredictedPos.x)^2 + (currentPos.y - lastPredictedPos.y)^2)
    
    -- Calculate vertical distance with an allowance for vertical movement
    local verticalDistance = math.abs(currentPos.z - lastPredictedPos.z)
    
    -- Define maximum acceptable distances
    local maxHorizontalDistance = 12  -- Max acceptable horizontal distance in units
    local maxVerticalDistance = 45    -- Max acceptable vertical distance in units
    
    -- Normalize the distances to a 0-1 scale
    local horizontalFactor = math.min(horizontalDistance / maxHorizontalDistance, 1)
    local verticalFactor = math.min(verticalDistance / maxVerticalDistance, 1)
    
    -- Calculate the hit chance as a percentage
    local overallFactor = (horizontalFactor + verticalFactor) / 2
    
    -- Convert to a percentage where 100% is perfect and 0% is a miss
    local hitChancePercentage = (1 - overallFactor) * 100
    
    return hitChancePercentage
end


-- Helper function to check path clearance for side collisions
local function checkPathClearance(dest, direction, angle, distance, origin, target)
    -- Function to determine if an entity should be hit
    local shouldhitentity = function(entity) return entity:GetIndex() ~= target:GetIndex() end

    -- Calculate the point based on direction and angle
    local point = dest + RotateVector(direction, angle) * distance

    -- Perform a trace line from origin to the calculated point
    local traceLine = engine.TraceLine(origin, point, 100679691, shouldhitentity)

    -- Perform a trace line downwards from the calculated point to ensure it's on solid ground
    local traceDown = engine.TraceLine(point, point + Vector3(0, 0, -100), 100679691, shouldhitentity)

    -- Check if the end point is within an acceptable range to the target
    local distanceToTarget = (traceDown.endpos - dest):Length()
    if distanceToTarget > distance then
        local excessDistance = distanceToTarget - distance
        local directionToDest = NormalizeVector(traceDown.endpos - dest)
        traceDown.endpos = traceDown.endpos + directionToDest * excessDistance
    end

    -- Perform a final visibility check from the origin to the destination
    local visibilityCheck = engine.TraceLine(origin, dest, 100679691, shouldhitentity)
    if visibilityCheck.fraction > 0.9 then
        return false
    end

    return true, traceDown.endpos  -- Path is clear and within range
end

-- Function to find the best shooting position
local function FindBestShootingPosition(origin, dest, target, BlastRadius)
    -- Helper function to check path clearance in a given direction and angle
    local function checkPath(direction, angle, distance)
        local point = dest + RotateVector(direction, angle) * distance

        -- Perform a trace line from origin to the point
        local traceLineOriginToPoint = engine.TraceLine(origin, point, 100679691, function(entity) return entity:GetIndex() ~= target:GetIndex() end)

        -- Return whether the path is clear and the actual end position
        return traceLineOriginToPoint.fraction > 0.9, traceLineOriginToPoint.endpos
    end

    -- Perform an initial trace from origin to destination
    local initialTrace = engine.TraceLine(origin, dest, 100679691, function(entity) return entity:GetIndex() ~= target:GetIndex() end)

    -- If the initial trace hits something other than the target, find a better shooting position
    if initialTrace.fraction < 1 and initialTrace.entity:GetIndex() ~= target:GetIndex() then
        local direction = NormalizeVector(dest - origin)

        -- Check initial clearance for left and right using checkPathClearance
        local leftClear, leftMaxPoint = checkPathClearance(dest, direction, -90, BlastRadius, origin, target)
        local rightClear, rightMaxPoint = checkPathClearance(dest, direction, 90, BlastRadius, origin, target)

        -- Determine the side to perform binary search on and its maximum distance point
        local searchSide = nil
        local maxDistancePoint = nil

        if leftClear and rightClear then
            -- Determine which side is closer to the destination
            local leftDistance = (leftMaxPoint - dest):Length()
            local rightDistance = (rightMaxPoint - dest):Length()

            if leftDistance < rightDistance then
                searchSide = -90
                maxDistancePoint = leftMaxPoint
            else
                searchSide = 90
                maxDistancePoint = rightMaxPoint
            end
        elseif leftClear then
            searchSide = -90
            maxDistancePoint = leftMaxPoint
        elseif rightClear then
            searchSide = 90
            maxDistancePoint = rightMaxPoint
        end

        -- Perform binary search to find the closest shootable point to the destination
        if searchSide and maxDistancePoint then
            local minDistance = 0
            local maxDistance = (maxDistancePoint - dest):Length()
            local iterations = Menu.Advanced.SplashAccuracy or 5
            local bestPoint = maxDistancePoint  -- Start with the farthest point
            local bestDistance = maxDistance

            for i = 1, iterations do
                local midDistance = (minDistance + maxDistance) / 2
                local isClear, midPoint = checkPath(direction, searchSide, midDistance)

                if isClear then
                    local distanceToDest = (midPoint - dest):Length()
                    if distanceToDest < bestDistance then
                        bestDistance = distanceToDest
                        bestPoint = midPoint
                    end
                    maxDistance = midDistance
                else
                    minDistance = midDistance
                end
            end

            if bestPoint then
                projectileSimulation2 = bestPoint
                return bestPoint
            end
        end

        return false  -- No valid shooting position found
    end

    return dest  -- If the initial trace is clear, return the destination as the best shooting position
end

-- Precompute and cache frequently used constants and empty vectors
local EMPTY_VECTOR = Vector3(0, 0, 0)
local MASK_PLAYERSOLID = 100679691  -- Example value; replace with the actual value from your environment
local MIN_HIT_FRACTION = 1.0
local DRAG_CONSTANT = 0.029374  -- Combined drag coefficients

-- Calculates the angle needed to hit a target with a projectile
---@param origin Vector3
---@param dest Vector3
---@param speed number
---@param gravity number
---@param sv_gravity number
---@return { angles: EulerAngles, time : number }?
local function SolveProjectile(origin, dest, speed, gravity, sv_gravity, target, timeToHit)
    -- Cache vectors and precomputed values
    local v = dest - origin
    local v0_squared = speed * speed
    local g = sv_gravity * gravity
    local dx = v:Length2D()
    local dy = v.z

    -- Cache the entity filter function
    local shouldHitEntity = function(entity)
        return entity:GetIndex() ~= target:GetIndex() or entity:GetTeamNumber() ~= target:GetTeamNumber()
    end

    -- No gravity case
    if g == 0 then
        local time = v:Length() / speed
        if time > timeToHit then
            return false  -- Projectile will fly out of range
        end

        -- Path trace check
        local trace = engine.TraceLine(origin, dest, MASK_PLAYERSOLID)
        if trace.fraction ~= MIN_HIT_FRACTION and trace.entity:GetName() ~= target:GetName() then
            return false
        end

        return {
            angles = Math.PositionAngles(origin, dest),
            time = time,
            Prediction = dest,
            Positions = {origin, dest}
        }
    else
        -- Ballistic arc calculation
        local gdx_squared = g * dx * dx

        -- Solve the quadratic equation for projectile motion
        local root = v0_squared * v0_squared - g * (gdx_squared + 2 * dy * v0_squared)
        if root < 0 then return nil end

        -- Calculate pitch and yaw angles
        local sqrtRoot = math.sqrt(root)
        local pitch = math.atan((v0_squared - sqrtRoot) / (g * dx))
        local yaw = math.atan(v.y, v.x)

        if isNaN(pitch) or isNaN(yaw) then return nil end

        -- Precompute angles and constants
        local angles = EulerAngles(pitch * -M_RADPI, yaw * M_RADPI)
        local cosPitch = math.cos(pitch)
        local timeToTarget = dx / (cosPitch * speed)
        local numSegments = math.max(1, Menu.Advanced.ProjectileSegments or 2)
        local segmentLength = timeToTarget / numSegments
        local pos = origin
        local currentVelocity = speed

        -- Table to store positions along the projectile's path
        local projectileSimulation = {pos}

        -- Simulate the projectile's flight path
        for segment = 1, numSegments do
            local t = segment * segmentLength

            -- Apply drag to the current velocity
            currentVelocity = currentVelocity * math.exp(-DRAG_CONSTANT * t)

            -- Calculate the new position based on current velocity, angle, and gravity
            local x = currentVelocity * cosPitch * t
            local y = currentVelocity * math.sin(pitch) * t - 0.5 * g * t * t
            local newPos = origin + Vector3(x * math.cos(yaw), x * math.sin(yaw), y)

            -- Perform a trace to check for collisions
            local trace = engine.TraceLine(pos, newPos, MASK_PLAYERSOLID, shouldHitEntity)

            -- Save the new position
            table.insert(projectileSimulation, newPos)

            -- Check if the projectile collided with something that isn't the target
            if trace.fraction < MIN_HIT_FRACTION and trace.entity ~= target then
                return false  -- Collision detected, exit the loop
            end

            -- Update the current position for the next segment
            pos = newPos
        end

        -- Return the calculated angles, time to target, final predicted position, and all positions along the path
        return {
            angles = angles,
            time = timeToTarget,
            Prediction = pos,
            Positions = projectileSimulation
        }
    end
end


--Returns whether the player is on the ground
---@return boolean
local function IsOnGround(player)
    local pFlags = player:GetPropInt("m_fFlags")
    return (pFlags & FL_ONGROUND) == 1
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
    local vStep = Vector3(0, 0, stepSize / 2)
    vPath = {}
    local lastP, lastV, lastG = player:GetAbsOrigin(), player:EstimateAbsVelocity(), IsOnGround(player)
    local shouldHitEntity = shouldHitEntity or function(entity) return entity:GetIndex() ~= player:GetIndex() or entity:GetTeamNumber() ~= player:GetTeamNumber() end --trace ignore simulated player 
    local BlastRadious = 150

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
            pos.x, pos.y = handleForwardCollision(vel, wallTrace)
        end

        -- Ground Collision
        local downStep = onGround and vStep or Vector3()
        groundTrace = engine.TraceHull(pos + vStep, pos - downStep, vHitbox[1], vHitbox[2], MASK_PLAYERSOLID, shouldHitEntity)
        if groundTrace.fraction < 1 then
            pos, onGround = handleGroundCollision(vel, groundTrace)
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

        -- Initialize storage for predictions if not already initialized
        if not lastPosition[player:GetIndex()] then lastPosition[player:GetIndex()] = {} end
        if not priorPrediction[player:GetIndex()] then priorPrediction[player:GetIndex()] = {} end

        -- Hitchance check and synchronization of predictions
        if i <= PredTicks then
            local currentTick = PredTicks - i  -- Determine which tick in the future we're currently predicting

            -- Store the last prediction of the current tick
            lastPosition[player:GetIndex()][currentTick] = priorPrediction[player:GetIndex()][currentTick] or pos

            -- Update priorPrediction with the current predicted position for this tick
            priorPrediction[player:GetIndex()][currentTick] = pos

            -- If this is the last simulation tick or we're comparing predictions
            if i == 1 or currentTick == 1 then
                -- Calculate the hit chance percentage based on the difference between the last and current prediction
                hitChance = calculateHitChancePercentage(lastPosition[player:GetIndex()][currentTick], priorPrediction[player:GetIndex()][currentTick])

                -- Check if the calculated hit chance meets the minimum required threshold
                if hitChance < Menu.Main.MinHitchance then
                    return nil  -- If not, return nil to indicate that the prediction is not reliable
                end
            end
        end


        local solution = SolveProjectile(shootPos, pos, projInfo[1], projInfo[2], gravity, player, PredTicks * tick_interval)
        if solution == nil then goto continue end

        if not solution then
            if Menu.Advanced.SplashPrediction and projInfo[2] == 0 then
                local bestPos = FindBestShootingPosition(shootPos, pos, player, BlastRadious, shouldHitEntity)
                if bestPos then
                    solution = SolveProjectile(shootPos, bestPos, projInfo[1], projInfo[2], gravity, player, PredTicks * tick_interval)
                end
                --if solution == false then return nil end
            else
                return nil
            end
        end

        local time
        if solution and solution.time then
            time = solution.time + latency + lerp
        else
            return nil
        end

        local ticks = Conversion.Time_to_Ticks(time) + 1
        if ticks > i then goto continue end

        targetAngles = solution.angles
        break
        ::continue::
    end

    if not targetAngles or (player:GetAbsOrigin() - me:GetAbsOrigin()):Length() < 100 or not lastPosition[player:GetIndex()] then
        return nil
    end

    return { entity = player, angles = targetAngles, factor = fov, Prediction = vPath[#vPath] }
end

local function GetHitboxPos(player, hitboxID)
    local hitbox = player:GetHitboxes()[hitboxID]
    if not hitbox then return nil end

    return (hitbox[1] + hitbox[2]) * 0.5
end

-- Finds the best position for hitscan weapons
---@param me WPlayer
---@param weapon WWeapon
---@param player WPlayer
---@return AimTarget?
local function CheckHitscanTarget(me, weapon, player)
    -- FOV Check
    local aimPos = GetHitboxPos(player, Menu.Main.AimPos.Hitscan)
    if not aimPos then return nil end
    local angles = Math.PositionAngles(me:GetEyePos(), aimPos)
    local fov = Math.AngleFov(angles, engine.GetViewAngles())

    -- Visiblity Check
    if not Helpers.VisPos(player, WPlayer:GetLocal():GetViewPos(), GetHitboxPos(player, Menu.Main.AimPos.Hitscan) or Vector3(10,10,-110)) then return nil end

    -- The target is valid
    local target = { entity = player, angles = angles, factor = fov }
    return target
end

local function GetBestTarget(me, weapon)
    local players = entities.FindByClass("CTFPlayer")
    local bestTarget = nil
    local bestFactor = 0
    local localPlayerOrigin = me:GetAbsOrigin()
    local localPlayerViewAngles = engine.GetViewAngles()

    if weapon:IsShootingWeapon() then
        local projType = weapon:GetWeaponProjectileType()
            if projType == 1 then
                -- Hitscan weapon
                Menu.Main.AimPos.CurrentAimPos = Menu.Main.AimPos.Hitscan
            else
                -- Projectile weapon
                Menu.Main.AimPos.CurrentAimPos = Menu.Main.AimPos.Projectile
            end
    else
        return nil
    end


    for _, player in pairs(players) do
        if player == nil or not player:IsAlive()
        or player:IsDormant()
        or player == me or player:GetTeamNumber() == me:GetTeamNumber()
        or gui.GetValue("ignore cloaked") == 1 and player:InCond(4) then
            goto continue
        end

        local aimPos = GetHitboxPos(player, Menu.Main.AimPos.CurrentAimPos)

        local playerOrigin = player:GetAbsOrigin()
        local distance = math.abs(playerOrigin.x - localPlayerOrigin.x) +
                         math.abs(playerOrigin.y - localPlayerOrigin.y) +
                         math.abs(playerOrigin.z - localPlayerOrigin.z)

        local angles = Math.PositionAngles(localPlayerOrigin, playerOrigin)
        local fov = Math.AngleFov(angles, localPlayerViewAngles)

        if fov > Menu.Main.AimFov then
            goto continue
        end

        local distanceFactor = Math.RemapValClamped(distance, 50, 2500, 1, 0.09)
        local fovFactor = Math.RemapValClamped(fov, 0, Menu.Main.AimFov, 1, 0.7)
        local isVisible = Helpers.VisPos(player, localPlayerOrigin + Vector3(0,0,75), playerOrigin + Vector3(0,0,75))
        local visibilityFactor = isVisible and 1 or 0.5
        local factor = fovFactor * visibilityFactor * distanceFactor

        if factor > bestFactor then
            bestTarget = player
            bestFactor = factor
        end

        ::continue::
    end

    if bestTarget then
            -- TODO: Improve this
            if projType == 1 then
                -- Hitscan weapon
                --return CheckHitscanTarget(me, weapon, bestTarget)
            else
                -- Projectile weapon
                return CheckProjectileTarget(me, weapon, bestTarget)
            end
            --[[elseif weapon:IsMeleeWeapon() then
            -- TODO: Melee Aimbot]]
            return bestTarget
    else
        return nil
    end
end

---@param userCmd UserCmd
local function OnCreateMove(userCmd)
    if Menu.Main.AimKey == 107 and Menu.Main.AutoShoot then
        userCmd:SetButtons(userCmd:GetButtons() & ~IN_ATTACK)
    end

    if not input.IsButtonDown(Menu.Main.AimKey) then
        return
    end

    projectileSimulation2 = nil
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

    -- Aim at the target
    userCmd:SetViewAngles(currentTarget.angles:Unpack())
    if not Menu.Main.Silent then
        engine.SetViewAngles(currentTarget.angles)
    end

    -- Auto Shoot
    if Menu.Main.AutoShoot then
        if currentTarget == nil then return end

        if weapon:GetWeaponID() == TF_WEAPON_COMPOUND_BOW then
        --or weapon:GetWeaponID() == TF_WEAPON_PIPEBOMBLAUNCHER then
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
    local normalized_direction = Normalize(direction)
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

local function handleKeybind(noKeyText, keybind, keybindName)
    if KeybindName ~= "Press The Key" and ImMenu.Button(KeybindName or noKeyText) then
        bindTimer = os.clock() + bindDelay
        KeybindName = "Press The Key"
    elseif KeybindName == "Press The Key" then
        ImMenu.Text("Press the key")
    end

    if KeybindName == "Press The Key" then
        if os.clock() >= bindTimer then
            local pressedKey = GetPressedKey()
            if pressedKey then
                if pressedKey == KEY_ESCAPE then
                    -- Reset keybind if the Escape key is pressed
                    keybind = 0
                    KeybindName = "Always On"
                else
                    -- Update keybind with the pressed key
                    keybind = pressedKey
                    KeybindName = GetKeyName(pressedKey)
                    Notify.Simple("Keybind Success", "Bound Key: " .. KeybindName, 2)
                end
            end
        end
    end
    return keybind, keybindName
end

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
 
               --draw predicted local position with strafe prediction
               if projectileSimulation2 then
                local screenPos = client.WorldToScreen(projectileSimulation2)
                    if screenPos ~= nil then
                        draw.Line( screenPos[1] + 10, screenPos[2], screenPos[1] - 10, screenPos[2])
                        draw.Line( screenPos[1], screenPos[2] - 10, screenPos[1], screenPos[2] + 10)
                    end
                end
    
            if Menu.Visuals.VisualizeHitchance or Menu.Visuals.Crosshair or Menu.Visuals.NccPred then 
                if i == #vPath - 1 then 
                    local screenPos1 = client.WorldToScreen(pos1)
                    local screenPos2 = client.WorldToScreen(pos2)
            
                    if screenPos1 ~= nil and screenPos2 ~= nil then
                        if Menu.Visuals.VisualizeHitchance then
                            local width = draw.GetTextSize(math.floor(hitChance))
                            draw.Text(screenPos2[1] - math.floor(width / 2), screenPos2[2] + 20, math.floor(hitChance))
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
        end

        if ImMenu.Button("Advanced") then
            Menu.tabs.Main = false
            Menu.tabs.Advanced = true
            Menu.tabs.Visuals = false
        end

        if ImMenu.Button("Visuals") then
            Menu.tabs.Main = false
            Menu.tabs.Advanced = false
            Menu.tabs.Visuals = true
        end
        ImMenu.EndFrame()

        if Menu.tabs.Main then
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
            Menu.Main.AimFov = ImMenu.Slider("Fov", Menu.Main.AimFov , 0.1, 360, 0.1)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Main.MinHitchance = ImMenu.Slider("Min Hitchance", Menu.Main.MinHitchance , 1, 100)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
                Menu.Main.AimKey, Menu.Main.AimkeyName = handleKeybind("Aim Key: ", Menu.Main.AimKey, Menu.Main.AimkeyName)
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
                Menu.Advanced.SplashPrediction = ImMenu.Checkbox("Splash Prediction", Menu.Advanced.SplashPrediction)
            ImMenu.EndFrame()
            
            ImMenu.BeginFrame(1)
                Menu.Advanced.SplashAccuracy = ImMenu.Slider("Splash Accuracy", Menu.Advanced.SplashAccuracy, 2, 47)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
                Menu.Advanced.StrafeSamples = ImMenu.Slider("Strafe Samples", Menu.Advanced.StrafeSamples, 2, 49)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
                Menu.Advanced.PredTicks = ImMenu.Slider("PredTicks", Menu.Advanced.PredTicks , 1, 200)
            ImMenu.EndFrame()
            
            ImMenu.BeginFrame(1)
                Menu.Advanced.Hitchance_Accuracy = ImMenu.Slider("Accuracy", Menu.Advanced.Hitchance_Accuracy , 1, Menu.Advanced.PredTicks)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
                Menu.Advanced.ProjectileSegments = ImMenu.Slider("projectile Simulation Segments", Menu.Advanced.ProjectileSegments, 3, 50)
            ImMenu.EndFrame()

            --[[ImMenu.BeginFrame(1)
                Menu.Advanced.SplashAccuracy = ImMenu.Slider("Splash Accuracy", Menu.Advanced.SplashAccuracy, 2, 50)
            ImMenu.EndFrame()]]



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

        ImMenu.End()
    end
end

local function PropUpdate()
    --[[local pLocal = entities.GetLocalPlayer()
    if not input.IsButtonDown(KEY_RSHIFT) then
        return
    end
    --143 and 210 are indle for unscoped and scoped


    --for i = 1, entities.GetHighestEntityIndex() do -- index 1 is world entity
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

    --for i = 0, 23 do
        pLocal:SetPropDataTableFloat(100, i, "m_flPoseParameter")
    end
    local viewmodelData =  pLocal:GetPropDataTableFloat("m_flPoseParameter") --213 reload no scope , 211 reload scope, 
    --printLuaTable(viewmodelData)

    --viewmodel:GetPropDataTableFloat("m_vecOrigin")
    --print(viewmodel)


    --pLocal:SetPropDataTableFloat(1000, 0, 0)    
    --pLocal:SetPropVector(Vector3(10000, 10000, 100000), "m_bDrawViewmodel")
 
    --pLocal:SetPropInt(1000, "m_Resolution")
    --local resolution =  pLocal:GetPropVector("m_Resolution") --213 reload no scope , 211 reload scope, ]]
 
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