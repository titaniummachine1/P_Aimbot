local G = require("PAimbot.Globals")
local Common = require("PAimbot.Common")

local function L_line(start_pos, end_pos, secondary_line_size)
    if not (start_pos and end_pos) then
        return
    end
    local direction = end_pos - start_pos
    local direction_length = direction:Length()
    if direction_length == 0 then
        return
    end
    local normalized_direction = Common.Normalize(direction)
    local perpendicular = Vector3(normalized_direction.y, -normalized_direction.x, 0) * secondary_line_size
    local w2s_start_pos = Common.WORLD2SCREEN(start_pos)
    local w2s_end_pos = Common.WORLD2SCREEN(end_pos)
    if not (w2s_start_pos and w2s_end_pos) then
        return
    end
    local secondary_line_end_pos = start_pos + perpendicular
    local w2s_secondary_line_end_pos = Common.WORLD2SCREEN(secondary_line_end_pos)
    if w2s_secondary_line_end_pos then
        Common.LINE(w2s_start_pos[1], w2s_start_pos[2], w2s_end_pos[1], w2s_end_pos[2])
        Common.LINE(w2s_start_pos[1], w2s_start_pos[2], w2s_secondary_line_end_pos[1], w2s_secondary_line_end_pos[2])
    end
end

local function OnDraw()
    if not G.PredictionData or not G.PredictionData.PredPath then
        return
    end
    draw.Color(255,255,255,255)
    draw.SetFont(Common.Fonts.Verdana)
    local vPath = G.PredictionData.PredPath.pos

    if not vPath then return end

    for i = 1, #vPath - 1 do
        local pos1 = vPath[i]
        local pos2 = vPath[i + 1]

        if pos1 and pos2 then
            if G.Menu.Visuals.Path_styles_selected == 1 or G.Menu.Visuals.Path_styles_selected == 3 then
                local screenPos1 = Common.WORLD2SCREEN(pos1)
                local screenPos2 = Common.WORLD2SCREEN(pos2)

                if screenPos1 and screenPos2 and (G.Menu.Visuals.Path_styles_selected ~= 3 or i % 2 == 1) then
                    Common.LINE(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
                end
            elseif G.Menu.Visuals.Path_styles_selected == 2 then
                L_line(pos1, pos2, 10)
            end
        end
    end
end

callbacks.Unregister("Draw", "LNX.Aimbot.Draw")
callbacks.Register("Draw", "LNX.Aimbot.Draw", OnDraw)