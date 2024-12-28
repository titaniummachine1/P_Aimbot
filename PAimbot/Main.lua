--[[
    PAimbot lua
    Autor: Titaniummachine1
    Github: https://github.com/Titaniummachine1

    pasted stuff from GoodEveningFellOff - (https://github.com/GoodEveningFellOff/lmaobox-visualize-arc-trajectories)
]]

--[[ Activate the script Modules ]]
local G = require("PAimbot.Globals")
local Common = require("PAimbot.Common")
local Config = require("PAimbot.Config")
Config:Initialize() -- Initialize the config with the script name

--[[Classes]]--
local BestTarget = require("PAimbot.Modules.Helpers.BestTarget")
local HistoryHandler = require("PAimbot.Modules.Prediction.HistoryHandler")
local Prediction = require("PAimbot.Modules.Prediction.Prediction")
local ProjectileData = require("PAimbot.Modules.ProjectileData")

require("PAimbot.Modules.Helpers.VariableUpdater")
require("PAimbot.Visuals")

--local PhysicsEnvironment = require("PAimbot.Modules.PhysicsEnvironment")
--local PhysicsObjectHandler = require("PAimbot.Modules.PhysicsObjectHandler")
--[[Initialize the physics environment
local physicsEnv = PhysicsEnvironment.new()
physicsEnv:SetGravity(Vector3(0, 0, -client.GetConVar("sv_gravity")))
physicsEnv:SetAirDensity(2.0)
physicsEnv:SetSimulationTimestep(globals.TickInterval())

-- Initialize the physics objects
PhysicsObjectHandler:Initialize(physicsEnv)]]

--local TrajectoryLine = require("PAimbot.Modules.TrajectoryLine")
--local ImpactPolygon = require("PAimbot.Modules.ImpactPolygon")
--[[ Initialize Visuals ]]--
--local impactPolygon = ImpactPolygon:new(G.Menu)  -- Create a new ImpactPolygon instance with the provided config
--local trajectoryLine = TrajectoryLine:new()  -- Create a new TrajectoryLine instance

-- Check if the trajectory should be drawn
local function ShouldDrawVisuals()
    return not (engine.Con_IsVisible() or engine.IsGameUIVisible())
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

-- Validate the local player
local function IsValidLocalPlayer(pLocal)
    return pLocal and not pLocal:InCond(7) and pLocal:IsAlive()
end

-- Validate the weapon
local function IsValidWeapon(pWeapon)
    return pWeapon
    and (pWeapon:GetWeaponProjectileType() or 0) > 1
    and (pWeapon:IsShootingWeapon() ~= 1)
end

-- Function to draw the trajectory
local function CalcualteShots()
    local pLocal = entities.GetLocalPlayer()
        if not IsValidLocalPlayer(pLocal) then return end
    --local weapon = pLocal:GetPropEntity("m_hActiveWeapon")
     --   if not IsValidWeapon(weapon) then return end

    --local ProjData = ProjectileData.GetProjectileData(pLocal, weapon)
    --if not ProjData then return end

    --strafe angle history and accel and viewwangle stuff
    HistoryHandler:updateAllValidTargets()

    --finds best target
    G.Target = BestTarget.Get(pLocal)
    --if not G.Target then return end

    Prediction:update(pLocal)
    Prediction:predict(66)

    G.PredictionData.PredPath = Prediction:history()
end

local function OnUnload()
    Config:SaveConfig(G.Menu)
end

-- Register the drawing callback for rendering the trajectory
callbacks.Unregister("CreateMove", G.scriptName .. "_ProjectileAimbot")
callbacks.Unregister("Unload", G.scriptName .. "_CleanupObjects")

-- Register the drawing callback for rendering the trajectory
callbacks.Register("CreateMove", G.scriptName .. "_ProjectileAimbot", CalcualteShots)
callbacks.Register("Unload", G.scriptName .. "_CleanupObjects", OnUnload)