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
    currentState: BaseState.BaseStateType,
    states: {[any]: BaseState.BaseStateType}
}

local stateIdMap = {}

local Statemachine = {}
Statemachine.__index = Statemachine

function Statemachine.new(character: Model)
    local self = setmetatable({}, Statemachine)

    self.character = character
    self.states = {
        Ground = Ground.new(self),
        Air = Air.new(self),
        Water = Water.new(self)
    }
    stateIdMap[self.states.Ground] = 0
    stateIdMap[self.states.Air] = 1
    stateIdMap[self.states.Water] = 2

    self.currentState = self.states.Ground

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

    local oldState = self.currentState
    self.currentState:leaveState()
    self.currentState = newState
    self.currentState:stateEnter(oldState)
end

function Statemachine:getCurrentState()
    return self.currentState
end

function Statemachine:resetRefs(character: Model)
    self.character = character
end

function Statemachine:update(dt: number, inputController)
    if (self.character) then
        self.currentState:update(dt, inputController)
    end

    return stateIdMap[self.currentState]
end

function Statemachine:destroy()
    setmetatable(self, nil)
end

return Statemachine