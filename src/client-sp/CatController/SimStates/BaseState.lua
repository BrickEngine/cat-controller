-- Abstract class for defining a simulation controlled state

export type BaseStateType = {
    new: (Model, Vector3) -> BaseStateType,
    stateLeave: (BaseStateType) -> (),
    stateEnter: (BaseStateType) -> (),
    update: (BaseStateType, dt: number) -> ()
}

local BaseState = {} :: BaseStateType
(BaseState :: any).__index = BaseState

function BaseState.new(character, inputVec)
    local self = setmetatable({} :: BaseStateType, BaseState)
    
    self.character = character
    self.inputVec = inputVec
    self.isActive = false

    return self :: any;
end

function BaseState:stateEnter()
    self.isActive = true
end

function BaseState:stateLeave()
    self.isActive = false
end

function BaseState:update(dt: number)
    error("must define update")
    return false
end

return BaseState