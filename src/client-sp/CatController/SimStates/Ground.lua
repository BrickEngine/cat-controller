local Workspace = game:GetService("Workspace")

local BaseState = require(script.Parent.BaseState)

local Ground = setmetatable({}, BaseState)
Ground.__index = Ground

function Ground.new(character: Model, inputVec: Vector3)
    local self = setmetatable(BaseState.new(character) :: BaseState.BaseStateType, Ground)
    
    self.character = character
    self.inputVec = inputVec

    return self :: BaseState.BaseStateType
end

function Ground:enterState()
    
end

function Ground:leaveState()
    
end

function Ground:update(dt: number)
    
end