---@meta

-- Global constants
---@class CONTENTS
CONTENTS_EMPTY = 0

---@class MASK
MASK_SHOT_HULL = 0 

---@class FL
FL_ONGROUND = 1

---@class KEY
KEY_FIRST = 0
KEY_LAST = 0
MOUSE_FIRST = 0
MOUSE_LEFT = 0
MOUSE_RIGHT = 0
MOUSE_MIDDLE = 0

-- Vector3 class definition
---@class Vector3
---@field x number X component of the vector
---@field y number Y component of the vector
---@field z number Z component of the vector
local Vector3 = {}

---Create a new Vector3
---@param x number
---@param y number
---@param z number
---@return Vector3
function Vector3.new(x, y, z) end

---Calculate dot product with another vector
---@param other Vector3
---@return number
function Vector3:Dot(other) end

---Calculate the length (magnitude) of the vector
---@return number
function Vector3:Length() end

---Calculate the squared length of the vector (faster than Length())
---@return number
function Vector3:LengthSqr() end

---Normalize the vector (make it unit length)
---@return Vector3
function Vector3:Normalize() end

---Create a normalized copy of the vector
---@return Vector3
function Vector3:Normalized() end

---Calculate cross product with another vector
---@param other Vector3
---@return Vector3
function Vector3:Cross(other) end

---Linear interpolation between two vectors
---@param other Vector3
---@param t number Interpolation factor (0-1)
---@return Vector3
function Vector3:Lerp(other, t) end

---Calculate distance to another vector
---@param other Vector3
---@return number
function Vector3:DistTo(other) end

---Calculate squared distance to another vector (faster than DistTo)
---@param other Vector3
---@return number
function Vector3:DistToSqr(other) end

---Convert vector to angle
---@return Angle
function Vector3:ToAngle() end

---Convert to string representation
---@return string
function Vector3:__tostring() end

-- Angle class definition
---@class Angle
---@field pitch number Pitch component (up/down)
---@field yaw number Yaw component (left/right)
---@field roll number Roll component (tilt)
local Angle = {}

---Create a new Angle
---@param pitch number
---@param yaw number
---@param roll number
---@return Angle
function Angle.new(pitch, yaw, roll) end

---Convert angle to forward vector
---@return Vector3
function Angle:Forward() end

---Convert angle to right vector
---@return Vector3
function Angle:Right() end

---Convert angle to up vector
---@return Vector3
function Angle:Up() end

-- Client API
---@class client
client = {}

---@param name string
---@return number|nil
function client.GetConVar(name) end

---@param x number
---@param y number
---@param z number
---@return boolean, number, number
function client.WorldToScreen(x, y, z) end

---Get local player entity
---@return Entity
function client.GetLocalPlayer() end

---Get player resource entity
---@return Entity
function client.GetPlayerResources() end

---Get current map name
---@return string
function client.GetMapName() end

---Get current game tick count
---@return number
function client.GetTickCount() end

---Get time since game started
---@return number
function client.GetTime() end

---Get screen dimensions
---@return number width, number height
function client.GetScreenSize() end

-- Engine API
---@class engine
engine = {}

---@param position Vector3
---@return number
function engine.GetPointContents(position) end

---@param startPos Vector3
---@param endPos Vector3
---@param mask number
---@param filter function|nil
---@return table
function engine.TraceLine(startPos, endPos, mask, filter) end

---@param startPos Vector3
---@param endPos Vector3
---@param mins Vector3
---@param maxs Vector3
---@param mask number
---@param filter function|nil
---@return table
function engine.TraceHull(startPos, endPos, mins, maxs, mask, filter) end

---@param soundPath string
function engine.PlaySound(soundPath) end

---Execute a console command
---@param command string
function engine.ExecuteCommand(command) end

---Get view angles
---@return Angle
function engine.GetViewAngles() end

---Set view angles
---@param angles Angle
function engine.SetViewAngles(angles) end

-- Input API
---@class input
input = {}

---@param button number
---@return boolean
function input.IsButtonDown(button) end

---@param button number
---@return boolean
function input.IsButtonPressed(button) end

---@param button number
---@return boolean
function input.IsButtonReleased(button) end

---Get cursor position
---@return number x, number y
function input.GetMousePos() end

-- Draw API
---@class draw
draw = {}

---@param points table
function draw.TexturedPolygon(points) end

---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
function draw.Line(x1, y1, x2, y2) end

---@param r number
---@param g number
---@param b number
---@param a number
function draw.Color(r, g, b, a) end

---Draw a filled rectangle
---@param x number
---@param y number
---@param width number
---@param height number
function draw.FilledRect(x, y, width, height) end

---Draw an outlined rectangle
---@param x number
---@param y number
---@param width number
---@param height number
function draw.OutlinedRect(x, y, width, height) end

---Draw text
---@param x number
---@param y number
---@param text string
function draw.Text(x, y, text) end

---Set text font
---@param font number
function draw.SetFont(font) end

---Create a font
---@param name string
---@param height number
---@param weight number
---@param antialias boolean
---@param additive boolean
---@param italic boolean
---@param outline boolean
---@return number
function draw.CreateFont(name, height, weight, antialias, additive, italic, outline) end

-- Entity API
---@class Entity
local Entity = {}

---@return Vector3
function Entity:GetAbsOrigin() end

---@return Vector3
function Entity:EstimateAbsVelocity() end

---@return string
function Entity:GetClass() end

---@return number
function Entity:GetTeamNumber() end

---@return number
function Entity:GetIndex() end

---@param table string
---@param prop string
---@return number
function Entity:GetPropInt(table, prop) end

---@param table string
---@param prop string
---@return number
function Entity:GetPropFloat(table, prop) end

---@param table string
---@param prop string
---@return boolean
function Entity:GetPropBool(table, prop) end

---@param table string
---@param prop string
---@return string
function Entity:GetPropString(table, prop) end

---@param table string
---@param prop string
---@return Vector3
function Entity:GetPropVector(table, prop) end

---@param table string
---@param prop string
---@return Angle
function Entity:GetPropAngle(table, prop) end

---@return table
function Entity:GetHitboxes() end

---Check if entity is player
---@return boolean
function Entity:IsPlayer() end

---Check if entity is alive
---@return boolean
function Entity:IsAlive() end

---Check if entity is dormant
---@return boolean
function Entity:IsDormant() end

---Get entity health
---@return number
function Entity:GetHealth() end

---Get entity max health
---@return number
function Entity:GetMaxHealth() end

---Get player name
---@return string
function Entity:GetName() end

---Get player active weapon
---@return Entity
function Entity:GetActiveWeapon() end

-- Callbacks API
---@class callbacks
callbacks = {}

---@param event string
---@param id string
---@param callback function
function callbacks.Register(event, id, callback) end

---@param event string
---@param id string
function callbacks.Unregister(event, id) end 