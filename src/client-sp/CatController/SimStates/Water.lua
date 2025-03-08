--!strict

local Workspace = game:GetService("Workspace")

local BaseState = require(script.Parent.BaseState)

local Water = setmetatable({}, BaseState)
Water.__index = Water

function Water.new(...)
    local self = setmetatable(BaseState.new(...) :: BaseState.BaseStateType, Water)

    return self :: BaseState.BaseStateType
end

function Water:stateEnter()

end

function Water:stateLeave()
    
end

function Water:update(dt: number)
    
end

return Water