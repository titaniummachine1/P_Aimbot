-- TrajectoryLine.lua
-- This is a Lua module for handling the drawing and management of trajectory lines.

local TrajectoryLine = {}
TrajectoryLine.__index = TrajectoryLine

local Common = require("Projectile_Visualizer.Common")

-- Constructor for creating a new instance of TrajectoryLine
function TrajectoryLine:new()
    self = setmetatable({}, TrajectoryLine)  -- Set up inheritance from TrajectoryLine
    self.positions = {}                            -- Stores the positions along the trajectory
    self.size = 0                                  -- Tracks the number of positions
    self.flagOffset = Vector3(0, 0, 0)             -- Offset for rendering flags along the trajectory
    return self                                    -- Return the new instance
end

-- Method to insert a new position into the trajectory
function TrajectoryLine:Insert(vec)
    self.size = self.size + 1          -- Increment the size to keep track of the number of positions
    self.positions[self.size] = vec    -- Store the position vector in the positions table
end

-- Method to clear the trajectory data
function TrajectoryLine:Clear()
    self.positions = {}  -- Reset the positions table to an empty state
    self.size = 0        -- Reset the size counter to zero
end

-- Helper function to calculate the outline offset based on flag size
local function CalculateOutlineOffset(flagSize)
    return {
        inner = (flagSize < 1) and -1 or 0,  -- Offset for inner outline depending on flag size
        outer = (flagSize < 1) and -1 or 1   -- Offset for outer outline depending on flag size
    }
end

-- Function to draw the outline of a line
local function DrawOutline(last, new, outlineColor)
    -- Set the color for the outline
    G.COLOR(outlineColor.r, outlineColor.g, outlineColor.b, outlineColor.a)

    -- Determine the direction to draw the outline based on the difference in coordinates
    if math.abs(last[1] - new[1]) > math.abs(last[2] - new[2]) then
        -- If horizontal difference is greater, draw horizontal outline
        Common.LINE(last[1], last[2] - 1, new[1], new[2] - 1)
        Common.LINE(last[1], last[2] + 1, new[1], new[2] + 1)
    else
        -- If vertical difference is greater, draw vertical outline
        Common.LINE(last[1] - 1, last[2], new[1] - 1, new[2])
        Common.LINE(last[1] + 1, last[2], new[1] + 1, new[2])
    end
end

-- Function to draw a line with an optional outline
local function DrawLineWithOptionalOutline(last, new, lineColor, outlineColor)
    -- Draw the outline if the outline color is specified
    if outlineColor then
        DrawOutline(last, new, outlineColor)
    end
    -- Set the color for the line
    Common.COLOR(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
    -- Draw the line between the last and new positions
    Common.LINE(last[1], last[2], new[1], new[2])
end

-- Method to render the trajectory based on the current configuration
function TrajectoryLine:Render(config)
    local lastScreenPos = nil  -- Variable to keep track of the last screen position
    local outlineOffset = CalculateOutlineOffset(config.flags.size)  -- Calculate the outline offsets

    -- Loop through the positions in reverse order to render the trajectory
    for i = self.size, 1, -1 do
        local worldPos = self.positions[i]              -- Get the current world position
        local screenPos = Common.WORLD2SCREEN(worldPos)        -- Convert the world position to screen coordinates
        local flagScreenPos = Common.WORLD2SCREEN(worldPos + self.flagOffset)  -- Apply the flag offset and convert to screen coordinates

        if lastScreenPos then
            -- Draw the line and flags with optional outlines based on the configuration
            if config.line.enabled then
                DrawLineWithOptionalOutline(lastScreenPos, screenPos, config.line, config.outline.line_and_flags and config.outline, outlineOffset.inner)
            end
            if config.flags.enabled then
                DrawLineWithOptionalOutline(flagScreenPos, screenPos, config.flags, config.outline.flags and config.outline, outlineOffset.outer)
            end
        end

        lastScreenPos = screenPos  -- Update the last screen position for the next iteration
    end
end

-- Utility function to setup and return color configurations
local function SetupColors(config)
    return {
        lineColor = {r = config.line.r, g = config.line.g, b = config.line.b, a = config.line.a},  -- Line color settings
        flagColor = {r = config.flags.r, g = config.flags.g, b = config.flags.b, a = config.flags.a},  -- Flag color settings
        outlineColor = {r = config.outline.r, g = config.outline.g, b = config.outline.b, a = config.outline.a}  -- Outline color settings
    }
end

SetupColors(G.Menu)  -- Set up color configurations for use in drawing

-- Export the TrajectoryLine class as a module
return TrajectoryLine