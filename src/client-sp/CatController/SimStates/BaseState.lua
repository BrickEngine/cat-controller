-- Abstract class for defining a simulation controlled state

local Controller = script.Parent.Parent

export type BaseStateType = {
    new: (Model, Vector3) -> BaseStateType,
    stateLeave: (BaseStateType) -> (),
    stateEnter: (BaseStateType) -> (),
    update: (BaseStateType, dt: number) -> (),

    _stateMachine: any,
}

local BaseState = {} :: BaseStateType
(BaseState :: any).__index = BaseState

function BaseState.new(_stateMachine)
    local self = setmetatable({} :: BaseStateType, BaseState)
    
    self._stateMachine = _stateMachine

    return self :: BaseStateType;
end

function BaseState:stateEnter(oldState: BaseStateType)
    return false
end

function BaseState:stateLeave()
    return false
end

function BaseState:update(dt: number)
    error("cannot call update of abstract BaseState class", 2)
end

return BaseState