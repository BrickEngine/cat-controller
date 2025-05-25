--!strict

local Workspace = game:GetService("Workspace")

local BaseState = require(script.Parent.BaseState)

local Air = setmetatable({}, BaseState)
Air.__index = Air

function Air.new(...)
    local self = setmetatable(BaseState.new(...) :: BaseState.BaseStateType, Air)

    return self :: BaseState.BaseStateType
end

function Air:enterState()
    return
end

function Air:leaveState()
    return
end

function Air:update(dt: number)
    
end

function Air:destroy()

end

return Air