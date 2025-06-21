local ProjectileAimbot = {}

local G = require("PAimbot.Globals")
local Common = require("PAimbot.Common")
local Config = require("PAimbot.Config")
local ProjectileData = require("PAimbot.Modules.ProjectileData")
local BestTarget = require("PAimbot.Modules.Helpers.BestTarget")

-- Cache frequently used functions for performance
local atan = math.atan
local cos = math.cos
local sin = math.sin
local sqrt = math.sqrt
local floor = math.floor
local TickInterval = globals.TickInterval
local TraceLine = engine.TraceLine
local TraceHull = engine.TraceHull

local function isNaN(x) return x ~= x end

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

-- Calculate hit chance based on prediction accuracy
local function calculateHitChancePercentage(lastPredictedPos, currentPos)
    if not lastPredictedPos then
        return 0
    end

    local horizontalDistance = math.sqrt((currentPos.x - lastPredictedPos.x) ^ 2 + (currentPos.y - lastPredictedPos.y) ^
        2)
    local verticalDistance = math.abs(currentPos.z - lastPredictedPos.z)

    local maxHorizontalDistance = 12
    local maxVerticalDistance = 45

    local horizontalFactor = math.min(horizontalDistance / maxHorizontalDistance, 1)
    local verticalFactor = math.min(verticalDistance / maxVerticalDistance, 1)

    local overallFactor = (horizontalFactor + verticalFactor) / 2
    local hitChancePercentage = (1 - overallFactor) * 100

    return hitChancePercentage
end

-- Calculate trust factor for hit chance accuracy
local function calculateTrustFactor(numRecords, maxRecords, growthRate)
    if maxRecords == 0 then
        return 0
    end

    local ratio = numRecords / maxRecords
    local trustFactor = 1 - math.exp(-growthRate * ratio)

    if trustFactor > 1 then
        trustFactor = 1
    end

    return math.floor(trustFactor * 100 + 0.5) / 100
end

-- Solve projectile trajectory
local function SolveProjectile(origin, dest, speed, gravity, sv_gravity, target, timeToHit)
    local direction = dest - origin
    local speed_squared = speed * speed
    local effective_gravity = sv_gravity * gravity
    local horizontal_distance = direction:Length2D()
    local vertical_distance = direction.z

    local shouldHitEntity = function(entity)
        return entity:GetIndex() ~= target:GetIndex() or entity:GetTeamNumber() ~= target:GetTeamNumber()
    end

    -- No gravity case (hitscan-like)
    if effective_gravity == 0 then
        local time_to_target = direction:Length() / speed
        if time_to_target > timeToHit then
            return false
        end

        local trace = TraceLine(origin, dest, G.Constants.MASK_PLAYERSOLID)
        if trace.fraction ~= G.Constants.FULL_HIT_FRACTION and trace.entity:GetName() ~= target:GetName() then
            return false
        end

        G.ProjectileSimulation.TrajectoryPath = { origin, trace.endpos }

        return {
            angles = Common.Math.PositionAngles(origin, dest),
            time = time_to_target,
            Prediction = dest,
            Positions = { origin, dest }
        }
    else
        -- Ballistic arc calculation
        local gravity_horizontal_squared = effective_gravity * horizontal_distance * horizontal_distance
        local discriminant = speed_squared * speed_squared -
            effective_gravity * (gravity_horizontal_squared + 2 * vertical_distance * speed_squared)

        if discriminant < 0 then return nil end

        local sqrt_discriminant = math.sqrt(discriminant)
        local pitch_angle = math.atan((speed_squared - sqrt_discriminant) / (effective_gravity * horizontal_distance))
        local yaw_angle = math.atan(direction.y, direction.x)

        if isNaN(pitch_angle) or isNaN(yaw_angle) then return nil end

        local calculated_angles = EulerAngles(pitch_angle * -G.Constants.M_RADPI, yaw_angle * G.Constants.M_RADPI)
        local time_to_target = horizontal_distance / (math.cos(pitch_angle) * speed)

        if time_to_target > timeToHit then
            return false
        end

        -- Simulate trajectory
        local number_of_segments = math.max(1, Config.advanced.projectileSegments or 2)
        local segment_duration = time_to_target / number_of_segments
        local current_position = origin
        local current_velocity = speed

        G.ProjectileSimulation.TrajectoryPath = { current_position }

        for segment = 1, number_of_segments do
            local time_segment = segment * segment_duration
            current_velocity = current_velocity * math.exp(-G.Constants.DRAG_COEFFICIENT * time_segment)

            local horizontal_displacement = current_velocity * math.cos(pitch_angle) * time_segment
            local vertical_displacement = current_velocity * math.sin(pitch_angle) * time_segment -
                0.5 * effective_gravity * time_segment * time_segment
            local new_position = origin +
                Vector3(horizontal_displacement * math.cos(yaw_angle), horizontal_displacement * math.sin(yaw_angle),
                    vertical_displacement)

            local trace = TraceLine(current_position, new_position, G.Constants.MASK_PLAYERSOLID, shouldHitEntity)
            table.insert(G.ProjectileSimulation.TrajectoryPath, new_position)

            if trace.fraction < G.Constants.FULL_HIT_FRACTION and trace.entity ~= target then
                return false
            end

            current_position = new_position
        end

        return {
            angles = calculated_angles,
            time = time_to_target,
            Prediction = current_position,
            Positions = G.ProjectileSimulation.TrajectoryPath
        }
    end
end

-- Find best splash position
local function FindBestShootingPosition(origin, dest, target, BlastRadius)
    local function checkPath(direction, angle, distance)
        local point = dest + RotateVector(direction, angle) * distance
        local traceLineOriginToPoint = TraceLine(origin, point, G.Constants.MASK_PLAYERSOLID,
            function(entity) return entity:GetIndex() ~= target:GetIndex() end)
        return traceLineOriginToPoint.fraction > 0.9, traceLineOriginToPoint.endpos
    end

    local initialTrace = TraceLine(origin, dest, G.Constants.MASK_PLAYERSOLID,
        function(entity) return entity:GetIndex() ~= target:GetIndex() end)

    if initialTrace.fraction < 1 and initialTrace.entity:GetIndex() ~= target:GetIndex() then
        local direction = Common.Normalize(dest - origin)

        -- Check clearance for left and right
        local leftClear, leftMaxPoint = checkPath(direction, -90, BlastRadius)
        local rightClear, rightMaxPoint = checkPath(direction, 90, BlastRadius)

        local searchSide = nil
        local maxDistancePoint = nil

        if leftClear and rightClear then
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

        if searchSide and maxDistancePoint then
            local minDistance = 0
            local maxDistance = (maxDistancePoint - dest):Length()
            local iterations = Config.advanced.splashAccuracy or 5
            local bestPoint = maxDistancePoint
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
                G.ProjectileSimulation.SplashPosition = bestPoint
                return bestPoint
            end
        end

        return false
    end

    return dest
end

-- Main projectile target checking function
function ProjectileAimbot.CheckProjectileTarget(me, weapon, player)
    local tick_interval = TickInterval()
    local shootPos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
    local aimPos = player:GetAbsOrigin() + Vector3(0, 0, 10)
    local aimOffset = aimPos - player:GetAbsOrigin()
    local gravity = client.GetConVar("sv_gravity")
    local stepSize = player:GetPropFloat("localdata", "m_flStepSize")
    local vStep = Vector3(0, 0, stepSize / 2)

    G.Aimbot.TargetPredictionPath = {}

    local lastP, lastV, lastG = player:GetAbsOrigin(), player:EstimateAbsVelocity(), Common.IsOnGround(player)
    local shouldHitEntity = function(entity)
        return entity:GetIndex() ~= player:GetIndex() or
            entity:GetTeamNumber() ~= player:GetTeamNumber()
    end
    local BlastRadius = 150

    -- Get projectile info
    local projData = ProjectileData.GetProjectileData(me, weapon)
    if not projData or not gravity or not stepSize then return nil end

    local PredTicks = Config.advanced.predTicks
    local speed = projData.Speed

    if (me:GetAbsOrigin() - player:GetAbsOrigin()):Length() > PredTicks * speed then return nil end

    local targetAngles, fov

    -- Initialize hit chance tracking
    if not G.HitChanceData.lastPositions[player:GetIndex()] then G.HitChanceData.lastPositions[player:GetIndex()] = {} end
    if not G.HitChanceData.priorPredictions[player:GetIndex()] then G.HitChanceData.priorPredictions[player:GetIndex()] = {} end
    if not G.HitChanceData.hitChanceRecords[player:GetIndex()] then G.HitChanceData.hitChanceRecords[player:GetIndex()] = {} end

    local totalHitChance = 0
    local tickCount = 0

    -- Main prediction loop
    for i = 1, PredTicks * 2 do
        local pos = lastP + lastV * tick_interval
        local vel = lastV
        local onGround = lastG

        -- Apply strafe prediction if enabled
        if Config.advanced.strafePrediction and G.predictionDelta[player:GetIndex()] then
            local strafeDelta = G.predictionDelta[player:GetIndex()].strafeDelta
            if strafeDelta then
                local ang = vel:Angles()
                ang.y = ang.y + strafeDelta
                vel = ang:Forward() * vel:Length()
            end
        end

        -- Forward collision
        local wallTrace = TraceHull(lastP + vStep, pos + vStep, G.Hitbox.Min, G.Hitbox.Max, G.Constants.MASK_PLAYERSOLID,
            shouldHitEntity)
        if wallTrace.fraction < 1 then
            local normal = wallTrace.plane
            local angle = math.deg(math.acos(normal:Dot(Vector3(0, 0, 1))))
            if angle > 55 then
                local dot = vel:Dot(normal)
                vel = vel - normal * dot
            end
            pos.x, pos.y = wallTrace.endpos.x, wallTrace.endpos.y
        end

        -- Ground collision
        local downStep = onGround and vStep or Vector3()
        local groundTrace = TraceHull(pos + vStep, pos - downStep, G.Hitbox.Min, G.Hitbox.Max,
            G.Constants.MASK_PLAYERSOLID, shouldHitEntity)
        if groundTrace.fraction < 1 then
            local normal = groundTrace.plane
            local angle = math.deg(math.acos(normal:Dot(Vector3(0, 0, 1))))
            if angle < 45 then
                onGround = true
            elseif angle < 60 then
                vel.x, vel.y, vel.z = 0, 0, 0
            else
                local dot = vel:Dot(normal)
                vel = vel - normal * dot
                onGround = true
            end
            if onGround then vel.z = 0 end
            pos = groundTrace.endpos
        else
            onGround = false
        end

        -- Apply gravity if not on ground
        if not onGround then
            vel.z = vel.z - gravity * tick_interval
        end

        lastP, lastV, lastG = pos, vel, onGround

        -- Store prediction path
        pos = lastP + aimOffset
        G.Aimbot.TargetPredictionPath[i] = pos

        -- Hit chance calculation
        if i <= PredTicks then
            local currentTick = PredTicks - i

            G.HitChanceData.lastPositions[player:GetIndex()][currentTick] = G.HitChanceData.priorPredictions
                [player:GetIndex()][currentTick] or pos
            G.HitChanceData.priorPredictions[player:GetIndex()][currentTick] = pos

            local hitChance1 = calculateHitChancePercentage(
                G.HitChanceData.lastPositions[player:GetIndex()][currentTick],
                G.HitChanceData.priorPredictions[player:GetIndex()][currentTick])

            table.insert(G.HitChanceData.hitChanceRecords[player:GetIndex()], hitChance1)

            local maxRecords = Config.advanced.hitchanceAccuracy
            if #G.HitChanceData.hitChanceRecords[player:GetIndex()] > maxRecords then
                table.remove(G.HitChanceData.hitChanceRecords[player:GetIndex()], 1)
            end

            totalHitChance = totalHitChance + hitChance1
            tickCount = tickCount + 1
        end

        -- Solve projectile
        local solution = SolveProjectile(shootPos, pos, projData.Speed, projData.Gravity, gravity, player,
            PredTicks * tick_interval)
        if solution == nil then goto continue end

        if not solution then
            if Config.advanced.splashPrediction and projData.Gravity == 0 then
                local bestPos = FindBestShootingPosition(shootPos, pos, player, BlastRadius)
                if bestPos then
                    solution = SolveProjectile(shootPos, bestPos, projData.Speed, projData.Gravity, gravity, player,
                        PredTicks * tick_interval)
                end
            else
                return nil
            end
        end

        local time
        if solution and solution.time then
            time = solution.time + G.Aimbot.LatencyData.latency + G.Aimbot.LatencyData.lerp
        else
            return nil
        end

        local ticks = Common.Conversion.Time_to_Ticks(time) + 1
        if ticks > i then goto continue end

        targetAngles = solution.angles
        break
        ::continue::
    end

    -- Calculate final hit chance
    if tickCount > 0 then
        G.Aimbot.HitChance = totalHitChance / tickCount
    else
        G.Aimbot.HitChance = 0
    end

    -- Apply trust factor
    local numRecords = #G.HitChanceData.hitChanceRecords[player:GetIndex()]
    local growthRate = Config.advanced.accuracyWeight or 5
    local trustFactor = calculateTrustFactor(numRecords, Config.advanced.hitchanceAccuracy, growthRate)

    G.Aimbot.HitChance = G.Aimbot.HitChance * trustFactor

    -- Check minimum hit chance
    if G.Aimbot.HitChance < Config.main.minHitchance then
        return nil
    end

    if not targetAngles or (player:GetAbsOrigin() - me:GetAbsOrigin()):Length() < Config.main.minDistance or not G.HitChanceData.lastPositions[player:GetIndex()] then
        return nil
    end

    return {
        entity = player,
        angles = targetAngles,
        factor = fov,
        Prediction = G.Aimbot.TargetPredictionPath
            [#G.Aimbot.TargetPredictionPath]
    }
end

-- Update latency data
function ProjectileAimbot.UpdateLatency()
    local latIn, latOut = clientstate.GetLatencyIn(), clientstate.GetLatencyOut()
    G.Aimbot.LatencyData.latency = (latIn or 0) + (latOut or 0)
    G.Aimbot.LatencyData.lerp = client.GetConVar("cl_interp") or 0
end

-- Main aimbot function
function ProjectileAimbot.Run(userCmd)
    if not input.IsButtonDown(Config.main.aimKey.key) then
        return
    end

    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end

    ProjectileAimbot.UpdateLatency()

    local weapon = me:GetPropEntity("m_hActiveWeapon")
    if not weapon then return end

    -- Check if weapon is projectile-based
    local projType = weapon:GetWeaponProjectileType()
    if not projType or projType <= 1 then return end

    local currentTarget = BestTarget.Get()
    if currentTarget == nil then
        return
    end

    local aimResult = ProjectileAimbot.CheckProjectileTarget(me, weapon, currentTarget)
    if aimResult == nil then
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
            userCmd.buttons = userCmd.buttons | IN_ATTACK
        end
    end
end

return ProjectileAimbot
