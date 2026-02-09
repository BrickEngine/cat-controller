local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateId = require(ReplicatedStorage.Shared.Enums.PlayerStateId)

local controller = script.Parent.Parent
local BaseState = require(controller.SimStates.BaseState)
---------------------------------------------------------------------------------------

local Water = setmetatable({}, BaseState)
Water.__index = Water

function Water.new(...)
    local self = BaseState.new(...) :: BaseState.BaseState

    self.id = PlayerStateId.IN_WATER

    return setmetatable(self, Water)
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