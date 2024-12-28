-- Define the ImpactPolygon class
local ImpactPolygon = {}
ImpactPolygon.__index = ImpactPolygon

local Common = require("Projectile_Visualizer.Common")

-- Constructor for creating a new instance of ImpactPolygon
function ImpactPolygon:new(config)
    local self = setmetatable({}, ImpactPolygon)  -- Set up inheritance from ImpactPolygon
    self.config = config  -- Store the provided configuration
    -- Create a texture used for drawing the polygon, using RGBA values from the configuration
    self.m_iTexture = draw.CreateTextureRGBA(string.char(
        0xff, 0xff, 0xff, config.polygon.a,
        0xff, 0xff, 0xff, config.polygon.a,
        0xff, 0xff, 0xff, config.polygon.a,
        0xff, 0xff, 0xff, config.polygon.a
    ), 2, 2)
    self.iSegments = config.polygon.segments  -- Number of segments to use for the polygon (circle approximation)
    self.fSegmentAngleOffset = math.pi / self.iSegments  -- Calculate the angle offset for each segment
    self.fSegmentAngle = self.fSegmentAngleOffset * 2  -- The full angle of each segment
    return self  -- Return the new instance
end

-- Method to destroy the polygon texture when no longer needed
function ImpactPolygon:destroy()
    if self.m_iTexture then
        draw.DeleteTexture(self.m_iTexture)  -- Delete the texture to free up resources
        self.m_iTexture = nil  -- Set the texture reference to nil
    end
end

-- Reusable function to calculate positions of the polygon vertices
function ImpactPolygon:calculatePositions(plane, origin, radius)
    local positions = {}  -- Table to store the calculated positions

    -- Handle the case where the plane is almost perfectly horizontal (z-axis aligned)
    if math.abs(plane.z) >= 0.99 then
        for i = 1, self.iSegments do
            local ang = i * self.fSegmentAngle + self.fSegmentAngleOffset  -- Calculate the angle for this segment
            -- Calculate the world position and convert it to screen space
            positions[i] = Common.WORLD2SCREEN(origin + Vector3(radius * math.cos(ang), radius * math.sin(ang), 0))
            if not positions[i] then return nil end  -- Return nil if the position could not be calculated
        end
    else
        -- For non-horizontal planes, calculate the right and up vectors
        local right = Vector3(-plane.y, plane.x, 0)
        local up = Vector3(plane.z * right.y, -plane.z * right.x, (plane.y * right.x) - (plane.x * right.y))
        radius = radius / math.cos(math.asin(plane.z))  -- Adjust the radius based on the plane's tilt

        for i = 1, self.iSegments do
            local ang = i * self.fSegmentAngle + self.fSegmentAngleOffset  -- Calculate the angle for this segment
            -- Calculate the world position using the right and up vectors, then convert it to screen space
            positions[i] = Common.WORLD2SCREEN(origin + (right * (radius * math.cos(ang))) + (up * (radius * math.sin(ang))))
            if not positions[i] then return nil end  -- Return nil if the position could not be calculated
        end
    end

    return positions  -- Return the calculated positions
end

-- Reusable function to draw the outline of the polygon
function ImpactPolygon:drawOutline(positions)
    local last = positions[#positions]  -- Start with the last position in the list
    -- Set the outline color from the configuration
    Common.COLOR(self.config.outline.r, self.config.outline.g, self.config.outline.b, self.config.outline.a)

    -- Loop through each position and draw a line to the next position
    for i = 1, #positions do
        local new = positions[i]
        -- Determine whether to draw the outline horizontally or vertically based on the difference in coordinates
        if math.abs(new[1] - last[1]) > math.abs(new[2] - last[2]) then
            Common.LINE(last[1], last[2] + 1, new[1], new[2] + 1)
            Common.LINE(last[1], last[2] - 1, new[1], new[2] - 1)
        else
            Common.LINE(last[1] + 1, last[2], new[1] + 1, new[2])
            Common.LINE(last[1] - 1, last[2], new[1] - 1, new[2])
        end
        last = new  -- Update the last position for the next iteration
    end
end

-- Reusable function to draw the polygon itself
function ImpactPolygon:drawPolygon(positions)
    -- Ensure that the polygon configuration is available
    if not self.config or not self.config.polygon then
        error("Configuration for polygon drawing is missing or invalid")
        return
    end

    -- Set the color for the polygon fill based on the configuration
    Common.COLOR(self.config.polygon.r, self.config.polygon.g, self.config.polygon.b, 255)

    local cords, reverse_cords = {}, {}  -- Tables to store the polygon coordinates and their reverse order
    local sizeof = #positions  -- Number of positions (vertices) in the polygon
    local sum = 0  -- Sum used to determine the winding order of the polygon

    -- Loop through each position to prepare the coordinates and calculate the winding order
    for i, pos in pairs(positions) do
        local convertedTbl = {pos[1], pos[2], 0, 0}  -- Convert the position to a table format
        cords[i], reverse_cords[sizeof - i + 1] = convertedTbl, convertedTbl  -- Store in both forward and reverse order
        -- Ensure that the positions table is valid before accessing it
        local nextPos = positions[(i % sizeof) + 1]
        if not nextPos then
            error("Invalid position in positions table")
            return
        end
        sum = sum + Common.CROSS(pos, nextPos, positions[1])  -- Calculate the cross product to determine winding order
    end

    -- Draw the polygon using the calculated coordinates
    Common.POLYGON(self.m_iTexture, (sum < 0) and reverse_cords or cords, true)

    -- Draw the final outline around the polygon
    local last = positions[#positions]  -- Start with the last position in the list
    for i = 1, #positions do
        local new = positions[i]
        if not last or not new then
            error("Invalid position detected during final outline drawing")
            return
        end
        Common.LINE(last[1], last[2], new[1], new[2])  -- Draw the line between the last and new positions
        last = new  -- Update the last position for the next iteration
    end
end

-- Main function to draw the impact polygon based on the plane and origin
function ImpactPolygon:drawImpactPolygon(plane, origin)
    if not self.config.polygon.enabled then return end  -- Check if polygon drawing is enabled in the config

    local positions = self:calculatePositions(plane, origin, self.config.polygon.size)  -- Calculate the polygon positions
    if not positions then return end  -- If positions could not be calculated, exit early

    if self.config.outline.polygon then  -- If the outline is enabled in the config, draw the outline
        self:drawOutline(positions)
    end

    self:drawPolygon(positions)  -- Draw the polygon itself
end

-- Metatable to allow the ImpactPolygon instance to be called like a function
setmetatable(ImpactPolygon, {
    __call = function(self, plane, origin)
        self:drawImpactPolygon(plane, origin)  -- Call the drawImpactPolygon method when the instance is invoked
    end
})

return ImpactPolygon