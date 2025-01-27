local simStates = script.Parent.SimStates

local BaseState = require(simStates.BaseState)
local Ground = require(simStates.Ground) :: BaseState.BaseStateType
local Water = require(simStates.Water) :: BaseState.BaseStateType
local Air = require(simStates.Air) :: BaseState.BaseStateType

export type StateMachineType = {
    transitionState: (StateMachineType) -> (),
    getCurrentState: (StateMachineType) -> (BaseState.BaseStateType),
    resetRefs: (StateMachineType, Model) -> (),
    update: (StateMachineType, dt: number) -> (),

    character: Model,
    input: any,
    states: {[any]: BaseState.BaseStateType},
    currentState: BaseState.BaseStateType
}

local Statemachine = {}
Statemachine.__index = Statemachine

function Statemachine.new(character: Model, input: any)
    local self = setmetatable({} :: StateMachineType, Statemachine)

    self.character = character
    self.input = input
    self.states = {
        Ground = Ground.new(self),
        --Water = Water.new(self),
        --Air = Air.new(self)
    }
    self.currentState = Ground

    self.currentState:stateEnter()

    return self
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
    if (not self.character) then
        warn("no ref to character") return
    end

    self.currentState:update(dt)
end

return Statemachine