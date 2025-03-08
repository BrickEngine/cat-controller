--!strict

-- Abstract class for defining a simulation controlled state

local Controller = script.Parent.Parent

export type BaseStateType = {
    new: (Model, Vector3) -> BaseStateType,
    stateLeave: (BaseStateType) -> (),
    stateEnter: (BaseStateType) -> (),
    update: (BaseStateType, dt: number, inputController: table) -> number,

    _simulation: any,
}

local BaseState = {} :: BaseStateType
(BaseState :: any).__index = BaseState

function BaseState.new(_simulation)
    local self = setmetatable({} :: BaseStateType, BaseState)

    self._simulation = _simulation

    return self :: BaseStateType
end

function BaseState:stateEnter()
    return false
end

function BaseState:stateLeave()
    return false
end

function BaseState:update(dt: number)
    error("cannot call update of abstract BaseState class", 2)
end

return BaseState