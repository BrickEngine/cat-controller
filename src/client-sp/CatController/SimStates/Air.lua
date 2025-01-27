local Workspace = game:GetService("Workspace")

local BaseState = require(script.Parent.BaseState)

local Air = setmetatable({}, BaseState)
Air.__index = Air

function Air.new(...)
    local self = setmetatable(BaseState.new(...) :: BaseState.BaseStateType, Air)

    return self :: BaseState.BaseStateType
end

function Air:enterState()
    
end

function Air:leaveState()
    
end

function Air:update(dt: number)
    
end

return Air