-- Abstract class for defining a simulation controlled state

local BaseState = {}
BaseState.__index = BaseState

export type BaseStateType = {
    new: () -> BaseStateType,
    stateLeave: () -> (),
    stateEnter: () -> (),
    update: (dt: number, input: any) -> ()
}

function BaseState.new()
    local self = setmetatable({}, BaseState)
    
    return self;
end

return BaseState