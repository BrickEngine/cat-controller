local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateId = require(ReplicatedStorage.Shared.Enums.PlayerStateId)

local BaseState = require(script.Parent.BaseState)

local Air = setmetatable({}, BaseState)
Air.__index = Air

function Air.new(...)
    local self = BaseState.new(...) :: BaseState.BaseState
    self.id = PlayerStateId.NONE

    return setmetatable(self, Air)
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