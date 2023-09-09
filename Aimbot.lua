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
        AimKey = MOUSE_4,
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
        Path_styles_selected = 2,
        VisualizeHitchance = true,
        VisualizeProjectile = false,
        VisualizeHitPos = false,
    },
}

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

if UnloadLib then UnloadLib() end

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
local shouldHitEntity = function (e, _) return false end

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
local NORMAL_TRACE_HULL_SIZE = 4  -- Normal hitbox size for projectiles
local LARGE_TRACE_HULL_SIZE = 40  -- Large hitbox size for initial check on ballistic missiles

-- Calculates the angle needed to hit a target with a projectile
---@param origin Vector3
---@param dest Vector3
---@param speed number
---@param gravity number
---@param sv_gravity number
---@return { angles: EulerAngles, time : number }?
local function SolveProjectile(origin, dest, speed, gravity, sv_gravity, target)
    local v = dest - origin
    local v0 = speed
    local v0_squared = v0 * v0  -- Calculate v0^2 once to avoid repeated calculations
    local g = sv_gravity * gravity

    local normalHitbox = { Vector3(-NORMAL_TRACE_HULL_SIZE, -NORMAL_TRACE_HULL_SIZE, -NORMAL_TRACE_HULL_SIZE), Vector3(NORMAL_TRACE_HULL_SIZE, NORMAL_TRACE_HULL_SIZE, NORMAL_TRACE_HULL_SIZE) }
    local largeHitbox = { Vector3(-LARGE_TRACE_HULL_SIZE, -LARGE_TRACE_HULL_SIZE, -LARGE_TRACE_HULL_SIZE), Vector3(LARGE_TRACE_HULL_SIZE, LARGE_TRACE_HULL_SIZE, LARGE_TRACE_HULL_SIZE) }
    local trace = engine.TraceHull(origin, dest, normalHitbox[1], normalHitbox[2], MASK_PLAYERSOLID)

    if g == 0 then
        if trace.entity == target and trace.endpos == dest then
            return nil
        end
        if not Helpers.VisPos(target:Unwrap(), origin, dest) then return nil end
        return { angles = Math.PositionAngles(origin, dest), time = v:Length() / v0 }
    else
        trace = engine.TraceHull(origin, dest, largeHitbox[1], largeHitbox[2], MASK_PLAYERSOLID)
        if not trace.entity == target and trace.endpos == dest then
            local dx = v:Length2D()
            local dy = v.z
            local g_dx = g * dx
            local root_part = g * (g_dx * dx + 2 * dy * v0_squared)
            local root = v0_squared * v0_squared - root_part

            if root < 0 then return nil end

            local pitch = math.atan((v0_squared - math.sqrt(root)) / g_dx)
            local yaw = math.atan(v.y, v.x)

            if pitch ~= pitch or yaw ~= yaw then return nil end

            local timeToTarget = dx / (math.cos(pitch) * v0)
            local tickInterval = globals.TickInterval()
            local numTicks = math.floor(timeToTarget / tickInterval)
            local pos = origin

            for i = 1, numTicks do
                local t = i * tickInterval
                local x = v0 * math.cos(pitch) * t
                local y = v0 * math.sin(pitch) * t - 0.5 * g * t * t
                local newPos = origin + Vector3(x * math.cos(yaw), x * math.sin(yaw), y)

                trace = engine.TraceHull(pos, newPos, normalHitbox[1], normalHitbox[2], MASK_PLAYERSOLID)
                if not trace.entity == target and trace.endpos == dest then
                    return nil
                end

                pos = newPos
            end

            return { angles = EulerAngles(pitch * -M_RADPI, yaw * M_RADPI), time = timeToTarget }
        else
            local dx = v:Length2D()
            local dy = v.z
            local g_dx = g * dx
            local root_part = g * (g_dx * dx + 2 * dy * v0_squared)
            local root = v0_squared * v0_squared - root_part

            if root < 0 then return nil end

            local pitch = math.atan((v0_squared - math.sqrt(root)) / g_dx)
            local yaw = math.atan(v.y, v.x)

            if pitch ~= pitch or yaw ~= yaw then return nil end

            local timeToTarget = dx / (math.cos(pitch) * v0)
            return { angles = EulerAngles(pitch * -M_RADPI, yaw * M_RADPI), time = timeToTarget }
        end
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

        local solution = SolveProjectile(shootPos, pos, projInfo[1], projInfo[2], gravity, player)
        if not solution then goto continue end

        fov = Math.AngleFov(solution.angles, engine.GetViewAngles())
        if fov > Menu.Main.AimFov then goto continue end

        local time = solution.time + latency + lerp
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
            return --CheckHitscanTarget(me, weapon, player)
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
    if not input.IsButtonDown(Menu.Main.AimKey) then
        return
    end

    local me = WPlayer.GetLocal()
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

local function CreateCFG(folder_name, table)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.txt")
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
        printc( 255, 183, 0, 255, "["..os.date("%H:%M:%S").."] Saved to ".. tostring(fullPath))
    end
end

local function LoadCFG(folder_name)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.txt")
    local file = io.open(filepath, "r")
    
    if file then
        local content = file:read("*a")
        file:close()
        local chunk, err = load("return " .. content)
        if chunk then
            printc( 0, 255, 140, 255, "["..os.date("%H:%M:%S").."] Loaded from ".. tostring(fullPath))
            return chunk()
        else
            print("Error loading configuration:", err)
        end
    end
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

    -- Draw lines between the predicted positions
    if Menu.Visuals.VisualizePath and vPath then
        draw.SetFont(font)
        for i = 1, #vPath - 1 do
            local pos1 = vPath[i]
            local pos2 = vPath[i + 1]
            
            draw.Color(255 - math.floor((hitChance / 100) * 255), math.floor((hitChance / 100) * 255), 0, 255)
            
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

            if Menu.Visuals.VisualizeHitchance then 
                if i == #vPath - 1 then 
                    local screenPos1 = client.WorldToScreen(pos1)
                    local screenPos2 = client.WorldToScreen(pos2)
        
                    if screenPos1 ~= nil and screenPos2 ~= nil then
                        local width = draw.GetTextSize(math.floor(hitChance))
                        --draw.Text(screenPos2[1] - math.floor(width / 2), screenPos2[2], math.floor(hitChance))
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
        if not me or not me:IsAlive() then return end

        local weapon = me:GetActiveWeapon()
        if not weapon then return end

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
            ImMenu.Text("The menu key is INSERT and the aim key is MOUSE4")
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



            --[[ImMenu.BeginFrame(1)
            ImMenu.Text("Aim Mode")
            Menu.Advanced.Aim_Modes.projectiles = ImMenu.Option(Menu.Advanced.Aim_Modes.projectiles, AimModes)
            ImMenu.EndFrame()]]
        end

        if Menu.tabs.Visuals then 
            ImMenu.BeginFrame(1)
            Menu.Visuals.VisualizePath = ImMenu.Checkbox("Visualize Path", Menu.Visuals.VisualizePath)
            ImMenu.EndFrame()

            if Menu.Visuals.VisualizePath then 
                ImMenu.BeginFrame(1)
                Menu.Visuals.VisualizeHitchance = ImMenu.Checkbox("Visualize Hitchance", Menu.Visuals.VisualizeHitchance)
                ImMenu.EndFrame()
                ImMenu.BeginFrame(1)
                Menu.Visuals.Path_styles_selected = ImMenu.Option(Menu.Visuals.Path_styles_selected, Menu.Visuals.Path_styles)
                ImMenu.EndFrame()
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

callbacks.Unregister("CreateMove", "LNX.Aimbot.CreateMove")
callbacks.Register("CreateMove", "LNX.Aimbot.CreateMove", OnCreateMove)

callbacks.Unregister("Draw", "LNX.Aimbot.Draw")
callbacks.Register("Draw", "LNX.Aimbot.Draw", OnDraw)