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

function Ground:stateEnter()
    print("I AM ENTERING THE STOOD HEHEHE")
end

function Ground:stateLeave()
    
end

function Ground:update(dt: number)
    print("player is on ground hehehaha")
end

return Ground