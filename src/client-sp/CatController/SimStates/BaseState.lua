--!strict

-- Abstract class for defining a simulation controlled state

local Controller = script.Parent.Parent

export type SimulationType = {
    transitionState: (newState: BaseStateType) -> (),

    states: {[string]: BaseStateType},
    currentstate: BaseStateType,

    [string]: any
}

export type BaseStateType = {
    new: (_simulation: SimulationType) -> BaseStateType,
    stateLeave: (BaseStateType) -> (),
    stateEnter: (BaseStateType) -> (),
    update: (BaseStateType, dt: number) -> (),
    destroy: (BaseStateType) -> (),

    _simulation: SimulationType,
    id: number,

    [string]: any
}

local BaseState = {}
BaseState.__index = BaseState

function BaseState.new(_simulation)
    local self = setmetatable({}, BaseState) :: BaseStateType

    self._simulation = _simulation
    self.id = -1

    return self
end

function BaseState:stateEnter()
    return false
end

function BaseState:stateLeave()
    return false
end

function BaseState:update(dt: number)
    error("cannot call update of abstract BaseState", 2)
end

function BaseState:destroy()
    error("cannot call destroy of abstract BaseState", 2)
end

return BaseState