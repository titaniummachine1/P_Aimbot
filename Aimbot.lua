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

---@alias AimTarget { entity : Entity, angles : EulerAngles, factor : number }

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.987, "lnxLib version is too old, please update it!")

local Math, Conversion = lnxLib.Utils.Math, lnxLib.Utils.Conversion
local WPlayer = lnxLib.TF2.WPlayer
local Helpers = lnxLib.TF2.Helpers
local Fonts = lnxLib.UI.Fonts

local Hitbox = {
   Head = 1,
   Neck = 2,
   Pelvis = 4,
   Body = 5,
   Chest = 7,
   Feet = 11,
}

local Menu = { -- this is the config that will be loaded every time u load the script

   tabs = {   -- dont touch this, this is just for managing the tabs in the menu
      Main = true,
      Advanced = false,
      Visuals = false,
   },

   Main = {
      AimKey = gui.GetValue("aim key"),
      AutoShoot = gui.GetValue("auto shoot") == 1 and true or false,
      Silent = true,
      pSilent = gui.GetValue("aim method (projectile)") == "silent +",
      MinDistance = 100,
      MaxDistance = 1500,
      MinHitchance = 40,
   },

   Advanced = {
      SplashPrediction = true,
      SplashAccuracy = 4,
      PredTicks = 77,
      Hitchance_Accuracy = 10,
      AccuracyWeight = 5,
      StrafePrediction = true,
      StrafeSamples = 4,
      ProjectileSegments = 10,
      Aim_Modes = {
         Leading = true,
         trailing = false,
      },
   },

   Visuals = {
      Active = true,
      VisualizePath = true,
      Path_styles = { "Line", "Alt Line", "Dashed" },
      Path_styles_selected = 1,
      VisualizeHitchance = false,
      VisualizeProjectile = false,
      VisualizeHitPos = false,
      Crosshair = false,
      NccPred = false
   },
}

-- Cache API calls for optimization
local math = math
local engine = engine
local globals = globals
local table = table

local math_atan = math.atan
local math_cos = math.cos
local math_sin = math.sin
local math_sqrt = math.sqrt
local math_floor = math.floor
local math_rad = math.rad
local math_deg = math.deg

local TickInterval = globals.TickInterval

local TraceLine = engine.TraceLine
local TraceHull = engine.TraceHull

local GetConVar = client.GetConVar
local WorldToScreen = client.WorldToScreen

local FindByClass = entities.FindByClass

local ipairs = ipairs

local draw_Line = draw.Line
local draw_Text = draw.Text
local draw_FilledRect = draw.FilledRect

local Vector3 = Vector3

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
      printc(255, 183, 0, 255, "[" .. os.date("%H:%M:%S") .. "] Saved Config to " .. tostring(fullPath))
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
         printc(0, 255, 140, 255, "[" .. os.date("%H:%M:%S") .. "] Loaded Config from " .. tostring(fullPath))
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
local strafeAngles = {} ---@type number[]
local hitChance = 0
local lastPosition = {}
local priorPrediction = {}
local hitChanceRecords = {}
local vPath = {}
local vHitbox = { Vector3(-22, -22, 0), Vector3(22, 22, 80) }
local MAX_ANGLE_HISTORY = Menu.Advanced.StrafeSamples -- Number of past angles to consider for averaging
local MAX_CENTER_HISTORY = 5                          -- Maximum number of center samples to consider for smoothing

local strafeAngleHistories = {}                       -- History of strafe angles for each player
local centerHistories = {}                            -- History of center directions for each player

function Normalize(vec)
   local length = math_sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
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
   local players = FindByClass("CTFPlayer")

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
            local center = angle.y -- Use the most recent angle as the center
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

local M_RADPI = 180 / math.pi

local function isNaN(x) return x ~= x end

-- Normalize vector function
local function Normalize(Vector)
   return Vector / Vector:Length()
end

-- Rotate vector function
local function RotateVector(vector, angle)
   local rad = math_rad(angle)
   local cosAngle = math_cos(rad)
   local sinAngle = math_sin(rad)
   return Vector3(
      vector.x * cosAngle - vector.y * sinAngle,
      vector.x * sinAngle + vector.y * cosAngle,
      vector.z
   )
end

-- Define the necessary variables
local vUp = Vector3(0, 0, 1)           -- Replace with the actual up vector
local GROUND_COLLISION_ANGLE_LOW = 45  -- Replace with the actual value
local GROUND_COLLISION_ANGLE_HIGH = 60 -- Replace with the actual value
local FORWARD_COLLISION_ANGLE = 55

local projectileSimulation = {}
local projectileSimulation2 = Vector3()

-- Helper function for forward collision
local function handleForwardCollision(vel, wallTrace)
   local normal = wallTrace.plane
   local angle = math_deg(math.acos(normal:Dot(vUp)))
   if angle > FORWARD_COLLISION_ANGLE then
      local dot = vel:Dot(normal)
      vel = vel - normal * dot
   end
   return wallTrace.endpos.x, wallTrace.endpos.y
end

-- Helper function for ground collision
local function handleGroundCollision(vel, groundTrace)
   local normal = groundTrace.plane
   local angle = math_deg(math.acos(normal:Dot(vUp)))
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

local function calculateHitChancePercentage(lastPredictedPos, currentPos)
   if not lastPredictedPos then
      print("lastPosition is NIL ~~!!!!")
      return 0
   end

   -- Calculate horizontal distance (2D distance on the X-Y plane)
   local horizontalDistance = math_sqrt((currentPos.x - lastPredictedPos.x) ^ 2 + (currentPos.y - lastPredictedPos.y) ^
      2)

   -- Calculate vertical distance with an allowance for vertical movement
   local verticalDistance = math.abs(currentPos.z - lastPredictedPos.z)

   -- Define maximum acceptable distances
   local maxHorizontalDistance = 12 -- Max acceptable horizontal distance in units
   local maxVerticalDistance = 45 -- Max acceptable vertical distance in units

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

   -- Perform a trace line downwards from the calculated point to ensure it's on solid ground
   local traceDown = TraceLine(point, point + Vector3(0, 0, -100), 100679691, shouldhitentity)

   -- Check if the end point is within an acceptable range to the target
   local distanceToTarget = (traceDown.endpos - dest):Length()
   if distanceToTarget > distance then
      local excessDistance = distanceToTarget - distance
      local directionToDest = Normalize(traceDown.endpos - dest)
      traceDown.endpos = traceDown.endpos + directionToDest * excessDistance
   end

   -- Perform a final visibility check from the origin to the destination
   local visibilityCheck = TraceLine(origin, dest, 100679691, shouldhitentity)
   if visibilityCheck.fraction > 0.9 then
      return false
   end

   return true, traceDown.endpos -- Path is clear and within range
end

-- Function to find the best shooting position
local function FindBestShootingPosition(origin, dest, target, BlastRadius)
   -- Helper function to check path clearance in a given direction and angle
   local function checkPath(direction, angle, distance)
      local point = dest + RotateVector(direction, angle) * distance

      -- Perform a trace line from origin to the point
      local traceLineOriginToPoint = TraceLine(origin, point, 100679691,
         function(entity) return entity:GetIndex() ~= target:GetIndex() end)

      -- Return whether the path is clear and the actual end position
      return traceLineOriginToPoint.fraction > 0.9, traceLineOriginToPoint.endpos
   end

   -- Perform an initial trace from origin to destination
   local initialTrace = TraceLine(origin, dest, 100679691,
      function(entity) return entity:GetIndex() ~= target:GetIndex() end)

   -- If the initial trace hits something other than the target, find a better shooting position
   if initialTrace.fraction < 1 and initialTrace.entity:GetIndex() ~= target:GetIndex() then
      local direction = Normalize(dest - origin)

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
         local bestPoint = maxDistancePoint -- Start with the farthest point
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

      return false -- No valid shooting position found
   end

   return dest -- If the initial trace is clear, return the destination as the best shooting position
end

-- Precompute and cache frequently used constants and empty vectors
local MASK_PLAYERSOLID = 100679691 -- Example value; replace with the actual value from your environment for tracing
local FULL_HIT_FRACTION = 1.0           -- Represents a full hit fraction in trace results
local DRAG_COEFFICIENT = 0.029374       -- Combined drag coefficients for drag simulation

-- Function to solve projectile trajectory and return the necessary angles and time to hit a target
---@param origin Vector3  -- The starting position of the projectile
---@param dest Vector3  -- The destination or target position
---@param speed number  -- The initial speed of the projectile
---@param gravity number  -- The gravity factor affecting the projectile
---@param sv_gravity number  -- The server's gravity setting
---@param target Entity  -- The target entity to avoid hitting with the projectile
---@param timeToHit number  -- The maximum allowed time to hit the target
---@return { angles: EulerAngles, time: number, Prediction: Vector3, Positions: table }|false?  -- Returns calculated angles, time, predicted final position, and the flight path positions
local function SolveProjectile(origin, dest, speed, gravity, sv_gravity, target, timeToHit)
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
      local trace = TraceLine(origin, dest, MASK_PLAYERSOLID)
      if trace.fraction ~= FULL_HIT_FRACTION and trace.entity:GetName() ~= target:GetName() then
         return false -- Path is obstructed, so return false
      end

      projectileSimulation = { origin, trace.endpos }

      -- Return the result with no gravity calculations
      return {
         angles = Math.PositionAngles(origin, dest),
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
      local sqrt_discriminant = math_sqrt(discriminant)
      local pitch_angle = math_atan((speed_squared - sqrt_discriminant) / (effective_gravity * horizontal_distance))
      local yaw_angle = math_atan(direction.y, direction.x)

      if isNaN(pitch_angle) or isNaN(yaw_angle) then return nil end

      -- Convert the pitch and yaw into Euler angles
      local calculated_angles = EulerAngles(pitch_angle * -M_RADPI, yaw_angle * M_RADPI)

      -- Calculate the time it takes for the projectile to reach the target
      local time_to_target = horizontal_distance / (math_cos(pitch_angle) * speed)

      if time_to_target > timeToHit then
         return false -- Projectile will fly out of range, so return false
      end

      -- Define the number of segments to divide the trajectory into for simulation (default is 2)
      local number_of_segments = math.max(1, Menu.Advanced.ProjectileSegments or 2)
      local segment_duration = time_to_target / number_of_segments
      local current_position = origin
      local current_velocity = speed

      -- Table to store positions along the projectile's path
      projectileSimulation = { current_position }

      -- Simulate the projectile's flight path
      for segment = 1, number_of_segments do
         local time_segment = segment * segment_duration

         -- Apply drag to the current velocity over time
         current_velocity = current_velocity * math.exp(-DRAG_COEFFICIENT * time_segment)

         -- Calculate the new position based on current velocity, pitch, yaw, and gravity
         local horizontal_displacement = current_velocity * math_cos(pitch_angle) * time_segment
         local vertical_displacement = current_velocity * math_sin(pitch_angle) * time_segment -
            0.5 * effective_gravity * time_segment * time_segment
         local new_position = origin +
            Vector3(horizontal_displacement * math_cos(yaw_angle), horizontal_displacement * math_sin(yaw_angle),
               vertical_displacement)

         -- Perform a trace to check for collisions
         local trace = TraceLine(current_position, new_position, MASK_PLAYERSOLID, shouldHitEntity)

         -- Save the new position to the projectile path
         table.insert(projectileSimulation, new_position)

         -- Check if the projectile collided with something that isn't the target
         if trace.fraction < FULL_HIT_FRACTION and trace.entity ~= target then
            return false -- Collision detected, exit the loop
         end

         -- Update the current position for the next segment
         current_position = new_position
      end

      -- Return the calculated angles, time to target, final predicted position, and all positions along the path
      return {
         angles = calculated_angles,
         time = time_to_target,
         Prediction = current_position,
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

-- Function to calculate the trust factor based on the number of records
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
   trustFactor = math_floor(trustFactor * 100 + 0.5) / 100

   return trustFactor
end

-- Function to calculate the adjusted hit chance
local function calculateAdjustedHitChance(hitChance, trustFactor)
   -- Apply the trust factor as a multiplier to the hit chance
   return math_floor(hitChance * trustFactor * 100 + 0.5) / 100
end

local function GetBonePosition(entity, hitbox)
    local model = entity:GetModel()
    local studioHdr = models.GetStudioModel(model)

    local myHitBoxSet = entity:GetPropInt("m_nHitboxSet")
    local hitboxSet = studioHdr:GetHitboxSet(myHitBoxSet)
    local hitboxes = hitboxSet:GetHitboxes()
    local boneMatrices = entity:SetupBones()
    local hitbox = hitboxes[hitbox]
    local bone = hitbox:GetBone()
    local boneMatrix = boneMatrices[bone]
    if boneMatrix == nil then return nil end
    local bonePos = Vector3( boneMatrix[1][4], boneMatrix[2][4], boneMatrix[3][4] )
    return bonePos
end

---@param player Entity
local function GetBodyPosition (player)
    return GetBonePosition(player, Hitbox.Body)
end

local function GetHeadPosition(player)
    return GetBonePosition(player, Hitbox.Head)
end

local function GetFeetPosition (player)
    return player:GetAbsOrigin() + Vector3(0,0,10)
end

local function GetAimPos(weapon, player)
   --local aimPos = weapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_ROCKET and GetFeetPosition(player) or weapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_ARROW and GetHeadPosition(player) or GetBodyPosition(player)
   local class = player:GetPropInt("m_PlayerClass", "m_iClass")
   if weapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_ROCKET
   or weapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_PIPEBOMB then
      return GetFeetPosition(player)
   elseif weapon:GetWeaponProjectileType() == E_ProjectileType.TF_PROJECTILE_ARROW then
      --- player is a medic or sniper?
      if class == 2 then --- medic
         return GetBodyPosition(player)
      elseif class == 5 then --- sniper
         return GetHeadPosition(player)
      end
   else
      return GetBodyPosition(player)
   end
end

-- Main function
local function CheckProjectileTarget(me, weapon, player)
   local tick_interval = TickInterval()
   local shootPos = me:GetEyePos()
   local aimPos = GetAimPos(weapon, player)
   if not aimPos then return nil end
   local aimOffset = aimPos - player:GetAbsOrigin()
   local gravity = GetConVar("sv_gravity")
   local stepSize = player:GetPropFloat("localdata", "m_flStepSize")
   local strafeAngle = Menu.Advanced.StrafePrediction and strafeAngles[player:GetIndex()] or nil
   local vStep = Vector3(0, 0, stepSize / 2)
   vPath = {}
   local lastP, lastV, lastG = player:GetAbsOrigin(), player:EstimateAbsVelocity(), IsOnGround(player)
   local BlastRadius = 150

   -- trace ignore simulated player
   local function shouldHitEntity(entity)
      return entity:GetIndex() ~= player:GetIndex() or
         entity:GetTeamNumber() ~= player:GetTeamNumber()
   end

   -- Check initial conditions
   local projInfo = weapon:GetProjectileInfo()
   if not projInfo or not gravity or not stepSize then return nil end

   local PredTicks = Menu.Advanced.PredTicks

   local speed = projInfo[1]
   if me:DistTo(player) > PredTicks * speed then return nil end

   local targetAngles, fov

   -- Initialize storage for predictions if not already initialized
   if not lastPosition[player:GetIndex()] then lastPosition[player:GetIndex()] = {} end
   if not priorPrediction[player:GetIndex()] then priorPrediction[player:GetIndex()] = {} end
   if not hitChanceRecords[player:GetIndex()] then hitChanceRecords[player:GetIndex()] = {} end

   -- Variables to accumulate hit chances
   local totalHitChance = 0
   local tickCount = 0

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
      local wallTrace = TraceHull(lastP + vStep, pos + vStep, vHitbox[1], vHitbox[2], MASK_PLAYERSOLID,
         shouldHitEntity)
      if wallTrace.fraction < 1 then
         pos.x, pos.y = handleForwardCollision(vel, wallTrace)
      end

      -- Ground Collision
      local downStep = onGround and vStep or Vector3()
      local groundTrace = TraceHull(pos + vStep, pos - downStep, vHitbox[1], vHitbox[2], MASK_PLAYERSOLID,
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
         lastPosition[player:GetIndex()][currentTick] = priorPrediction[player:GetIndex()][currentTick] or pos

         -- Update priorPrediction with the current predicted position for this tick
         priorPrediction[player:GetIndex()][currentTick] = pos

         -- Calculate hit chance for the current tick
         local hitChance1 = calculateHitChancePercentage(lastPosition[player:GetIndex()][currentTick],
            priorPrediction[player:GetIndex()][currentTick])

         -- Insert the hit chance record
         table.insert(hitChanceRecords[player:GetIndex()], hitChance1)

         -- Ensure the number of records does not exceed the maximum allowed
         local maxRecords = Menu.Advanced.Hitchance_Accuracy
         if #hitChanceRecords[player:GetIndex()] > maxRecords then
            table.remove(hitChanceRecords[player:GetIndex()], 1) -- Remove the oldest record
         end

         -- Accumulate hit chance and tick count
         totalHitChance = totalHitChance + hitChance1
         tickCount = tickCount + 1
      end

      -- Solve the projectile based on the current position
      local solution = SolveProjectile(shootPos, pos, projInfo[1], projInfo[2], gravity, player,
         PredTicks * tick_interval)
      if solution == nil then goto continue end

      if not solution then
         if Menu.Advanced.SplashPrediction and projInfo[2] == 0 then
            local bestPos = FindBestShootingPosition(shootPos, pos, player, BlastRadius)
            if bestPos then
               solution = SolveProjectile(shootPos, bestPos, projInfo[1], projInfo[2], gravity, player,
                  PredTicks * tick_interval)
            end
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

   -- Calculate the average hit chance and set the global hitChance variable
   if tickCount > 0 then
      hitChance = totalHitChance / tickCount
   else
      hitChance = 0
   end

   -- Calculate trust factor based on the number of records
   local numRecords = #hitChanceRecords[player:GetIndex()]
   local growthRate = Menu.Advanced.AccuracyWeight or 5 -- Customize as needed
   local trustFactor = calculateTrustFactor(numRecords, Menu.Advanced.Hitchance_Accuracy, growthRate)

   -- Adjust the average hit chance based on trust factor
   hitChance = calculateAdjustedHitChance(hitChance, trustFactor)

   -- Check if the average adjusted hit chance meets the minimum required threshold
   if hitChance < Menu.Main.MinHitchance then
      return nil -- If not, return nil to indicate that the prediction is not reliable
   end

   if not targetAngles or (player:GetAbsOrigin() - me:GetAbsOrigin()):Length() < 100 or not lastPosition[player:GetIndex()] then
      return nil
   end

   return { entity = player, angles = targetAngles, factor = fov, Prediction = vPath[#vPath] }
end

local function GetBestTarget(me, weapon)
   local players = FindByClass("CTFPlayer")
   local bestTarget = nil
   local bestFactor = 0
   local localPlayerOrigin = me:GetAbsOrigin()
   local localPlayerViewAngles = engine.GetViewAngles()

   if not weapon:IsShootingWeapon() then
      return nil
   end

   for _, player in pairs(players) do
      if player == nil or not player:IsAlive()
         or player:IsDormant()
         or player == me or player:GetTeamNumber() == me:GetTeamNumber()
         or gui.GetValue("ignore cloaked") == 1 and player:InCond(4) then
         goto continue
      end

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
      local isVisible = Helpers.VisPos(player, localPlayerOrigin + Vector3(0, 0, 75), playerOrigin + Vector3(0, 0, 75))
      local visibilityFactor = isVisible and 1 or 0.5
      local factor = fovFactor * visibilityFactor * distanceFactor

      if factor > bestFactor then
         bestTarget = player
         bestFactor = factor
      end

      ::continue::
   end

   if bestTarget then
      -- Projectile weapon
      return CheckProjectileTarget(me, weapon, bestTarget)
   else
      return nil
   end
end

local EMPTY_VECTOR = Vector3() -- Represents an empty vector for zero velocity cases

--- https://www.unknowncheats.me/forum/team-fortress-2-a/273821-canshoot-function.html pasted from one the comments like seriously wtf is this
local lastFire = 0
local nextAttack = 0
local old_weapon = nil
---@param local_player Entity
local function CanShoot(local_player)
   local local_weapon = local_player:GetPropEntity("m_hActiveWeapon")
   if not local_weapon then return false end

   local lastfiretime = local_weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime")

   if lastFire ~= lastfiretime or local_weapon ~= old_weapon then
      lastFire = lastfiretime
      nextAttack = local_weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
   end

   if local_weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then
      return false
   end

   old_weapon = local_weapon

   return nextAttack <= (local_player:GetPropInt("m_nTickBase") * TickInterval())
end

---@param userCmd UserCmd
local function OnCreateMove(userCmd)
   --- check if aimbot is enabled on lbox
   if gui.GetValue("aim bot") == 0 then return end

   if engine.IsChatOpen() or engine.Con_IsVisible() or engine.IsGameUIVisible() then return end
   if not input.IsButtonDown(Menu.Main.AimKey) then
      return
   end

    --- oh no this is horrible
   Menu.Main.AimFov = gui.GetValue("aim fov")
   Menu.Main.AimKey = gui.GetValue("aim key")
   Menu.Main.AutoShoot = gui.GetValue("auto shoot") == 1

   local method = gui.GetValue("aim method (projectile)")
   Menu.Main.pSilent = method == "silent +"
   Menu.Main.Silent = not Menu.Main.pSilent and method == "silent"

   projectileSimulation2 = EMPTY_VECTOR
   local me = WPlayer.GetLocal()
   if not me or not me:IsAlive() then return end
   if not CanShoot(me) then return end

   -- Calculate strafe angles (optional)
   if Menu.Advanced.StrafePrediction then
      CalcStrafe(me)
   end

   local weapon = me:GetActiveWeapon()
   if not weapon then return end

   local netchannel = clientstate.GetNetChannel()
   if not netchannel then return end

   -- Get current latency
   local latIn, latOut = netchannel:GetLatency(E_Flows.FLOW_INCOMING), netchannel:GetLatency(E_Flows.FLOW_OUTGOING)
   latency = (latIn or 0) + (latOut or 0)

   -- Get current lerp
   lerp = GetConVar("cl_interp") or 0

   -- Get the best target
   local currentTarget = GetBestTarget(me, weapon)
   if currentTarget == nil then
      return
   end

   -- Auto Shoot
   if Menu.Main.AutoShoot then
      if weapon:GetWeaponID() == TF_WEAPON_COMPOUND_BOW or weapon:GetWeaponID() == TF_WEAPON_PIPEBOMBLAUNCHER then
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

   if (userCmd.buttons & IN_ATTACK ~= 0) then
      -- Aim at the target
      userCmd:SetViewAngles(currentTarget.angles:Unpack())
      userCmd.sendpacket = not Menu.Main.pSilent

      if not Menu.Main.pSilent and not Menu.Main.Silent then
         engine.SetViewAngles(currentTarget.angles)
      end
   end

   currentTarget = nil
end

local font = draw.CreateFont("Verdana", 12, 400, FONTFLAG_OUTLINE)
draw.SetFont(font)

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
   local w2s_start_pos = WorldToScreen(start_pos)
   local w2s_end_pos = WorldToScreen(end_pos)
   if not (w2s_start_pos and w2s_end_pos) then
      return
   end
   local secondary_line_end_pos = start_pos + perpendicular
   local w2s_secondary_line_end_pos = WorldToScreen(secondary_line_end_pos)
   if w2s_secondary_line_end_pos then
      draw_Line(w2s_start_pos[1], w2s_start_pos[2], w2s_end_pos[1], w2s_end_pos[2])
      draw_Line(w2s_start_pos[1], w2s_start_pos[2], w2s_secondary_line_end_pos[1], w2s_secondary_line_end_pos[2])
   end
end

local hitPos = {}
local function PlayerHurtEvent(event)
   if (event:GetName() == 'player_hurt') and Menu.Visuals.VisualizeHitPos then
      local localPlayer = entities.GetLocalPlayer();
      if not localPlayer then return end
      local victim = entities.GetByUserID(event:GetInt("userid"))
      if not victim then return end
      local attacker = entities.GetByUserID(event:GetInt("attacker"))
      if (attacker == nil or localPlayer:GetIndex() ~= attacker:GetIndex()) then
         return
      end
      table.insert(hitPos, 1, { box = victim:HitboxSurroundingBox(), time = globals.RealTime() })
   end
   if #hitPos > 1 then
      table.remove(hitPos)
   end
end
callbacks.Register("FireGameEvent", "PlayerHurtEvent", PlayerHurtEvent)

local clear_lines = 0

local function OnDraw()
   draw.SetFont(Fonts.Verdana)
   draw.Color(255, 255, 255, 255)

   if not input.IsButtonDown(gui.GetValue("aim key")) then
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

         draw.Color(255 - math_floor((hitChance / 100) * 255), math_floor((hitChance / 100) * 255), 0, 255)

         --draw predicted local position with strafe prediction
         if projectileSimulation2 and projectileSimulation2 ~= EMPTY_VECTOR then
            local screenPos = WorldToScreen(projectileSimulation2)
            if screenPos ~= nil then
               draw_Line(screenPos[1] + 10, screenPos[2], screenPos[1] - 10, screenPos[2])
               draw_Line(screenPos[1], screenPos[2] - 10, screenPos[1], screenPos[2] + 10)
            end
         end

         if Menu.Visuals.VisualizeHitchance or Menu.Visuals.Crosshair or Menu.Visuals.NccPred then
            if i == #vPath - 1 then
               local screenPos1 = WorldToScreen(pos1)
               local screenPos2 = WorldToScreen(pos2)

               if screenPos1 ~= nil and screenPos2 ~= nil then
                  if Menu.Visuals.VisualizeHitchance then
                     ---@diagnostic disable-next-line: param-type-mismatch
                     local width = draw.GetTextSize(math_floor(hitChance))
                     ---@diagnostic disable-next-line: param-type-mismatch
                     draw_Text(screenPos2[1] - math_floor(width / 2), screenPos2[2] + 20, math_floor(hitChance))
                  end
                  if Menu.Visuals.Crosshair then
                     local c_size = 8
                     draw_Line(screenPos2[1] - c_size, screenPos2[2], screenPos2[1] + c_size, screenPos2[2])
                     draw_Line(screenPos2[1], screenPos2[2] - c_size, screenPos2[1], screenPos2[2] + c_size)
                  end
                  if Menu.Visuals.NccPred then
                     local c_size = 5
                     draw_FilledRect(screenPos2[1] - c_size, screenPos2[2] - c_size, screenPos2[1] + c_size,
                        screenPos2[2] + c_size)
                     local w2s = WorldToScreen(startPos)
                     if w2s then
                        draw_Line(w2s[1], w2s[2], screenPos2[1], screenPos2[2])
                     end
                  end
               end
            end
         end

         if Menu.Visuals.VisualizePath then
            if Menu.Visuals.Path_styles_selected == 1 or Menu.Visuals.Path_styles_selected == 3 then
               local screenPos1 = WorldToScreen(pos1)
               local screenPos2 = WorldToScreen(pos2)

               if screenPos1 ~= nil and screenPos2 ~= nil and (not (Menu.Visuals.Path_styles_selected == 3) or i % 2 == 1) then
                  draw_Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
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
                        local screenPos1 = WorldToScreen(pos1)
                        local screenPos2 = WorldToScreen(pos2)

                        if screenPos1 ~= nil and screenPos2 ~= nil and (not (Menu.Visuals.Path_styles_selected == 3) or i % 2 == 1) then
                           draw_Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
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
         for i, v in pairs(hitPos) do
            if globals.RealTime() - v.time > 1 then
               table.remove(hitPos, i)
            else
               draw.Color(255, 255, 255, 255)
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
                  local screenPos = WorldToScreen(vertex)
                  if screenPos ~= nil then
                     screenVertices[j] = { x = screenPos[1], y = screenPos[2] }
                  end
               end
               for j = 1, 4 do
                  local vertex1 = screenVertices[j]
                  local vertex2 = screenVertices[j % 4 + 1]
                  local vertex3 = screenVertices[j + 4]
                  local vertex4 = screenVertices[(j + 4) % 4 + 5]
                  if vertex1 ~= nil and vertex2 ~= nil and vertex3 ~= nil and vertex4 ~= nil then
                     draw_Line(vertex1.x, vertex1.y, vertex2.x, vertex2.y)
                     draw_Line(vertex3.x, vertex3.y, vertex4.x, vertex4.y)
                  end
               end
               for j = 1, 4 do
                  local vertex1 = screenVertices[j]
                  local vertex2 = screenVertices[j + 4]
                  if vertex1 ~= nil and vertex2 ~= nil then
                     draw_Line(vertex1.x, vertex1.y, vertex2.x, vertex2.y)
                  end
               end
            end
         end
      end
   end

   ::continue::

   if gui.IsMenuOpen() and ImMenu.Begin("Custom Projectile Aimbot", true) then -- managing the menu
      ImMenu.BeginFrame(1)                                                 -- tabs
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
         ImMenu.BeginFrame(1)
         Menu.Main.MinHitchance = ImMenu.Slider("Min Hitchance", Menu.Main.MinHitchance, 1, 100)
         ImMenu.EndFrame()
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
         Menu.Advanced.PredTicks = ImMenu.Slider("PredTicks", Menu.Advanced.PredTicks, 1, 200)
         ImMenu.EndFrame()

         ImMenu.BeginFrame(1)
         Menu.Advanced.Hitchance_Accuracy = ImMenu.Slider("Accuracy", Menu.Advanced.Hitchance_Accuracy, 1,
            Menu.Advanced.PredTicks)
         ImMenu.EndFrame()

         ImMenu.BeginFrame(1)
         Menu.Advanced.ProjectileSegments = ImMenu.Slider("projectile Simulation Segments",
            Menu.Advanced.ProjectileSegments, 3, 50)
         ImMenu.EndFrame()
      end

      if Menu.tabs.Visuals then
         ImMenu.BeginFrame(1)
         Menu.Visuals.Active = ImMenu.Checkbox("Enable", Menu.Visuals.Active)
         ImMenu.EndFrame()

         if Menu.Visuals.Active then
            ImMenu.BeginFrame(1)
            Menu.Visuals.VisualizePath = ImMenu.Checkbox("Player Path", Menu.Visuals.VisualizePath)
            Menu.Visuals.VisualizeProjectile = ImMenu.Checkbox("Projectile Simulation",
               Menu.Visuals.VisualizeProjectile)
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
               Menu.Visuals.Path_styles_selected = ImMenu.Option(Menu.Visuals.Path_styles_selected,
                  Menu.Visuals.Path_styles)
               ImMenu.EndFrame()
            end
         end
      end

      ImMenu.End()
   end
end

--[[ Remove the menu when unloaded ]]                      --
local function OnUnload()                                  -- Called when the script is unloaded
   CreateCFG(string.format([[Lua %s]], Lua__fileName), Menu) --saving the config
   UnloadLib()                                            --unloading lualib
   client.Command('play "ui/buttonclickrelease"', true)   -- Play the "buttonclickrelease" sound
end

--[[ Unregister previous callbacks ]] --

callbacks.Unregister("CreateMove", "LNX.Aimbot.CreateMove")
callbacks.Register("CreateMove", "LNX.Aimbot.CreateMove", OnCreateMove)

callbacks.Unregister("Unload", "LNX.Aimbot.OnUnload")
callbacks.Register("Unload", "LNX.Aimbot.OnUnload", OnUnload)

callbacks.Unregister("Draw", "LNX.Aimbot.Draw")
callbacks.Register("Draw", "LNX.Aimbot.Draw", OnDraw)
--[[ Play sound when loaded ]]                --
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded
