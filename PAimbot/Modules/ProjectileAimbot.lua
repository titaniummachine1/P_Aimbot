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

-- Solve projectile trajectory (exact copy from working original)
function SolveProjectile(origin, dest, speed, gravity, sv_gravity, target, timeToHit)
    -- Calculate the direction vector from origin to destination
    local direction = dest - origin

    -- Calculate squared speed for later use in equations
    local speed_squared = speed * speed

    -- Calculate the effective gravity based on server gravity settings and the specified gravity factor
    local effective_gravity = sv_gravity * gravity

    -- Calculate the horizontal (2D) distance and vertical (Z-axis) distance between origin and destination
    local horizontal_distance = direction:Length2D()
    local vertical_distance = direction.z

    -- Entity filter function to avoid hitting the target itself
    local shouldHitEntity = function(entity)
        return entity:GetIndex() ~= target:GetIndex() or entity:GetTeamNumber() ~= target:GetTeamNumber()
    end

    -- Case for when there is no gravity (e.g., hitscan projectiles)
    if effective_gravity == 0 then
        -- Calculate the time to hit based on speed and distance
        local time_to_target = direction:Length() / speed
        if time_to_target > timeToHit then
            return false -- Projectile will fly out of range, so return false
        end

        -- Perform a trace line to check if the path is clear
        local trace = TraceLine(origin, dest, G.Constants.MASK_PLAYERSOLID)
        if trace.fraction ~= 1.0 and trace.entity:GetName() ~= target:GetName() then
            return false -- Path is obstructed, so return false
        end

        -- Return the result with no gravity calculations
        return {
            angles = Common.PositionAngles(origin, dest),
            time = time_to_target,
            Prediction = dest,
            Positions = { origin, dest }
        }
    else
        -- Ballistic arc calculation when gravity is present

        -- Calculate the term related to gravity and horizontal distance squared
        local gravity_horizontal_squared = effective_gravity * horizontal_distance * horizontal_distance

        -- Solve the quadratic equation for projectile motion
        local discriminant = speed_squared * speed_squared -
            effective_gravity * (gravity_horizontal_squared + 2 * vertical_distance * speed_squared)
        if discriminant < 0 then return nil end -- No real solution, so return nil

        -- Calculate the pitch and yaw angles required for the projectile to reach the target
        local sqrt_discriminant = math.sqrt(discriminant)
        local pitch_angle = math.atan((speed_squared - sqrt_discriminant) / (effective_gravity * horizontal_distance))
        local yaw_angle = math.atan(direction.y, direction.x)

        if isNaN(pitch_angle) or isNaN(yaw_angle) then return nil end

        -- Convert the pitch and yaw into Euler angles
        local calculated_angles = EulerAngles(pitch_angle * -M_RADPI, yaw_angle * M_RADPI)

        -- Calculate the time it takes for the projectile to reach the target
        local time_to_target = horizontal_distance / (math.cos(pitch_angle) * speed)

        if time_to_target > timeToHit then
            return false -- Projectile will fly out of range, so return false
        end

        -- Return the calculated angles, time to target, final predicted position, and all positions along the path
        return {
            angles = calculated_angles,
            time = time_to_target,
            Prediction = dest,
            Positions = { origin, dest }
        }
    end
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
    local lastP, lastV, lastG = player:GetAbsOrigin(), player:EstimateAbsVelocity(), Common.IsOnGround(player)
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

    -- Apply strafe prediction if enabled
    local strafeAngle = nil
    if Config.advanced.strafePrediction and G.predictionDelta[playerIndex] then
        strafeAngle = G.predictionDelta[playerIndex].strafeDelta
    end

    -- Main Loop for Prediction and Projectile Calculations (EXACT COPY FROM ORIGINAL)
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
            local maxRecords = Config.advanced.hitchanceAccuracy or 66
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
            -- TODO: Add splash prediction here if needed
            return nil
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
    local growthRate = Config.advanced.accuracyWeight or 5
    local trustFactor = calculateTrustFactor(numRecords, Config.advanced.hitchanceAccuracy or 66, growthRate)

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
end

return ProjectileAimbot
