local Workspace = game:GetService("Workspace")

local BaseState = require(script.Parent.BaseState)

local Water = setmetatable({}, BaseState)
Water.__index = Water

function Water.new(character: Model, inputVec: Vector3)
    local self = setmetatable(BaseState.new(character) :: BaseState.BaseStateType, Water)
    
    self.character = character
    self.inputVec = inputVec

    return self :: BaseState.BaseStateType
end

function Water:enterState()
    
end

function Water:leaveState()
    
end

function Water:update(dt: number)
    
end