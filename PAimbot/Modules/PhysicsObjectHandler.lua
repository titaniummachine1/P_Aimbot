-- PhysicsObjectHandlerModule.lua

-- Define a handler for managing physics objects
local PhysicsObjectHandler = {}

-- Initialize the object list and the active object index
PhysicsObjectHandler.m_aObjects = {}  -- List to store all the physics objects
PhysicsObjectHandler.m_iActiveObject = 0  -- Index of the currently active object

-- Function to initialize and load physics objects
function PhysicsObjectHandler:Initialize(PhysicsEnvironment)
    -- Avoid reinitializing if objects are already loaded
    if #self.m_aObjects > 0 then return end

    -- Helper function to load a new physics object from a model path
    local function loadObject(path)
        -- Parse the model by name to get its solid and model information
        local solid, model = physics.ParseModelByName(path)

        -- Create a new poly object in the physics environment using the model's parameters
        local newObject = PhysicsEnvironment:CreatePolyObject(
            model,  -- The model of the object
            solid:GetSurfacePropName(),  -- The surface properties of the object
            solid:GetObjectParameters()  -- The physical parameters of the object
        )

        -- Insert the new object into the object list
        table.insert(self.m_aObjects, newObject)
    end

    -- Load the necessary physics objects based on their model paths
    loadObject("models/weapons/w_models/w_stickybomb.mdl")  -- Stickybomb
    loadObject("models/workshop/weapons/c_models/c_kingmaker_sticky/w_kingmaker_stickybomb.mdl")  -- QuickieBomb
    loadObject("models/weapons/w_models/w_stickybomb_d.mdl")  -- ScottishResistance, StickyJumper

    -- Wake the first object to set it as the active object
    if #self.m_aObjects > 0 then
        self.m_aObjects[1]:Wake()  -- Wake up the first physics object to make it active
        self.m_iActiveObject = 1  -- Set the active object index to 1
    end
end

-- Function to destroy all loaded physics objects
function PhysicsObjectHandler:Destroy(PhysicsEnvironment)
    self.m_iActiveObject = 0  -- Reset the active object index

    -- If there are no objects loaded, there's nothing to destroy
    if #self.m_aObjects == 0 then return end

    -- Loop through each loaded object
    for i, obj in pairs(self.m_aObjects) do
        -- Destroy the object within the physics environment
        PhysicsEnvironment:DestroyObject(obj)
        self.m_aObjects[i] = nil  -- Clear the reference to the destroyed object
    end
end

-- Metatable for PhysicsObjectHandler to allow it to be called like a function
setmetatable(PhysicsObjectHandler, {
    __call = function(self, iRequestedObject)
        -- If the requested object is not the currently active one, switch the active object
        if iRequestedObject ~= self.m_iActiveObject then
            self.m_aObjects[self.m_iActiveObject]:Sleep()  -- Put the current active object to sleep
            self.m_aObjects[iRequestedObject]:Wake()  -- Wake up the requested object to make it active
            self.m_iActiveObject = iRequestedObject  -- Update the active object index
        end

        -- Return the currently active object
        return self.m_aObjects[self.m_iActiveObject]
    end
})

-- Return the module table
return PhysicsObjectHandler