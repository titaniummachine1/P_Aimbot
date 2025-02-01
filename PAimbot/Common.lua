---@diagnostic disable: duplicate-set-field, undefined-field
---@class Common
local Common = {}

--[[require modules]]--
local G = require("PAimbot.Globals")

pcall(UnloadLib) -- if it fails then forget about it it means it wasnt loaded in first place and were clean

-- Unload the module if it's already loaded
if package.loaded["ImMenu"] then
    package.loaded["ImMenu"] = nil
end

local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 1.0, "LNXlib version is too old, please update it!")

Common.Lib = Lib
Common.Log = Lib.Utils.Logger.new(G.scriptName)
Common.UI = Lib.UI
Common.Fonts = Common.UI.Fonts
Common.Notify = Common.UI.Notify
Common.TF2 = Common.Lib.TF2
Common.Utils = Common.Lib.Utils
Common.Math, Common.Conversion = Common.Utils.Math, Common.Utils.Conversion
Common.WPlayer, Common.PR = Common.TF2.WPlayer, Common.TF2.PlayerResource
Common.Helpers = Common.TF2.Helpers
Common.Prediction = Common.TF2.Prediction

-- Boring shit ahead!
Common.CROSS = (function(a, b, c) return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]); end);
Common.CLAMP = (function(a, b, c) return (a<b) and b or (a>c) and c or a; end);
Common.TRACE_HULL = engine.TraceHull;
Common.TRACE_Line = engine.TraceLine;
Common.WORLD2SCREEN = client.WorldToScreen;
Common.POLYGON = draw.TexturedPolygon;
Common.LINE = draw.Line;
Common.COLOR = draw.Color;

-- Function to normalize a vector
function Common.Normalize(vector)
    return vector / vector:Length()
end

--Returns whether the player is on the ground
---@return boolean
function Common.IsOnGround(player)
    local pFlags = player:GetPropInt("m_fFlags")
    return (pFlags & FL_ONGROUND) == 1
end

-- Helper functions can be defined here if needed
function Common.GetHitboxPos(player, hitboxID)
    local hitbox = player:GetHitboxes()[hitboxID]
    if not hitbox then return nil end

    return (hitbox[1] + hitbox[2]) * 0.5
end

-- Returns the name of a keycode
    ---@param key integer
    ---@return string|nil
    function Common.GetKeyName(key)
        return G.KeyNames[key]
    end

    -- Returns the string value of a keycode
    ---@param key integer
    ---@return string|nil
    function Common.KeyToChar(key)
        return G.KeyValues[key]
    end

    -- Returns the keycode of a string value
    ---@param char string
    ---@return integer|nil
    function Common.CharToKey(char)
        return table.find(G.KeyValues, string.upper(char))
    end

    -- Returns all currently pressed keys as a table
    ---@return integer[]
    function Common.GetPressedKeys()
        local keys = {}
        for i = KEY_FIRST, KEY_LAST do
            if input.IsButtonDown(i) then table.insert(keys, i) end
        end

        return keys
    end

    -- Update the GetPressedKey function to check for these additional mouse buttons
    function Common.GetPressedKey()
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

    
-- Calculate the start position and the view angle for the projectile's trajectory
local function GetStartPositionAndAngle(pLocal)
    -- The start position is the player's current position plus their view offset
    local vStartPosition = pLocal:GetAbsOrigin() + pLocal:GetPropVector("localdata", "m_vecViewOffset[0]")
    -- The view angle is the direction the player is looking
    local vStartAngle = engine.GetViewAngles()
    return vStartPosition, vStartAngle
end

-- Perform the initial hull trace to determine the starting point of the trajectory
local function PerformInitialTrace(vStartPosition, vStartAngle, vOffset, vCollisionMin, vCollisionMax, pWeapon)
    -- A trace (or raycast) is done from the start position in the direction of the projectile to see where it would first hit
    return Common.TRACE_HULL(
        vStartPosition,
        vStartPosition + (vStartAngle:Forward() * vOffset.x) +
        (vStartAngle:Right() * (vOffset.y * (pWeapon:IsViewModelFlipped() and -1 or 1))) +
        (vStartAngle:Up() * vOffset.z),
        vCollisionMin, vCollisionMax, 100679691
    )
end

-- Adjust the view angle if needed, based on the weapon type and collision results
local function AdjustViewAngleIfNeeded(iItemDefinitionType, fForwardVelocity, vStartPosition, vStartAngle, results)
    -- Certain weapons (like bows or crossbows) might need the angle adjusted for more accurate trajectory prediction
    if iItemDefinitionType == -1 or (iItemDefinitionType >= 7 and iItemDefinitionType < 11) and fForwardVelocity ~= 0 then
        -- Trace a straight line forward to correct the angle
        local res = Common.TRACE_Line(results.startpos, results.startpos + (vStartAngle:Forward() * 2000), 100679691)
        -- Adjust the angle based on where the trace ends
        vStartAngle = (((res.fraction <= 0.1) and (results.startpos + (vStartAngle:Forward() * 2000)) or res.endpos) - vStartPosition):Angles()
    end
    return vStartAngle
end

-- Calculate the velocity vector for the projectile based on the start angle and weapon stats
local function CalculateVelocity(vStartAngle, fForwardVelocity, fUpwardVelocity)
    -- The velocity is a combination of the forward velocity and any upward velocity (like from a grenade arc)
    return (vStartAngle:Forward() * fForwardVelocity) + (vStartAngle:Up() * fUpwardVelocity)
end

-- Handle the trajectory for straight-line projectiles (like rockets)
local function HandleStraightLineTrajectory(results, vStartAngle, vStartPosition)
    -- Perform a line trace to see where a straight-line projectile will go
    local traceResults = Common.TRACE_Line(vStartPosition, vStartPosition + (vStartAngle:Forward() * 10000), 100679691)
    if traceResults.startsolid then return traceResults end  -- Stop if the projectile starts inside a solid object

    -- Calculate how many segments of the line should be drawn
    local iSegments = math.floor((traceResults.endpos - traceResults.startpos):Length() / g_fFlagInterval)
    local vForward = vStartAngle:Forward()

    -- Insert points along the trajectory into the trajectory line
    for i = 1, iSegments do
        trajectoryLine:Insert(vForward * (i * g_fFlagInterval) + vStartPosition)
    end

    -- Insert the final end position
    trajectoryLine:Insert(traceResults.endpos)
    return traceResults
end

-- Handle the trajectory for arc-based projectiles (like grenades)
local function HandleArcTrajectory(results, vStartPosition, vVelocity, vCollisionMin, vCollisionMax, fGravity, fDrag)
    local traceResults = results
    local vPosition = Vector3(0, 0, 0)

    -- Simulate the projectile's movement over time
    for i = 0.01515, 5, g_fTraceInterval do
        -- Calculate the scalar based on whether drag is present or not
        local scalar = (not fDrag) and i or ((1 - math.exp(-fDrag * i)) / fDrag)

        -- Update the position based on the velocity, gravity, and time
        vPosition.x = vVelocity.x * scalar + vStartPosition.x
        vPosition.y = vVelocity.y * scalar + vStartPosition.y
        vPosition.z = (vVelocity.z - fGravity * i) * scalar + vStartPosition.z

        -- Trace the trajectory and check for collisions
        traceResults = vCollisionMax.x ~= 0 and Common.TRACE_HULL(traceResults.endpos, vPosition, vCollisionMin, vCollisionMax, 100679691)
            or Common.TRACE_Line(vStartPosition, vStartPosition + (vStartAngle:Forward() * 10000), 100679691)

        -- Insert the new position into the trajectory line
        trajectoryLine:Insert(traceResults.endpos)

        if traceResults.fraction ~= 1 then break end  -- Stop if the projectile hits something
    end
    return traceResults
end

-- Main function to trace and simulate the trajectory
local function TraceAndSimulateTrajectory(pLocal, pWeapon)

    -- Retrieve the projectile information and the type of weapon being used
    local projectileInfo, iItemDefinitionType = GetProjectileInformationObject(pLocal, pWeapon)
    if not iItemDefinitionType or not projectileInfo then 
        print("No valid projectile information available.")
        return 
    end

    -- Unpack the projectile information for easier access
    local vOffset, fForwardVelocity, fUpwardVelocity, vCollisionMax, fGravity, fDrag = table.unpack(projectileInfo)
    local vCollisionMin = -vCollisionMax

    -- Calculate the start position and angle for the trajectory
    local vStartPosition, vStartAngle = GetStartPositionAndAngle(pLocal)
    print("Start position:", vStartPosition)

    -- Perform the initial trace to determine where the projectile starts
    local traceResults = PerformInitialTrace(vStartPosition, vStartAngle, vOffset, vCollisionMin, vCollisionMax, pWeapon)
    if traceResults.fraction ~= 1 then 
        print("Initial trace hit something, stopping.")
        return 
    end
    vStartPosition = traceResults.endpos

    -- Adjust the view angle if necessary based on the weapon type
    vStartAngle = AdjustViewAngleIfNeeded(iItemDefinitionType, fForwardVelocity, vStartPosition, vStartAngle, traceResults)

    -- Calculate the projectile's velocity vector
    local vVelocity = CalculateVelocity(vStartAngle, fForwardVelocity, fUpwardVelocity)
    -- Update the flag offset for rendering the trajectory line
    trajectoryLine.flagOffset = vStartAngle:Right() * -G.Menu.flags.size
    -- Insert the initial position into the trajectory line
    trajectoryLine:Insert(vStartPosition)
    print("Initial position inserted into trajectory line:", vStartPosition)

    -- Handle the trajectory based on the type of projectile
    if iItemDefinitionType == -1 then
        traceResults = HandleStraightLineTrajectory(traceResults, vStartAngle, vStartPosition)
    elseif iItemDefinitionType > 3 then
        traceResults = HandleArcTrajectory(traceResults, vStartPosition, vVelocity, vCollisionMin, vCollisionMax, fGravity, fDrag)
    else
        --traceResults = HandlePhysicsBasedTrajectory(traceResults, vStartPosition, vStartAngle, vVelocity, vCollisionMin, vCollisionMax, iItemDefinitionType)
    end

    -- If no trajectory points were added, exit early
    if trajectoryLine.size == 0 then 
        print("No trajectory points were added, exiting.")
        return 
    end

    -- Draw the impact polygon at the final position of the trajectory
    DrawImpactPolygonIfNeeded(traceResults)

    -- Render the trajectory line if it has more than one point
    if trajectoryLine.size > 1 then
        print("Rendering trajectory line.")
        trajectoryLine:Render()
    end
end


--[[ Callbacks ]]
local function OnUnload() -- Called when the script is unloaded
    pcall(UnloadLib) --unloading lualib
    engine.PlaySound("hl1/fvox/deactivated.wav") --deactivated
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("Unload", G.scriptName .. "_Unload")                                -- unregister the "Unload" callback
--[[ Register callbacks ]]--
callbacks.Register("Unload", G.scriptName .. "_Unload", OnUnload)                         -- Register the "Unload" callback

--[[ Play sound when loaded ]]--
engine.PlaySound("hl1/fvox/activated.wav")

return Common
