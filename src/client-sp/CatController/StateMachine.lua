local simStates = script.Parent.SimStates
local BaseState = require(simStates.BaseState)
local Ground = require(simStates.Ground) :: BaseState.BaseStateType
local Water = require(simStates.Water) :: BaseState.BaseStateType
local Air = require(simStates.Air) :: BaseState.BaseStateType

local Statemachine = {}
Statemachine.__index = Statemachine

function Statemachine.new(character)
    local self = setmetatable({}, Statemachine)

    self.character = character
    self.states = {
        Ground = Ground.new(),
        --Water = Water.new(),
        --Air = Air.new()
    }

    self.currentState = Ground
    self.currentState:stateEnter()

    return self
end

function Statemachine:transitionState(newState)
    
end

function Statemachine:getCurrentState()
    
end

return Statemachine