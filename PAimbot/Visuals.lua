local G = require("PAimbot.Globals")
local Config = require("PAimbot.Config")
local Common = require("PAimbot.Common")

function Normalize(vec)
    local length = vec:Length()
    return Vector3(vec.x / length, vec.y / length, vec.z / length)
end

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

local function OnDraw()
    -- Check if visuals are enabled
    if not Config.visuals.active or not Config.visuals.visualizePath then
        return
    end

    -- Check if aimbot prediction data exists
    if not G.Aimbot or not G.Aimbot.TargetPredictionPath then
        return
    end

    local posArray = G.Aimbot.TargetPredictionPath
    if not posArray or type(posArray) ~= "table" or #posArray < 2 then
        return
    end

    -- Set drawing properties from config
    draw.Color(Config.visuals.line.r, Config.visuals.line.g, Config.visuals.line.b, Config.visuals.line.a)

    -- Draw prediction path based on selected style
    local selectedStyle = Config.visuals.path_styles_selected or 1

    if selectedStyle == 1 then
        -- Style 1: Simple Line
        for i = 1, #posArray - 1 do
            local pos1 = posArray[i]
            local pos2 = posArray[i + 1]

            if pos1 and pos2 then
                local screenPos1 = client.WorldToScreen(pos1)
                local screenPos2 = client.WorldToScreen(pos2)

                if screenPos1 and screenPos2 then
                    draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
                end
            end
        end
    elseif selectedStyle == 2 then
        -- Style 2: Alt Line (L_line with perpendicular)
        for i = 1, #posArray - 1 do
            local pos1 = posArray[i]
            local pos2 = posArray[i + 1]

            if pos1 and pos2 then
                L_line(pos1, pos2, 10) -- 10 is the secondary line size
            end
        end
    elseif selectedStyle == 3 then
        -- Style 3: Dashed Line
        for i = 1, #posArray - 1 do
            local pos1 = posArray[i]
            local pos2 = posArray[i + 1]

            if pos1 and pos2 then
                local screenPos1 = client.WorldToScreen(pos1)
                local screenPos2 = client.WorldToScreen(pos2)

                if screenPos1 and screenPos2 then
                    -- Only draw every other segment for dashed effect
                    if i % 2 == 1 then
                        draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
                    end
                end
            end
        end
    end

    -- Draw outline if enabled
    if Config.visuals.outline.line_and_flags and selectedStyle ~= 2 then -- L_line already has its own styling
        draw.Color(Config.visuals.outline.r, Config.visuals.outline.g, Config.visuals.outline.b, Config.visuals.outline
            .a)
        for i = 1, #posArray - 1 do
            local pos1 = posArray[i]
            local pos2 = posArray[i + 1]

            if pos1 and pos2 then
                local screenPos1 = client.WorldToScreen(pos1)
                local screenPos2 = client.WorldToScreen(pos2)

                if screenPos1 and screenPos2 then
                    -- Draw outline by offsetting the line slightly
                    draw.Line(screenPos1[1] + 1, screenPos1[2], screenPos2[1] + 1, screenPos2[2])
                    draw.Line(screenPos1[1] - 1, screenPos1[2], screenPos2[1] - 1, screenPos2[2])
                    draw.Line(screenPos1[1], screenPos1[2] + 1, screenPos2[1], screenPos2[2] + 1)
                    draw.Line(screenPos1[1], screenPos1[2] - 1, screenPos2[1], screenPos2[2] - 1)
                end
            end
        end
    end

    -- Draw start and end points if enabled
    if Config.visuals.visualizeHitPos and #posArray > 0 then
        local startPos = posArray[1]
        local endPos = posArray[#posArray]

        -- Draw start point
        local startScreen = client.WorldToScreen(startPos)
        if startScreen then
            draw.Color(0, 255, 0, 255)
            draw.FilledRect(startScreen[1] - 2, startScreen[2] - 2, startScreen[1] + 2, startScreen[2] + 2)
        end

        -- Draw end point
        local endScreen = client.WorldToScreen(endPos)
        if endScreen then
            draw.Color(255, 0, 0, 255)
            draw.FilledRect(endScreen[1] - 2, endScreen[2] - 2, endScreen[1] + 2, endScreen[2] + 2)
        end
    end
end

callbacks.Unregister("Draw", "LNX.Aimbot.Draw")
callbacks.Register("Draw", "LNX.Aimbot.Draw", OnDraw)
