---@diagnostic disable: unused-function
---@diagnostic disable: undefined-global

--[[
    ProjectileAimbot Module
    Optimized projectile prediction with binary search
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

-- Batch-based binary search for optimal prediction
local function BatchBinarySearch(me, weapon, player, projData, maxTicks)
    local shootPos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
    local tick_interval = TickInterval()
    local batchSize = 8 -- Predict in batches of 8 ticks
    local currentBatch = 0
    local predictionCache = {}

    -- Function to predict a batch if not already cached
    local function ensureBatchPredicted(batchStart, batchEnd)
        local batchKey = batchStart
        if predictionCache[batchKey] then return end

        predictionCache[batchKey] = {}
        for tick = batchStart, math.min(batchEnd, maxTicks) do
            predictionCache[batchKey][tick] = PredictPlayerPosition(player, tick)
        end
    end

    -- Binary search through batches
    local minTicks = 1
    local maxSearchTicks = maxTicks

    for iteration = 1, 10 do -- Max 10 iterations
        ::continue::
        local midTicks = math.floor((minTicks + maxSearchTicks) * 0.5)

        -- Ensure we have predictions up to midTicks
        local batchStart = math.floor((midTicks - 1) / batchSize) * batchSize + 1
        local batchEnd = batchStart + batchSize - 1
        ensureBatchPredicted(batchStart, batchEnd)

        -- Get prediction for midTicks
        local batchKey = math.floor((midTicks - 1) / batchSize) * batchSize + 1
        local predictedPos = predictionCache[batchKey] and predictionCache[batchKey][midTicks]

        if not predictedPos then
            -- Need more prediction, expand search
            minTicks = midTicks + 1
            goto continue
        end

        -- Test projectile solution
        local solution = SolveProjectile(shootPos, predictedPos, projData.Speed, projData.Gravity,
            client.GetConVar("sv_gravity"))

        if solution and solution.time then
            local requiredTicks = math.ceil(solution.time / tick_interval)

            -- Check if our prediction time matches projectile flight time
            if math.abs(requiredTicks - midTicks) <= 2 then -- Within 2 ticks tolerance
                -- Generate trajectory path for visuals
                local trajectoryPath = {}
                for i = 1, math.min(midTicks, 30) do -- Limit to 30 points for performance
                    local bKey = math.floor((i - 1) / batchSize) * batchSize + 1
                    if not predictionCache[bKey] then
                        ensureBatchPredicted(bKey, bKey + batchSize - 1)
                    end
                    if predictionCache[bKey] and predictionCache[bKey][i] then
                        trajectoryPath[i] = predictionCache[bKey][i]
                    end
                end

                return {
                    ticks = midTicks,
                    position = predictedPos,
                    solution = solution,
                    trajectoryPath = trajectoryPath
                }
            elseif requiredTicks > midTicks then
                -- Need more prediction time
                minTicks = midTicks + 1
            else
                -- Can use less prediction time
                maxSearchTicks = midTicks - 1
            end
        else
            -- No solution found, need more time
            minTicks = midTicks + 1
        end

        -- Stop if range is too small
        if maxSearchTicks - minTicks <= 1 then
            break
        end
    end

    return nil
end

-- Optimized player position prediction
function PredictPlayerPosition(player, ticks)
    local tick_interval = TickInterval()
    local pos = player:GetAbsOrigin()
    local vel = player:EstimateAbsVelocity()
    local onGround = Common.IsOnGround(player)
    local gravity = client.GetConVar("sv_gravity") or 800
    local stepSize = player:GetPropFloat("localdata", "m_flStepSize") or 18
    local vStep = Vector3(0, 0, stepSize / 2)

    local shouldHitEntity = function(entity)
        return entity:GetIndex() ~= player:GetIndex() or entity:GetTeamNumber() ~= player:GetTeamNumber()
    end

    -- Apply strafe prediction if enabled
    if Config.advanced.strafePrediction and G.predictionDelta[player:GetIndex()] then
        local strafeDelta = G.predictionDelta[player:GetIndex()].strafeDelta
        if strafeDelta then
            local ang = vel:Angles()
            ang.y = ang.y + strafeDelta
            vel = ang:Forward() * vel:Length()
        end
    end

    -- Simple physics simulation for specified ticks
    for i = 1, ticks do
        pos = pos + vel * tick_interval

        -- Basic collision detection
        local groundTrace = TraceHull(pos + vStep, pos - vStep, G.Hitbox.Min, G.Hitbox.Max, G.Constants.MASK_PLAYERSOLID,
            shouldHitEntity)
        if groundTrace and groundTrace.fraction < 1 then
            pos = groundTrace.endpos
            onGround = true
            vel.z = 0
        else
            onGround = false
        end

        -- Apply gravity if not on ground
        if not onGround then
            vel.z = vel.z - gravity * tick_interval
        end
    end

    return pos + Vector3(0, 0, 10) -- Add aim offset
end

-- Solve projectile trajectory (restored working version)
function SolveProjectile(startPos, targetPos, speed, projGravity, serverGravity)
    local diff = targetPos - startPos
    local dist2D = Vector3(diff.x, diff.y, 0):Length()
    local heightDiff = diff.z

    local gravity = serverGravity or 800

    -- Handle zero gravity projectiles
    if projGravity == 0 then
        local time = dist2D / speed
        local pitch = math.atan(heightDiff, dist2D)
        local yaw = math.atan(diff.y, diff.x)
        return {
            angles = EulerAngles(math.deg(pitch), math.deg(yaw), 0),
            time = time
        }
    end

    -- Ballistic trajectory calculation
    local g = gravity * projGravity
    local speedSqr = speed * speed
    local discriminant = speedSqr * speedSqr - g * (g * dist2D * dist2D + 2 * heightDiff * speedSqr)

    if discriminant < 0 then return nil end

    local sqrt_discriminant = math.sqrt(discriminant)
    local pitch_angle = math.atan((speedSqr - sqrt_discriminant) / (g * dist2D))
    local yaw_angle = math.atan(diff.y, diff.x)

    local time_to_target = dist2D / (math.cos(pitch_angle) * speed)

    return {
        angles = EulerAngles(-math.deg(pitch_angle), math.deg(yaw_angle), 0),
        time = time_to_target
    }
end

-- Calculate hit chance percentage
local function calculateHitChancePercentage(lastPos, currentPos)
    if not lastPos or not currentPos then return 100 end

    local distance = (lastPos - currentPos):Length()
    local maxDistance = 50 -- Maximum acceptable prediction error

    return math.max(0, math.min(100, 100 - (distance / maxDistance) * 100))
end

-- Calculate trust factor based on number of records
local function calculateTrustFactor(numRecords, maxRecords, growthRate)
    if maxRecords <= 0 then return 1 end

    local ratio = numRecords / maxRecords
    return math.min(1, ratio ^ (1 / growthRate))
end

-- Main projectile target checking function
function ProjectileAimbot.CheckProjectileTarget(me, weapon, player)
    local projData = ProjectileData.GetProjectileData(me, weapon)
    if not projData then return nil end

    -- Get max prediction ticks directly (no conversion needed)
    local maxTicks = Config.advanced.maxPredictionTicks or 132

    -- Use batch-based binary search to find optimal prediction
    local result = BatchBinarySearch(me, weapon, player, projData, maxTicks)
    if not result then return nil end

    -- Calculate hit chance for this prediction
    local playerIndex = player:GetIndex()

    -- Initialize hit chance tracking
    if not G.HitChanceData.lastPositions[playerIndex] then G.HitChanceData.lastPositions[playerIndex] = {} end
    if not G.HitChanceData.priorPredictions[playerIndex] then G.HitChanceData.priorPredictions[playerIndex] = {} end
    if not G.HitChanceData.hitChanceRecords[playerIndex] then G.HitChanceData.hitChanceRecords[playerIndex] = {} end

    -- Store prediction for hit chance calculation
    local currentTick = result.ticks
    G.HitChanceData.lastPositions[playerIndex][currentTick] = G.HitChanceData.priorPredictions[playerIndex][currentTick] or
        result.position
    G.HitChanceData.priorPredictions[playerIndex][currentTick] = result.position

    local hitChance = calculateHitChancePercentage(
        G.HitChanceData.lastPositions[playerIndex][currentTick],
        G.HitChanceData.priorPredictions[playerIndex][currentTick]
    )

    table.insert(G.HitChanceData.hitChanceRecords[playerIndex], hitChance)

    -- Maintain history size
    local maxRecords = Config.advanced.hitchanceAccuracy or 66
    if #G.HitChanceData.hitChanceRecords[playerIndex] > maxRecords then
        table.remove(G.HitChanceData.hitChanceRecords[playerIndex], 1)
    end

    -- Calculate average hit chance with trust factor
    local totalHitChance = 0
    for _, chance in ipairs(G.HitChanceData.hitChanceRecords[playerIndex]) do
        totalHitChance = totalHitChance + chance
    end

    local avgHitChance = #G.HitChanceData.hitChanceRecords[playerIndex] > 0 and
        (totalHitChance / #G.HitChanceData.hitChanceRecords[playerIndex]) or 0

    -- Apply trust factor
    local numRecords = #G.HitChanceData.hitChanceRecords[playerIndex]
    local growthRate = Config.advanced.accuracyWeight or 5
    local trustFactor = calculateTrustFactor(numRecords, maxRecords, growthRate)

    G.Aimbot.HitChance = avgHitChance * trustFactor

    -- Check minimum hit chance
    if G.Aimbot.HitChance < Config.main.minHitchance then
        return nil
    end

    -- Use trajectory path from binary search result for visuals
    G.Aimbot.TargetPredictionPath = result.trajectoryPath or {}

    -- Check distance constraints
    if (player:GetAbsOrigin() - me:GetAbsOrigin()):Length() < Config.main.minDistance then
        return nil
    end

    return {
        entity = player,
        angles = result.solution.angles,
        factor = 0,
        Prediction = result.position
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
            userCmd.buttons = userCmd.buttons | IN_ATTACK
        end
    end
end

return ProjectileAimbot
