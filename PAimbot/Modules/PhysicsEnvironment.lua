-- PhysicsEnvironmentModule.lua
-- This is a Lua module for managing the physics environment.

local PhysicsEnvironmentModule = {}
PhysicsEnvironmentModule.__index = PhysicsEnvironmentModule

-- Function to initialize the physics environment
function PhysicsEnvironmentModule:Initialize()
    -- Create the physics environment
    self.environment = physics.CreateEnvironment()

    -- Set the gravity in the physics environment using the server's gravity setting
    self.environment:SetGravity(Vector3(0, 0, -client.GetConVar("sv_gravity")))

    -- Set the air density to simulate air resistance
    self.environment:SetAirDensity(2.0)

    -- Set the simulation timestep to match the game's tick interval
    self.environment:SetSimulationTimestep(globals.TickInterval())
end

-- Function to get the physics environment (useful if you need to interact with it directly)
function PhysicsEnvironmentModule:GetEnvironment()
    return self.environment
end

-- Export the PhysicsEnvironmentModule as a module
return PhysicsEnvironmentModule
