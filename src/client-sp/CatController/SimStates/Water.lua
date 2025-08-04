local Workspace = game:GetService("Workspace")

local STATE_ID = 1

local BaseState = require(script.Parent.BaseState)

local Water = setmetatable({}, BaseState)
Water.__index = Water

function Water.new(...)
    local self = setmetatable(BaseState.new(...) :: BaseState.BaseStateType, Water)

    self.id = STATE_ID

    return self :: BaseState.BaseStateType
end

function Water:stateEnter()

end

function Water:stateLeave()
    
end

function Water:update(dt: number)
    
end

function Water:destroy()

end

return Water