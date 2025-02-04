local simStates = script.Parent.SimStates

local BaseState = require(simStates.BaseState)
local BaseMoveInput = require(script.Parent.BaseMoveInput)

local Ground = require(simStates.Ground) :: BaseState.BaseStateType
local Water = require(simStates.Water) :: BaseState.BaseStateType
local Air = require(simStates.Air) :: BaseState.BaseStateType

export type StateMachineType = {
    transitionState: (StateMachineType) -> (),
    getCurrentState: (StateMachineType) -> (BaseState.BaseStateType),
    resetRefs: (StateMachineType, Model) -> (),
    update: (StateMachineType, dt: number) -> (),

    input: BaseMoveInput.BaseMoveInputType,
    character: Model,
    currentState: BaseState.BaseStateType,
    states: {[any]: BaseState.BaseStateType}
}

local Statemachine = {}
Statemachine.__index = Statemachine

function Statemachine.new(character: Model, inpModule: BaseMoveInput.BaseMoveInputType)
    local self = setmetatable({} :: StateMachineType, Statemachine)

    self.input = inpModule
    self.character = character
    self.currentState = Ground
    self.states = {
        Ground = Ground.new(Statemachine),
        Water = Water.new(Statemachine),
        Air = Air.new(Statemachine)
    }

    self.currentState:stateEnter()

    return self
end

function Statemachine:reset()
    if (self.currentState) then
        self.currentState:stateLeave()
    end

    self.currentState = Ground
    self.currentState:stateEnter()
end

function Statemachine:transitionState(newState: BaseState.BaseStateType)
    if (not newState) then
        error("no state to transition to")
    end

    self.currentState:leaveState()
    self.currentState = newState
    self.currentState:stateEnter()
end

function Statemachine:getCurrentState()
    return self.currentState
end

function Statemachine:resetRefs(character: Model)
    self.character = character
end

function Statemachine:update(dt: number)
    if (self.character and self.currentState.update) then
        self.currentState:update(dt)
    end
end

return Statemachine