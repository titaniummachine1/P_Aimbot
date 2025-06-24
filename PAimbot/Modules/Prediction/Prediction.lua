---@class Prediction
local Prediction = {}
Prediction.__index = Prediction

-- Reverse imports:
-- Used by: PAimbot.Aimbot, PAimbot.Movement

local Common = require("PAimbot.Common")
local G = require("PAimbot.Globals")

-- Constants and helpers
local vUp = Vector3(0, 0, 1)
local nullVector = Vector3(0, 0, 0)
local ignoreEntities = { "CTFAmmoPack", "CTFDroppedWeapon" }
local MAX_SPEED = 450 -- Default max speed if not provided by player

-- Create a lookup table for faster class checks
local ignoreClassLookup = {}
for _, class in ipairs(ignoreEntities) do
    ignoreClassLookup[class] = true
end

-- Multi-order derivative tracking limits
local POSITION_HISTORY_LIMIT = 10
local VELOCITY_HISTORY_LIMIT = 10
local ACCELERATION_HISTORY_LIMIT = 8
local JERK_HISTORY_LIMIT = 6

-- Player derivative tracking tables
local positionRecords = {}
local velocityRecords = {}
local accelerationRecords = {}
local jerkRecords = {}

--------------------------------------------------------------------------------
-- Multi-Order Derivative Prediction System
--------------------------------------------------------------------------------

-- Update position history for a player
local function updatePositionRecords(player, currentTime)
    if not player or not player:IsAlive() then return end

    local playerIndex = player:GetIndex()
    local currentPos = player:GetAbsOrigin()

    if not positionRecords[playerIndex] then
        positionRecords[playerIndex] = {
            lastPos = currentPos,
            lastTime = currentTime,
            positionHistory = {
                { pos = currentPos, time = currentTime }
            }
        }
        return
    end

    local record = positionRecords[playerIndex]

    table.insert(record.positionHistory, { pos = currentPos, time = currentTime })

    if #record.positionHistory > POSITION_HISTORY_LIMIT then
        table.remove(record.positionHistory, 1)
    end

    record.lastPos = currentPos
    record.lastTime = currentTime
end

-- Calculate current velocity from position history
local function getCurrentVelocityFromHistory(player)
    local playerIndex = player:GetIndex()
    local record = positionRecords[playerIndex]

    if not record or not record.positionHistory or #record.positionHistory < 2 then
        return player:EstimateAbsVelocity()
    end

    local p2 = record.positionHistory[#record.positionHistory].pos
    local t2 = record.positionHistory[#record.positionHistory].time
    local p1 = record.positionHistory[#record.positionHistory - 1].pos
    local t1 = record.positionHistory[#record.positionHistory - 1].time

    local dt = t2 - t1
    if dt <= 0 then return player:EstimateAbsVelocity() end

    return (p2 - p1) / dt
end

-- Update velocity history for a player
local function updateVelocityRecords(player, currentTime)
    if not player or not player:IsAlive() then return end

    local playerIndex = player:GetIndex()
    local currentVel = getCurrentVelocityFromHistory(player)

    if not velocityRecords[playerIndex] then
        velocityRecords[playerIndex] = {
            lastVel = currentVel,
            lastTime = currentTime,
            velocityHistory = {
                { vel = currentVel, time = currentTime }
            }
        }
        return
    end

    local record = velocityRecords[playerIndex]

    table.insert(record.velocityHistory, { vel = currentVel, time = currentTime })

    if #record.velocityHistory > VELOCITY_HISTORY_LIMIT then
        table.remove(record.velocityHistory, 1)
    end

    record.lastVel = currentVel
    record.lastTime = currentTime
end

-- Calculate current acceleration from velocity history
local function getCurrentAcceleration(player)
    local playerIndex = player:GetIndex()
    local record = velocityRecords[playerIndex]

    if not record or not record.velocityHistory or #record.velocityHistory < 2 then
        return Vector3(0, 0, 0)
    end

    local v2 = record.velocityHistory[#record.velocityHistory].vel
    local t2 = record.velocityHistory[#record.velocityHistory].time
    local v1 = record.velocityHistory[#record.velocityHistory - 1].vel
    local t1 = record.velocityHistory[#record.velocityHistory - 1].time

    local dt = t2 - t1
    if dt <= 0 then return Vector3(0, 0, 0) end

    return (v2 - v1) / dt
end

-- Update acceleration history for a player
local function updateAccelerationRecords(player, currentTime)
    if not player or not player:IsAlive() then return end

    local playerIndex = player:GetIndex()
    local currentAccel = getCurrentAcceleration(player)

    if not accelerationRecords[playerIndex] then
        accelerationRecords[playerIndex] = {
            lastAccel = currentAccel,
            lastTime = currentTime,
            accelerationHistory = {
                { accel = currentAccel, time = currentTime }
            }
        }
        return
    end

    local record = accelerationRecords[playerIndex]

    table.insert(record.accelerationHistory, { accel = currentAccel, time = currentTime })

    if #record.accelerationHistory > ACCELERATION_HISTORY_LIMIT then
        table.remove(record.accelerationHistory, 1)
    end

    record.lastAccel = currentAccel
    record.lastTime = currentTime
end

-- Calculate current jerk from acceleration history
local function getCurrentJerk(player)
    local playerIndex = player:GetIndex()
    local record = accelerationRecords[playerIndex]

    if not record or not record.accelerationHistory or #record.accelerationHistory < 2 then
        return Vector3(0, 0, 0)
    end

    local a2 = record.accelerationHistory[#record.accelerationHistory].accel
    local t2 = record.accelerationHistory[#record.accelerationHistory].time
    local a1 = record.accelerationHistory[#record.accelerationHistory - 1].accel
    local t1 = record.accelerationHistory[#record.accelerationHistory - 1].time

    local dt = t2 - t1
    if dt <= 0 then return Vector3(0, 0, 0) end

    return (a2 - a1) / dt
end

-- Update jerk history for a player
local function updateJerkRecords(player, currentTime)
    if not player or not player:IsAlive() then return end

    local playerIndex = player:GetIndex()
    local currentJerk = getCurrentJerk(player)

    if not jerkRecords[playerIndex] then
        jerkRecords[playerIndex] = {
            lastJerk = currentJerk,
            lastTime = currentTime,
            jerkHistory = {
                { jerk = currentJerk, time = currentTime }
            }
        }
        return
    end

    local record = jerkRecords[playerIndex]

    table.insert(record.jerkHistory, { jerk = currentJerk, time = currentTime })

    if #record.jerkHistory > JERK_HISTORY_LIMIT then
        table.remove(record.jerkHistory, 1)
    end

    record.lastJerk = currentJerk
    record.lastTime = currentTime
end

-- Predict future position using Taylor series expansion with derivatives
local function predictPositionWithDerivatives(player, deltaTime)
    local playerIndex = player:GetIndex()

    -- Get current state
    local pos = positionRecords[playerIndex] and positionRecords[playerIndex].lastPos or player:GetAbsOrigin()
    local vel = velocityRecords[playerIndex] and velocityRecords[playerIndex].lastVel or Vector3(0, 0, 0)
    local accel = accelerationRecords[playerIndex] and accelerationRecords[playerIndex].lastAccel or Vector3(0, 0, 0)
    local jerk = jerkRecords[playerIndex] and jerkRecords[playerIndex].lastJerk or Vector3(0, 0, 0)

    -- Taylor series expansion: p(t) = p₀ + v₀t + ½a₀t² + ⅙j₀t³
    local dt = deltaTime
    local dt2 = dt * dt
    local dt3 = dt2 * dt

    local predictedPos = pos + vel * dt + accel * (0.5 * dt2) + jerk * (dt3 / 6.0)

    return predictedPos, vel + accel * dt + jerk * (0.5 * dt2)
end

-- Clean up records for invalid or dormant players
local function cleanupDerivativeRecords()
    local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")
    local players = FastPlayers.GetAll()
    local validIndices = {}

    for _, player in pairs(players) do
        local playerRaw = player._rawEntity
        if playerRaw and playerRaw:IsAlive() and not playerRaw:IsDormant() then
            validIndices[playerRaw:GetIndex()] = true
        end
    end

    -- Clean up position records
    for index, _ in pairs(positionRecords) do
        if not validIndices[index] then
            positionRecords[index] = nil
        end
    end

    -- Clean up velocity records
    for index, _ in pairs(velocityRecords) do
        if not validIndices[index] then
            velocityRecords[index] = nil
        end
    end

    -- Clean up acceleration records
    for index, _ in pairs(accelerationRecords) do
        if not validIndices[index] then
            accelerationRecords[index] = nil
        end
    end

    -- Clean up jerk records
    for index, _ in pairs(jerkRecords) do
        if not validIndices[index] then
            jerkRecords[index] = nil
        end
    end
end

-- Update all derivative records for a player
local function updateAllDerivativeRecords(player, currentTime)
    updatePositionRecords(player, currentTime)
    updateVelocityRecords(player, currentTime)
    updateAccelerationRecords(player, currentTime)
    updateJerkRecords(player, currentTime)
end

--------------------------------------------------------------------------------
-- Helper Functions
--------------------------------------------------------------------------------
-- Determines if an entity should be considered for collision
---@param entity Entity The entity to check
---@param player Entity The player entity to compare against
---@return boolean Whether the entity should be hit by traces
local function shouldHitEntityFun(entity, player)
    -- Branchless entity collision check using mathematical operations
    local entityClass = entity:GetClass()
    local isIgnoredClass = ignoreClassLookup[entityClass] and 1 or 0
    local isSameEntity = (entity == player) and 1 or 0
    local isSameTeam = (entity:GetTeamNumber() == player:GetTeamNumber()) and 1 or 0

    local pos = entity:GetAbsOrigin() + Vector3(0, 0, 1)
    local contents = engine.GetPointContents(pos)
    local isNotEmpty = (contents ~= CONTENTS_EMPTY) and 1 or 0

    -- Sum all the "should ignore" conditions - if any are true (sum > 0), we ignore
    local ignoreScore = isIgnoredClass + isSameEntity + isSameTeam + isNotEmpty

    -- Return true only if ignoreScore is 0 (no ignore conditions met)
    return ignoreScore == 0
end

-- Clamp velocity components per axis (sv_maxvelocity)
---@param velocity Vector3 The velocity vector to clamp
---@param maxVel number Maximum velocity per axis
---@return Vector3 Clamped velocity vector
local function clampVelocityPerAxis(velocity, maxVel)
    -- Branchless per-axis clamping
    local x = velocity.x
    local y = velocity.y
    local z = velocity.z

    -- Clamp X axis
    local xExceeds = (math.abs(x) > maxVel) and 1 or 0
    local xSign = (x > 0) and 1 or -1
    x = x * (1 - xExceeds) + (maxVel * xSign * xExceeds)

    -- Clamp Y axis
    local yExceeds = (math.abs(y) > maxVel) and 1 or 0
    local ySign = (y > 0) and 1 or -1
    y = y * (1 - yExceeds) + (maxVel * ySign * yExceeds)

    -- Clamp Z axis
    local zExceeds = (math.abs(z) > maxVel) and 1 or 0
    local zSign = (z > 0) and 1 or -1
    z = z * (1 - zExceeds) + (maxVel * zSign * zExceeds)

    return Vector3(x, y, z)
end

--------------------------------------------------------------------------------
-- Prediction State: reset, initialization, and update
--------------------------------------------------------------------------------
---@param self Prediction
function Prediction:reset()
    -- Clear simulation history
    self.currentTick = 0
    self.cachedPredictions = { pos = {}, vel = {}, onGround = {} }

    -- Clear physics variables
    self.gravity = nil
    self.stepHeight = nil
    self.position = nil
    self.velocity = nil
    self.onGround = nil
    self.deltaStrafe = nil
    self.vStep = nil
    self.hitbox = nil
    self.MAX_SPEED = nil
    self.shouldHitEntity = nil
    self.terminalVelocity = nil
    self.maxVelocity = nil

    -- Variables for move intent simulation
    self.moveIntent = nil        -- Current intended movement vector
    self.initialMoveIntent = nil -- Baseline movement vector at start
    self.accumulatedStrafe = 0   -- Accumulated strafe angle (in degrees)

    -- Advanced prediction variables
    self.useAdvancedPrediction = true
    self.currentTime = globals.RealTime()
end

-- Update simulation state from the current player's data
---@param self Prediction
---@param player Entity The player entity to simulate
function Prediction:update(player)
    -- Only reset if we don't have cached data or player changed
    if not self.cachedPredictions or not self.cachedPredictions.pos or #self.cachedPredictions.pos == 0 then
        self:reset()
    end

    -- Update derivative tracking for this player
    updateAllDerivativeRecords(player, self.currentTime)

    -- Get physics constants from game
    self.gravity = client.GetConVar("sv_gravity") or 800
    self.acceleration = client.GetConVar("sv_accelerate") or 10
    self.friction = client.GetConVar("sv_friction") or 4
    self.stepHeight = player:GetPropFloat("localdata", "m_flStepSize") or 18

    -- TF2 Terminal Velocity (based on fall damage plateau at ~3500 HU/s)
    self.terminalVelocity = -3500 -- Negative because downward

    -- TF2 Maximum Velocity per axis (sv_maxvelocity)
    self.maxVelocity = client.GetConVar("sv_maxvelocity") or 3500

    -- Set up hitbox dimensions based on player state
    G.Hitbox.Max.z = Common.IsOnGround(player) and 62 or 82
    self.hitbox = G.Hitbox or { Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82) }
    self.vStep = Vector3(0, 0, self.stepHeight)

    -- Get current player state
    self.position = player:GetAbsOrigin()
    self.velocity = player:EstimateAbsVelocity()
    self.onGround = Common.IsOnGround(player)
    self.MAX_SPEED = player:GetPropFloat("m_flMaxspeed") or MAX_SPEED

    -- Set the move intent based on current velocity direction
    local horizontalVel = Vector3(self.velocity.x, self.velocity.y, 0)
    if horizontalVel:Length() > 50 then -- Only if actually moving with decent speed
        self.initialMoveIntent = horizontalVel
        self.moveIntent = horizontalVel
    else
        -- If not moving, no move intent (standing still)
        self.initialMoveIntent = Vector3(0, 0, 0)
        self.moveIntent = Vector3(0, 0, 0)
    end

    self.accumulatedStrafe = 0

    -- Create a closure for entity collision detection
    self.shouldHitEntity = function(entity)
        return shouldHitEntityFun(entity, player)
    end

    -- Get enhanced motion data from history
    local playerIndex = player:GetIndex()
    local motionData = G.history[playerIndex] or {
        strafeDelta = 0,
        acceleration = Vector3(0, 0, 0),
        jerk = Vector3(0, 0, 0),
        predictabilityScore = 1.0
    }
    self.deltaStrafe = motionData.strafeDelta
    self.motionData = motionData

    -- Store player reference for advanced prediction
    self.player = player

    -- Clear the current tick counter for fresh prediction
    self.currentTick = 0

    -- Store initial state as tick 0
    self.cachedPredictions.pos[1] = self.position
    self.cachedPredictions.vel[1] = self.velocity
    self.cachedPredictions.onGround[1] = self.onGround
end

--------------------------------------------------------------------------------
-- predictTick: Simulate one tick of prediction.
--
-- This function simulates one physics tick, updating position based on current velocity,
-- applying gravity, friction, and handling collisions. Each tick builds on the previous.
--------------------------------------------------------------------------------
---@param self Prediction
---@return table Result containing position, velocity and ground state
function Prediction:predictTick()
    local dt = G.TickInterval

    -- Start with current simulation state (this accumulates over ticks)
    local pos = self.position
    local vel = self.velocity
    local onGround = self.onGround

    -- Apply gravity if airborne
    if not onGround then
        vel.z = vel.z - self.gravity * dt
    end

    -- Apply terminal velocity clamping
    if vel.z < self.terminalVelocity then
        vel.z = self.terminalVelocity
    end

    -- Update strafe based on enhanced motion data (simulate continuous strafing)
    if self.motionData and self.motionData.strafeDelta ~= 0 then
        local strafeInfluence = self.motionData.strafeDelta

        -- Scale strafe influence by predictability (less predictable = less influence)
        if self.motionData.predictabilityScore then
            strafeInfluence = strafeInfluence * (1.0 - self.motionData.predictabilityScore * 0.3)
        end

        self.accumulatedStrafe = self.accumulatedStrafe + strafeInfluence
        self.moveIntent = Common.RotateVector(self.initialMoveIntent, self.accumulatedStrafe)
    end

    -- Apply acceleration and jerk if available in motion data
    if self.motionData and self.motionData.acceleration then
        -- Apply a small portion of acceleration to the velocity prediction
        vel = vel + self.motionData.acceleration * dt * 0.1 -- Scale down to avoid overshooting
    end

    -- Get desired horizontal movement direction
    local desiredDir = Vector3(0, 0, 0)
    local horizontalMoveIntent = Vector3(self.moveIntent.x, self.moveIntent.y, 0)
    if horizontalMoveIntent:Length() > 0 then
        desiredDir = Common.Normalize(horizontalMoveIntent)
    end
    local desiredSpeed = self.MAX_SPEED

    -- Apply friction if on ground
    local currentHorizontal = Vector3(vel.x, vel.y, 0)
    local currentSpeed = currentHorizontal:Length()

    if onGround and currentSpeed > 0 then
        local drop = currentSpeed * self.friction * dt
        local newSpeed = math.max(currentSpeed - drop, 0)
        if currentSpeed > 0 then
            currentHorizontal = currentHorizontal * (newSpeed / currentSpeed)
        end
    end

    -- Apply acceleration toward desired direction
    if desiredDir:Length() > 0 then
        local speedAlongWish = currentHorizontal:Dot(desiredDir)
        local addSpeed = desiredSpeed - speedAlongWish
        if addSpeed > 0 then
            local accelSpeed = math.min(self.acceleration * desiredSpeed * dt, addSpeed)
            currentHorizontal = currentHorizontal + desiredDir * accelSpeed
        end
    end

    -- Clamp horizontal speed
    local horizontalSpeed = currentHorizontal:Length()
    if horizontalSpeed > desiredSpeed then
        currentHorizontal = currentHorizontal * (desiredSpeed / horizontalSpeed)
    end

    -- Update velocity
    vel.x = currentHorizontal.x
    vel.y = currentHorizontal.y

    -- Calculate new position
    local newPos = pos + vel * dt

    -- Wall collision detection
    local wallTrace = Common.TRACE_HULL(
        pos + self.vStep,
        newPos + self.vStep,
        self.hitbox.Min,
        self.hitbox.Max,
        MASK_PLAYERSOLID,
        self.shouldHitEntity
    )

    if wallTrace.fraction < 1.0 then
        -- Hit a wall - slide along it
        local normal = wallTrace.plane
        local dot = vel:Dot(normal)
        if dot < 0 then
            vel = vel - normal * dot -- Remove velocity component into wall
        end
        newPos.x = wallTrace.endpos.x
        newPos.y = wallTrace.endpos.y
        -- Keep Z movement
    end

    -- Ground collision detection
    local downStep = onGround and self.vStep or nullVector
    local groundTrace = Common.TRACE_HULL(
        newPos + self.vStep,
        newPos - downStep,
        self.hitbox.Min,
        self.hitbox.Max,
        MASK_PLAYERSOLID,
        self.shouldHitEntity
    )

    if groundTrace.fraction < 1.0 then
        local groundNormal = groundTrace.plane
        local groundAngle = math.deg(math.acos(math.max(0, math.min(1, groundNormal:Dot(vUp)))))

        if groundAngle < 45 then -- Walkable surface
            newPos = groundTrace.endpos
            onGround = true
            vel.z = 0
        elseif groundAngle >= 45 and groundAngle < 55 then -- Slippery surface
            vel = Vector3(0, 0, 0)                         -- Stop all movement
        else                                               -- Wall-like surface
            local wallDot = vel:Dot(groundNormal)
            vel = vel - groundNormal * wallDot
            onGround = true
        end
    else
        onGround = false -- Not touching ground
    end

    -- Apply sv_maxvelocity clamping per axis
    vel = clampVelocityPerAxis(vel, self.maxVelocity)

    -- Update simulation state for next tick
    self.position = newPos
    self.velocity = vel
    self.onGround = onGround
    self.currentTick = self.currentTick + 1

    -- Cache results
    self.cachedPredictions.pos[self.currentTick + 1] = newPos
    self.cachedPredictions.vel[self.currentTick + 1] = vel
    self.cachedPredictions.onGround[self.currentTick + 1] = onGround

    return { pos = newPos, vel = vel, onGround = onGround }
end

--------------------------------------------------------------------------------
-- Public API for running multiple ticks and rewinding
--------------------------------------------------------------------------------
---@param self Prediction
---@param ticks number Number of ticks to predict forward
---@return table Result containing position, velocity and ground state
function Prediction:predict(ticks)
    ticks = ticks or 1
    for i = 1, ticks do
        self:predictTick()
    end
    return {
        pos = self.cachedPredictions.pos[self.currentTick],
        vel = self.cachedPredictions.vel[self.currentTick],
        onGround = self.cachedPredictions.onGround[self.currentTick]
    }
end

---@param self Prediction
---@param ticks number Number of ticks to rewind
---@return table Result containing position, velocity and ground state
function Prediction:rewind(ticks)
    ticks = ticks or 1
    local targetTick = self.currentTick - ticks
    if targetTick < 1 then targetTick = 1 end
    self.currentTick = targetTick
    return {
        pos = self.cachedPredictions.pos[self.currentTick],
        vel = self.cachedPredictions.vel[self.currentTick],
        onGround = self.cachedPredictions.onGround[self.currentTick]
    }
end

---@param self Prediction
---@return table Complete prediction history
function Prediction:history()
    return self.cachedPredictions
end

-- Get prediction quality metrics for a player
---@param self Prediction
---@param player Entity The player to get metrics for
---@return table Prediction quality metrics
function Prediction:getPredictionQuality(player)
    if not player then return { quality = 0, dataPoints = 0, method = "none" } end

    local playerIndex = player:GetIndex()
    local posRecord = positionRecords[playerIndex]
    local velRecord = velocityRecords[playerIndex]
    local accelRecord = accelerationRecords[playerIndex]
    local jerkRecord = jerkRecords[playerIndex]

    local posDataPoints = posRecord and #posRecord.positionHistory or 0
    local velDataPoints = velRecord and #velRecord.velocityHistory or 0
    local accelDataPoints = accelRecord and #accelRecord.accelerationHistory or 0
    local jerkDataPoints = jerkRecord and #jerkRecord.jerkHistory or 0

    local totalDataPoints = posDataPoints + velDataPoints + accelDataPoints + jerkDataPoints
    local maxPossibleDataPoints = POSITION_HISTORY_LIMIT + VELOCITY_HISTORY_LIMIT + ACCELERATION_HISTORY_LIMIT +
        JERK_HISTORY_LIMIT

    local quality = totalDataPoints / maxPossibleDataPoints

    local method = "physics"
    if posDataPoints >= 3 and velDataPoints >= 3 and accelDataPoints >= 2 then
        method = "derivatives"
        if jerkDataPoints >= 2 then
            method = "advanced_derivatives"
        end
    end

    return {
        quality = quality,
        dataPoints = totalDataPoints,
        method = method,
        details = {
            position = posDataPoints,
            velocity = velDataPoints,
            acceleration = accelDataPoints,
            jerk = jerkDataPoints
        }
    }
end

-- Update all player derivative records (call this every frame)
---@param self Prediction
function Prediction:updateDerivativeTracking()
    local currentTime = globals.RealTime()
    local FastPlayers = require("PAimbot.Modules.Helpers.FastPlayers")
    local players = FastPlayers.GetEnemies()

    for _, player in pairs(players) do
        local playerRaw = player._rawEntity
        if playerRaw and playerRaw:IsAlive() and not playerRaw:IsDormant() then
            updateAllDerivativeRecords(playerRaw, currentTime)
        end
    end

    -- Clean up records for invalid players
    cleanupDerivativeRecords()
end

-- Enable or disable advanced prediction
---@param self Prediction
---@param enabled boolean Whether to use advanced prediction
function Prediction:setAdvancedPrediction(enabled)
    self.useAdvancedPrediction = enabled
end

-- Get derivative data for debugging
---@param self Prediction
---@param player Entity The player to get data for
---@return table Derivative data
function Prediction:getDerivativeData(player)
    if not player then return {} end

    local playerIndex = player:GetIndex()

    return {
        position = positionRecords[playerIndex],
        velocity = velocityRecords[playerIndex],
        acceleration = accelerationRecords[playerIndex],
        jerk = jerkRecords[playerIndex]
    }
end

-- Get predicted position at a specific time offset
---@param self Prediction
---@param player Entity The player to predict for
---@param timeOffset number Time offset in seconds
---@return Vector3|nil Predicted position
function Prediction:predictPositionAt(player, timeOffset)
    if not player or timeOffset <= 0 then return nil end

    local playerIndex = player:GetIndex()
    local posRecord = positionRecords[playerIndex]
    local velRecord = velocityRecords[playerIndex]
    local accelRecord = accelerationRecords[playerIndex]

    -- Use advanced prediction if we have sufficient data
    if posRecord and velRecord and accelRecord and
        #posRecord.positionHistory >= 3 and
        #velRecord.velocityHistory >= 3 and
        #accelRecord.accelerationHistory >= 2 then
        local predictedPos, _ = predictPositionWithDerivatives(player, timeOffset)
        return predictedPos
    else
        -- Fall back to simple linear prediction
        local currentPos = player:GetAbsOrigin()
        local currentVel = player:EstimateAbsVelocity()
        return currentPos + currentVel * timeOffset
    end
end

--------------------------------------------------------------------------------
-- Create and return the singleton Prediction instance
--------------------------------------------------------------------------------
local predictionInstance = setmetatable({}, Prediction)
predictionInstance:reset()
return predictionInstance
