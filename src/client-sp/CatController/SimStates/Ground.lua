local Workspace = game:GetService("Workspace")

local BaseState = require(script.Parent.BaseState)

local Ground = setmetatable({}, BaseState)
Ground.__index = Ground

function Ground.new(stateMachine)
    local self = setmetatable(BaseState.new(stateMachine) :: BaseState.BaseStateType, Ground)
    
    self.stateMachine = stateMachine
    self.physCheck = nil

    return self :: BaseState.BaseStateType
end

function Ground:enterState()

end

function Ground:leaveState()
    
end

function Ground:update(dt: number)
    
end

return Ground