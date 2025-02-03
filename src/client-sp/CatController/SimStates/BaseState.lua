-- Abstract class for defining a simulation controlled state

export type BaseStateType = {
    new: (Model, Vector3) -> BaseStateType,
    stateLeave: (BaseStateType) -> (),
    stateEnter: (BaseStateType) -> (),
    update: (BaseStateType, dt: number) -> (),

    stateMachine: any
}

local BaseState = {} :: BaseStateType
(BaseState :: any).__index = BaseState

function BaseState.new(stateMachine)
    local self = setmetatable({} :: BaseStateType, BaseState)
    
    self._stateMachine = stateMachine

    return self :: any;
end

function BaseState:stateEnter()
    return false
end

function BaseState:stateLeave()
    return false
end

function BaseState:update(dt: number)
    return false
end

return BaseState