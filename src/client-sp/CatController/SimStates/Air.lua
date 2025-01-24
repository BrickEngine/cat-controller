local Workspace = game:GetService("Workspace")

local BaseState = require(script.Parent.BaseState)

local Air = setmetatable({}, BaseState)
Air.__index = Air

function Air.new(character: Model, inputVec: Vector3)
    local self = setmetatable(BaseState.new(character) :: BaseState.BaseStateType, Air)
    
    self.character = character
    self.inputVec = inputVec

    return self :: BaseState.BaseStateType
end

function Air:enterState()
    
end

function Air:leaveState()
    
end

function Air:update(dt: number)
    
end