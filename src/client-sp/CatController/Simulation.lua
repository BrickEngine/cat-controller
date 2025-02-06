local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Controller = script.Parent
local StateMachine = require(Controller.StateMachine)
local MoveKeyboard = require(Controller.MoveKeyboard)
local MoveTouch = nil -- TODO

local RENDER_PRIO = 100

local INPUT_TYPES = {
    moveKeyboard = "MoveKeyboard",
    moveTouch = "MoveTouch"
}

local Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
    local self = setmetatable({}, Simulation)

    self.inputModules = {}
    self.inputModules[INPUT_TYPES.moveKeyboard] = MoveKeyboard.new(RENDER_PRIO)

    self.character = Players.LocalPlayer.Character
    self.activeInputModule = nil
    self.stateMachine = nil

    Players.LocalPlayer.CharacterAdded:Connect(function(char) self:onCharAdded(char) end)
    Players.LocalPlayer.CharacterRemoving:Connect(function(char) self:onCharRemoving(char) end)
    if Players.LocalPlayer.Character then
		self:onCharAdded(Players.LocalPlayer.Character)
	end

    -------------------------------------------------------------------------------------

    self:initMoveInpControl()
    self:initStateMachine()

    RunService:BindToRenderStep("SimulationRSUpdate", RENDER_PRIO, function(dt)
        self:update(dt)
    end)

	UserInputService.LastInputTypeChanged:Connect(function(newLastInputType)
		--self:onLastInputTypeChanged(newLastInputType)
	end)

    return self
end

function Simulation:update(dt: number)
    self.stateMachine:update(dt)
    print(self:getActiveInputModule():getMoveVec())
end

function Simulation:onCharAdded(character)
    self.character = character
    self.stateMachine:resetRefs(character)
end

function Simulation:onCharRemoving()
    --self.character = nil
    --self.stateMachine:resetRefs(nil)
end

function Simulation:getActiveInputModule(): any
    return self.inputModules[self.activeInputModule]
end

function Simulation:initMoveInpControl(): boolean
    if (UserInputService.KeyboardEnabled) then
        self.activeInputModule = INPUT_TYPES.moveKeyboard
    elseif (UserInputService.TouchEnabled) then
        self.activeInputModule = nil -- TODO
    else
        self.activeInputModule = nil
    end

    if (self.activeInputModule) then
        self:getActiveInputModule():enable(true)
    end
end

function Simulation:initStateMachine()
    if (self.stateMachine) then
        return
    end

    self.stateMachine = StateMachine.new(self.character, self:getActiveInputModule())
end

return Simulation.new()