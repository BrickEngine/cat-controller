-- Abstract class for defining a simulation controlled state

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerStateId = require(ReplicatedStorage.Shared.Enums.PlayerStateId)

local BaseState = {}
BaseState.__index = BaseState

export type BaseState = typeof(setmetatable({}, BaseState))

function BaseState.new(_simulation)
    local self = setmetatable({} :: any, BaseState) :: BaseState

    self._simulation = _simulation
    self.id = PlayerStateId.NONE

    self.grounded = false
    self.inWater = false
    self.normal = Vector3.fromAxis(Enum.Axis.Y)

    return self
end

function BaseState:stateEnter(params: any?)
end

function BaseState:stateLeave()
end

function BaseState:stun(impulse: Vector3)
end

function BaseState:update(dt: number)
    error("cannot call update of abstract BaseState", 2)
end
 
function BaseState:destroy()
    error("cannot call destroy of abstract BaseState", 2)
end

return BaseState