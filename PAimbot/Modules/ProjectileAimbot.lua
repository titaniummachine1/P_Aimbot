---@diagnostic disable: unused-function
---@diagnostic disable: undefined-global

--[[
    ProjectileAimbot Module
    Restored working prediction approach from original Aimbot.lua
]]

-- Dependencies
local G = require("PAimbot.Globals")
local Common = require("PAimbot.Common")
local Config = require("PAimbot.Config")
local BestTarget = require("PAimbot.Modules.Helpers.BestTarget")
local ProjectileData = require("PAimbot.Modules.ProjectileData")

-- Module declaration
local ProjectileAimbot = {}

-- Cache frequently used functions for performance
local M_RADPI = 180 / math.pi
local atan = math.atan
local cos = math.cos
local sin = math.sin
local sqrt = math.sqrt
local floor = math.floor
local TickInterval = globals.TickInterval
local TraceLine = engine.TraceLine
local TraceHull = engine.TraceHull

-- Physics constants (no drag needed for TF2 projectiles)

local function isNaN(x) return x ~= x end

-- Helper function for forward collision (from original working code)
local function handleForwardCollision(vel, wallTrace)
    local vUp = Vector3(0, 0, 1)
    local FORWARD_COLLISION_ANGLE = 55
    local normal = wallTrace.plane
    local angle = math.deg(math.acos(normal:Dot(vUp)))
    if angle > FORWARD_COLLISION_ANGLE then
        local dot = vel:Dot(normal)
        vel = vel - normal * dot
    end
    return wallTrace.endpos.x, wallTrace.endpos.y
end

-- Helper function for ground collision (from original working code)
local function handleGroundCollision(vel, groundTrace)
    local vUp = Vector3(0, 0, 1)
    local GROUND_COLLISION_ANGLE_LOW = 45
    local GROUND_COLLISION_ANGLE_HIGH = 60
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

-- Find best splash position for hitting hidden targets
local function FindBestSplashPosition(origin, targetPos, target)
    local BlastRadius = 150 -- Standard TF2 explosive radius
    local shouldHitEntity = function(entity)
        return entity:GetIndex() ~= target:GetIndex() and entity:GetTeamNumber() ~= target:GetTeamNumber()
    end

    -- Check if direct shot is blocked
    local directTrace = TraceLine(origin, targetPos, G.Constants.MASK_PLAYERSOLID, shouldHitEntity)
    if directTrace.fraction > 0.9 then
        return targetPos -- Direct shot is clear, no need for splash
    end

    -- Try shooting at nearby surfaces for splash damage
    local directions = {
        Vector3(1, 0, 0),  -- Right
        Vector3(-1, 0, 0), -- Left
        Vector3(0, 1, 0),  -- Forward
        Vector3(0, -1, 0), -- Back
        Vector3(0, 0, -1), -- Down (ground)
    }

    local bestSplashPos = nil
    local bestDistance = math.huge

    for _, dir in ipairs(directions) do
        -- Cast ray from target position outward to find nearby walls/ground
        local splashTrace = TraceLine(targetPos, targetPos + dir * BlastRadius, G.Constants.MASK_PLAYERSOLID,
            shouldHitEntity)

        if splashTrace.fraction < 1.0 then
            local splashPos = splashTrace.endpos
            local distanceToTarget = (splashPos - targetPos):Length()

            -- Check if we can shoot at this splash position
            local shootTrace = TraceLine(origin, splashPos, G.Constants.MASK_PLAYERSOLID, shouldHitEntity)

            -- Valid splash position if:
            -- 1. We can shoot at it (clear line of sight)
            -- 2. It's within blast radius of target
            -- 3. It's closer than previous candidates
            if shootTrace.fraction > 0.9 and distanceToTarget < BlastRadius and distanceToTarget < bestDistance then
                bestSplashPos = splashPos
                bestDistance = distanceToTarget
            end
        end
    end

    return bestSplashPos
end

-- Solve projectile trajectory (exact copy from working original)
-- Enhanced projectile simulation with proper collision detection
local function SimulateProjectileTrajectory(origin, dest, speed, gravity, sv_gravity, target, timeToHit, projData)
    local direction = dest - origin
    local speed_squared = speed * speed
    local effective_gravity = sv_gravity * gravity
    local horizontal_distance = direction:Length2D()
    local vertical_distance = direction.z

    -- Entity filter function to avoid hitting the target itself
    local shouldHitEntity = function(entity)
        return entity:GetIndex() ~= target:GetIndex() and entity:GetTeamNumber() ~= target:GetTeamNumber()
    end

    -- Calculate projectile hull size based on weapon type
    local projMins, projMaxs = projData.Mins or Vector3(-1, -1, -1), projData.Maxs or Vector3(1, 1, 1)

    -- Case for hitscan/no gravity projectiles (rockets, energy weapons)
    if effective_gravity == 0 then
        local time_to_target = direction:Length() / speed
        if time_to_target > timeToHit then
            return false
        end

        -- Simple TraceLine collision detection - if nil then hit target, if wall then blocked
        local trace = TraceLine(origin, dest, G.Constants.MASK_PLAYERSOLID, shouldHitEntity)

        -- Check collision result
        if trace.fraction < 1.0 then
            if trace.entity and trace.entity:GetIndex() == target:GetIndex() then
                -- We hit our target faster than anticipated - success!
                G.ProjectileSimulation.currentPath = { origin, trace.endpos }
                return {
                    angles = Common.Math.PositionAngles(origin, dest),
                    time = time_to_target * trace.fraction, -- Adjust time for early hit
                    Prediction = dest,
                    Positions = { origin, dest }
                }
            else
                -- We hit a wall or obstacle - path blocked
                return false
            end
        end

        G.ProjectileSimulation.currentPath = { origin, dest }
        return {
            angles = Common.Math.PositionAngles(origin, dest),
            time = time_to_target,
            Prediction = dest,
            Positions = { origin, dest }
        }
    else
        -- Ballistic trajectory calculation with proper physics simulation
        local gravity_horizontal_squared = effective_gravity * horizontal_distance * horizontal_distance
        local discriminant = speed_squared * speed_squared -
            effective_gravity * (gravity_horizontal_squared + 2 * vertical_distance * speed_squared)

        if discriminant < 0 then return nil end

        local sqrt_discriminant = math.sqrt(discriminant)
        local pitch_angle = math.atan((speed_squared - sqrt_discriminant) / (effective_gravity * horizontal_distance))
        local yaw_angle = math.atan(direction.y, direction.x)

        if isNaN(pitch_angle) or isNaN(yaw_angle) then return nil end

        local calculated_angles = EulerAngles(pitch_angle * -M_RADPI, yaw_angle * M_RADPI)
        local time_to_target = horizontal_distance / (math.cos(pitch_angle) * speed)

        if time_to_target > timeToHit then
            return false
        end

        -- Enhanced trajectory simulation with proper collision detection
        local number_of_segments = math.max(10, Config.advanced.projectileSegments or 20)
        local segment_duration = time_to_target / number_of_segments
        local current_position = origin
        local velocity_vector = Vector3(
            speed * math.cos(pitch_angle) * math.cos(yaw_angle),
            speed * math.cos(pitch_angle) * math.sin(yaw_angle),
            speed * math.sin(pitch_angle)
        )

        G.ProjectileSimulation.currentPath = { current_position }

        -- Simulate each segment of the trajectory
        for segment = 1, number_of_segments do
            local time_step = segment_duration

            -- Calculate new position using physics equations
            local displacement = velocity_vector * time_step
            local gravity_displacement = Vector3(0, 0, -0.5 * effective_gravity * time_step * time_step)
            local new_position = current_position + displacement + gravity_displacement

            -- No drag for TF2 projectiles - they maintain constant velocity

            -- Apply gravity to velocity
            velocity_vector.z = velocity_vector.z - effective_gravity * time_step

            -- Simple TraceLine collision detection for each segment
            local trace = TraceLine(current_position, new_position, G.Constants.MASK_PLAYERSOLID, shouldHitEntity)

            -- Update position to collision point if we hit something
            if trace.fraction < 1.0 then
                new_position = trace.endpos
                table.insert(G.ProjectileSimulation.currentPath, new_position)

                -- Check what we hit
                if trace.entity and trace.entity:GetIndex() == target:GetIndex() then
                    -- We hit our target - success!
                    return {
                        angles = calculated_angles,
                        time = segment * segment_duration * trace.fraction,
                        Prediction = new_position,
                        Positions = G.ProjectileSimulation.currentPath
                    }
                else
                    -- We hit something else (wall, ground, etc.) - trajectory blocked
                    return false
                end
            end

            -- Add position to path and continue
            table.insert(G.ProjectileSimulation.currentPath, new_position)
            current_position = new_position
        end

        -- If we completed the full trajectory without hitting anything
        return {
            angles = calculated_angles,
            time = time_to_target,
            Prediction = current_position,
            Positions = G.ProjectileSimulation.currentPath
        }
    end
end

function SolveProjectile(origin, dest, speed, gravity, sv_gravity, target, timeToHit)
    -- Get projectile data for proper collision detection
    local me = entities.GetLocalPlayer()
    local weapon = me:GetPropEntity("m_hActiveWeapon")
    local projData = ProjectileData.GetProjectileData(me, weapon)

    if not projData then
        -- Fallback to basic simulation if no projectile data
        projData = { Mins = Vector3(-1, -1, -1), Maxs = Vector3(1, 1, 1) }
    end

    return SimulateProjectileTrajectory(origin, dest, speed, gravity, sv_gravity, target, timeToHit, projData)
end

-- Calculate hit chance percentage (from original)
local function calculateHitChancePercentage(lastPredictedPos, currentPos)
    if not lastPredictedPos then
        return 0
    end

    -- Calculate horizontal distance (2D distance on the X-Y plane)
    local horizontalDistance = math.sqrt((currentPos.x - lastPredictedPos.x) ^ 2 + (currentPos.y - lastPredictedPos.y) ^
        2)

    -- Calculate vertical distance with an allowance for vertical movement
    local verticalDistance = math.abs(currentPos.z - lastPredictedPos.z)

    -- Define maximum acceptable distances
    local maxHorizontalDistance = 12 -- Max acceptable horizontal distance in units
    local maxVerticalDistance = 45   -- Max acceptable vertical distance in units

    -- Normalize the distances to a 0-1 scale
    local horizontalFactor = math.min(horizontalDistance / maxHorizontalDistance, 1)
    local verticalFactor = math.min(verticalDistance / maxVerticalDistance, 1)

    -- Calculate the hit chance as a percentage
    local overallFactor = (horizontalFactor + verticalFactor) / 2

    -- Convert to a percentage where 100% is perfect and 0% is a miss
    local hitChancePercentage = (1 - overallFactor) * 100

    return hitChancePercentage
end

-- Calculate trust factor based on number of records (from original)
local function calculateTrustFactor(numRecords, maxRecords, growthRate)
    -- Ensure we avoid division by zero
    if maxRecords == 0 then
        return 0
    end

    -- Calculate the ratio of current records to maximum records
    local ratio = numRecords / maxRecords

    -- Apply an exponential function to grow the trust factor
    local trustFactor = 1 - math.exp(-growthRate * ratio)

    -- Ensure the trust factor is capped at 1
    if trustFactor > 1 then
        trustFactor = 1
    end

    -- Round the trust factor to 2 decimal places
    trustFactor = math.floor(trustFactor * 100 + 0.5) / 100

    return trustFactor
end

-- Calculate adjusted hit chance (from original)
local function calculateAdjustedHitChance(hitChance, trustFactor)
    -- Apply the trust factor as a multiplier to the hit chance
    return math.floor(hitChance * trustFactor * 100 + 0.5) / 100
end

-- Main projectile target checking function (restored original working approach)
function ProjectileAimbot.CheckProjectileTarget(me, weapon, player)
    local tick_interval = TickInterval()
    local shootPos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
    local aimPos = player:GetAbsOrigin() + Vector3(0, 0, 10)
    local aimOffset = aimPos - player:GetAbsOrigin()
    local gravity = client.GetConVar("sv_gravity")
    local stepSize = player:GetPropFloat("localdata", "m_flStepSize")
    local vStep = Vector3(0, 0, stepSize / 2)
    local vPath = {}
    -- Start with lag-compensated real-time position
    local latency = G.Aimbot.LatencyData.latency + G.Aimbot.LatencyData.lerp
    local basePos = player:GetAbsOrigin()
    local baseVel = player:EstimateAbsVelocity()

    -- Use enhanced motion data from HistoryHandler if available
    local playerIndex = player:GetIndex()
    local motionData = G.history[playerIndex]

    -- Compensate for network lag by advancing position to real-time
    local lastP = basePos + baseVel * latency
    local lastV = baseVel
    local lastG = Common.IsOnGround(player)
    local shouldHitEntity = function(entity)
        return entity:GetIndex() ~= player:GetIndex() or entity:GetTeamNumber() ~= player:GetTeamNumber()
    end
    local vHitbox = { Vector3(-22, -22, 0), Vector3(22, 22, 80) }

    -- Check initial conditions
    local projData = ProjectileData.GetProjectileData(me, weapon)
    if not projData or not gravity or not stepSize then return nil end

    local PredTicks = Config.advanced.maxPredictionTicks or 77
    local speed = projData.Speed

    -- Early distance check
    if (me:GetAbsOrigin() - player:GetAbsOrigin()):Length() > PredTicks * speed then return nil end

    local targetAngles

    -- Initialize storage for predictions if not already initialized
    local playerIndex = player:GetIndex()
    if not G.HitChanceData.lastPositions[playerIndex] then G.HitChanceData.lastPositions[playerIndex] = {} end
    if not G.HitChanceData.priorPredictions[playerIndex] then G.HitChanceData.priorPredictions[playerIndex] = {} end
    if not G.HitChanceData.hitChanceRecords[playerIndex] then G.HitChanceData.hitChanceRecords[playerIndex] = {} end

    -- Variables to accumulate hit chances
    local totalHitChance = 0
    local tickCount = 0

    -- Apply strafe prediction (now always enabled)
    local strafeAngle = nil
    if G.predictionDelta[playerIndex] then
        strafeAngle = G.predictionDelta[playerIndex].strafeDelta
    end

    -- Main Loop for Prediction and Projectile Calculations (EXACT COPY FROM ORIGINAL)
    for i = 1, PredTicks * 2 do
        local pos = lastP + lastV * tick_interval
        local vel = lastV
        local onGround = lastG

        -- Apply enhanced strafe prediction using motion data
        if motionData and motionData.strafeDelta ~= 0 then
            local strafeInfluence = motionData.strafeDelta
            -- Scale strafe influence by predictability (less predictable = less influence)
            if motionData.predictabilityScore then
                strafeInfluence = strafeInfluence * (1.0 - motionData.predictabilityScore * 0.5)
            end

            local ang = vel:Angles()
            ang.y = ang.y + strafeInfluence
            vel = ang:Forward() * vel:Length()
        end

        -- Apply acceleration and jerk if available
        if motionData and motionData.acceleration then
            vel = vel + motionData.acceleration * tick_interval
        end

        -- Forward Collision
        local wallTrace = TraceHull(lastP + vStep, pos + vStep, vHitbox[1], vHitbox[2], G.Constants.MASK_PLAYERSOLID,
            shouldHitEntity)
        if wallTrace.fraction < 1 then
            pos.x, pos.y = handleForwardCollision(vel, wallTrace)
        end

        -- Ground Collision
        local downStep = onGround and vStep or Vector3()
        local groundTrace = TraceHull(pos + vStep, pos - downStep, vHitbox[1], vHitbox[2], G.Constants.MASK_PLAYERSOLID,
            shouldHitEntity)
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
        vPath[i] = pos -- save path for visuals

        -- Hitchance check and synchronization of predictions
        if i <= PredTicks then
            local currentTick = PredTicks - i -- Determine which tick in the future we're currently predicting

            -- Store the last prediction of the current tick
            G.HitChanceData.lastPositions[playerIndex][currentTick] = G.HitChanceData.priorPredictions[playerIndex]
                [currentTick] or pos

            -- Update priorPrediction with the current predicted position for this tick
            G.HitChanceData.priorPredictions[playerIndex][currentTick] = pos

            -- Calculate hit chance for the current tick
            local hitChance1 = calculateHitChancePercentage(G.HitChanceData.lastPositions[playerIndex][currentTick],
                G.HitChanceData.priorPredictions[playerIndex][currentTick])

            -- Insert the hit chance record
            table.insert(G.HitChanceData.hitChanceRecords[playerIndex], hitChance1)

            -- Ensure the number of records does not exceed the maximum allowed
            local maxRecords = 66                                              -- Default max records
            if #G.HitChanceData.hitChanceRecords[playerIndex] > maxRecords then
                table.remove(G.HitChanceData.hitChanceRecords[playerIndex], 1) -- Remove the oldest record
            end

            -- Accumulate hit chance and tick count
            totalHitChance = totalHitChance + hitChance1
            tickCount = tickCount + 1
        end

        -- Solve the projectile based on the current position
        local solution = SolveProjectile(shootPos, pos, projData.Speed, projData.Gravity, gravity, player,
            PredTicks * tick_interval)
        if solution == nil then goto continue end

        if not solution then
            -- Try splash prediction for hidden targets if enabled
            if Config.advanced.splashPrediction and projData.Gravity == 0 then -- Only for explosive projectiles
                local splashPos = FindBestSplashPosition(shootPos, pos, player)
                if splashPos then
                    solution = SolveProjectile(shootPos, splashPos, projData.Speed, projData.Gravity, gravity, player,
                        PredTicks * tick_interval)
                    if solution then
                        -- Mark this as a splash shot for visuals
                        G.Aimbot.IsSplashShot = true
                    end
                end
            end

            if not solution then
                return nil
            end
        else
            G.Aimbot.IsSplashShot = false
        end

        local time
        if solution and solution.time then
            -- Add latency and lerp compensation (CRITICAL - this was missing!)
            time = solution.time + G.Aimbot.LatencyData.latency + G.Aimbot.LatencyData.lerp
        else
            return nil
        end

        local ticks = Common.TimeToTicks(time) + 1
        if ticks > i then goto continue end

        targetAngles = solution.angles
        break
        ::continue::
    end

    -- Calculate the average hit chance and set the global hitChance variable
    if tickCount > 0 then
        G.Aimbot.HitChance = totalHitChance / tickCount
    else
        G.Aimbot.HitChance = 0
    end

    -- Calculate trust factor based on the number of records
    local numRecords = #G.HitChanceData.hitChanceRecords[playerIndex]
    local growthRate = 5  -- Default growth rate (was Config.advanced.accuracyWeight)
    local maxRecords = 66 -- Default max records (was Config.advanced.hitchanceAccuracy)
    local trustFactor = calculateTrustFactor(numRecords, maxRecords, growthRate)

    -- Adjust the average hit chance based on trust factor
    G.Aimbot.HitChance = calculateAdjustedHitChance(G.Aimbot.HitChance, trustFactor)

    -- Check if the average adjusted hit chance meets the minimum required threshold
    if G.Aimbot.HitChance < Config.main.minHitchance then
        return nil -- If not, return nil to indicate that the prediction is not reliable
    end

    -- Store trajectory path for visuals
    G.Aimbot.TargetPredictionPath = vPath

    if not targetAngles or (player:GetAbsOrigin() - me:GetAbsOrigin()):Length() < Config.main.minDistance then
        return nil
    end

    return {
        entity = player,
        angles = targetAngles,
        factor = 0,
        Prediction = vPath[#vPath]
    }
end

-- Update latency data efficiently
function ProjectileAimbot.UpdateLatency()
    G.Aimbot.LatencyData.latency = (clientstate.GetLatencyIn() or 0) + (clientstate.GetLatencyOut() or 0)
    G.Aimbot.LatencyData.lerp = client.GetConVar("cl_interp") or 0
end

-- Main aimbot function (optimized - validation done in Main.lua)
function ProjectileAimbot.Run(userCmd)
    local me = entities.GetLocalPlayer()
    local weapon = me:GetPropEntity("m_hActiveWeapon")

    ProjectileAimbot.UpdateLatency()

    local currentTarget = BestTarget.Get()
    if not currentTarget then
        return
    end

    local aimResult = ProjectileAimbot.CheckProjectileTarget(me, weapon, currentTarget)
    if not aimResult then
        return
    end

    -- Store current target
    G.Aimbot.Target = currentTarget
    G.Aimbot.CurrentAngles = aimResult.angles

    -- Apply aim
    userCmd:SetViewAngles(aimResult.angles:Unpack())
    if not Config.main.silent then
        engine.SetViewAngles(aimResult.angles)
    end

    -- Auto shoot
    if Config.main.autoShoot then
        if weapon:GetWeaponID() == TF_WEAPON_COMPOUND_BOW then
            local chargeBeginTime = weapon:GetPropFloat("PipebombLauncherLocalData", "m_flChargeBeginTime") or 0
            if chargeBeginTime > 0 then
                userCmd.buttons = userCmd.buttons & ~IN_ATTACK
            else
                userCmd.buttons = userCmd.buttons | IN_ATTACK
            end
        else
            -- Normal weapon
            userCmd.buttons = userCmd.buttons | IN_ATTACK
        end
    end
end

-- Direct aimbot function (skip hitchance checks when player is actively shooting)
function ProjectileAimbot.RunDirect(userCmd)
    local me = entities.GetLocalPlayer()
    local weapon = me:GetPropEntity("m_hActiveWeapon")

    ProjectileAimbot.UpdateLatency()

    local currentTarget = BestTarget.Get()
    if not currentTarget then
        return
    end

    -- Skip hitchance validation for direct shooting
    local aimResult = ProjectileAimbot.CheckProjectileTargetDirect(me, weapon, currentTarget)
    if not aimResult then
        return
    end

    -- Store current target
    G.Aimbot.Target = currentTarget
    G.Aimbot.CurrentAngles = aimResult.angles

    -- Apply aim immediately
    userCmd:SetViewAngles(aimResult.angles:Unpack())
    if not Config.main.silent then
        engine.SetViewAngles(aimResult.angles)
    end
end

-- Direct target checking (skip hitchance validation)
function ProjectileAimbot.CheckProjectileTargetDirect(me, weapon, player)
    local tick_interval = TickInterval()
    local shootPos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
    local aimPos = player:GetAbsOrigin() + Vector3(0, 0, 10)
    local aimOffset = aimPos - player:GetAbsOrigin()
    local gravity = client.GetConVar("sv_gravity")
    local stepSize = player:GetPropFloat("localdata", "m_flStepSize")
    local vStep = Vector3(0, 0, stepSize / 2)
    local vPath = {}

    -- Start with lag-compensated real-time position
    local latency = G.Aimbot.LatencyData.latency + G.Aimbot.LatencyData.lerp
    local basePos = player:GetAbsOrigin()
    local baseVel = player:EstimateAbsVelocity()

    -- Use enhanced motion data from HistoryHandler if available
    local playerIndex = player:GetIndex()
    local motionData = G.history[playerIndex]
    local strafeAngle = motionData and motionData.strafeDelta or 0

    -- Compensate for network lag by advancing position to real-time
    local lastP = basePos + baseVel * latency
    local lastV = baseVel
    local lastG = Common.IsOnGround(player)
    local shouldHitEntity = function(entity)
        return entity:GetIndex() ~= player:GetIndex() or entity:GetTeamNumber() ~= player:GetTeamNumber()
    end
    local vHitbox = { Vector3(-22, -22, 0), Vector3(22, 22, 80) }

    -- Check initial conditions
    local projData = ProjectileData.GetProjectileData(me, weapon)
    if not projData or not gravity or not stepSize then return nil end

    local PredTicks = Config.advanced.maxPredictionTicks or 77
    local speed = projData.Speed

    -- Early distance check
    if (me:GetAbsOrigin() - player:GetAbsOrigin()):Length() > PredTicks * speed then return nil end

    local targetAngles

    -- Enhanced prediction using motion data
    for i = 1, PredTicks do
        local pos = lastP + lastV * tick_interval
        local vel = lastV
        local onGround = lastG

        -- Apply enhanced strafe prediction using motion data
        if motionData and motionData.strafeDelta ~= 0 then
            local strafeInfluence = motionData.strafeDelta
            -- Scale strafe influence by predictability (less predictable = less influence)
            if motionData.predictabilityScore then
                strafeInfluence = strafeInfluence * (1.0 - motionData.predictabilityScore * 0.5)
            end

            local ang = vel:Angles()
            ang.y = ang.y + strafeInfluence
            vel = ang:Forward() * vel:Length()
        end

        -- Apply acceleration and jerk if available
        if motionData and motionData.acceleration then
            vel = vel + motionData.acceleration * tick_interval
        end

        -- Forward Collision
        local wallTrace = TraceHull(lastP + vStep, pos + vStep, vHitbox[1], vHitbox[2], G.Constants.MASK_PLAYERSOLID,
            shouldHitEntity)
        if wallTrace.fraction < 1 then
            pos.x, pos.y = handleForwardCollision(vel, wallTrace)
        end

        -- Ground Collision
        local downStep = onGround and vStep or Vector3()
        local groundTrace = TraceHull(pos + vStep, pos - downStep, vHitbox[1], vHitbox[2], G.Constants.MASK_PLAYERSOLID,
            shouldHitEntity)
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
        vPath[i] = pos

        -- Solve the projectile based on the current position (no hitchance validation)
        local solution = SolveProjectile(shootPos, pos, projData.Speed, projData.Gravity, gravity, player,
            PredTicks * tick_interval)
        if solution == nil then goto continue end

        if not solution then
            -- Try splash prediction for hidden targets if enabled
            if Config.advanced.splashPrediction and projData.Gravity == 0 then
                local splashPos = FindBestSplashPosition(shootPos, pos, player)
                if splashPos then
                    solution = SolveProjectile(shootPos, splashPos, projData.Speed, projData.Gravity, gravity, player,
                        PredTicks * tick_interval)
                    if solution then
                        G.Aimbot.IsSplashShot = true
                    end
                end
            end

            if not solution then
                goto continue
            end
        else
            G.Aimbot.IsSplashShot = false
        end

        local time
        if solution and solution.time then
            time = solution.time + G.Aimbot.LatencyData.latency + G.Aimbot.LatencyData.lerp
        else
            goto continue
        end

        local ticks = Common.TimeToTicks(time) + 1
        if ticks > i then goto continue end

        targetAngles = solution.angles
        break
        ::continue::
    end

    -- Store trajectory path for visuals
    G.Aimbot.TargetPredictionPath = vPath

    if not targetAngles or (player:GetAbsOrigin() - me:GetAbsOrigin()):Length() < Config.main.minDistance then
        return nil
    end

    return {
        entity = player,
        angles = targetAngles,
        factor = 0,
        Prediction = vPath[#vPath]
    }
end

return ProjectileAimbot
