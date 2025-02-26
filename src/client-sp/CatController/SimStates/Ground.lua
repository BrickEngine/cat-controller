local Workspace = game:GetService("Workspace")

local Controller = script.Parent.Parent
local BaseState = require(Controller.SimStates.BaseState)
local physCheck = require(Controller.Common.PhysCheck)
local InputManager = require(Controller.InputManager)

local Ground = setmetatable({}, BaseState)
Ground.__index = Ground

local function getWalkInput()
    
end

function Ground.new(stateMachine)
    local self = setmetatable(BaseState.new(stateMachine), Ground)

    self._stateMachine = stateMachine

    return self
end

function Ground:stateEnter(oldState: BaseState.BaseStateType)
    print("I AM GROUND")
end

function Ground:stateLeave()
    print("BAIBAI")
end

function Ground:update(dt: number)
   --print(self._stateMachine._input)
    --print(inputController)
    print(InputManager:getMoveVec())
end

return Ground