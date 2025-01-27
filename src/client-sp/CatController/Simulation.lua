local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Controller = script.Parent
local CameraModule = require(Controller.CameraModule)
local StateMachine = require(Controller.StateMachine)

local RENDER_PRIO = 100

local Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
    local self = setmetatable({}, Simulation)

    self.character = nil
    self.activeControl = nil
    self.currentState = nil

    Players.LocalPlayer.CharacterAdded:Connect(function(char) self:onCharAdded(char) end)
    Players.LocalPlayer.CharacterRemoving:Connect(function(char) self:onCharRemoving(char) end)
    if Players.LocalPlayer.Character then
		self:onCharAdded(Players.LocalPlayer.Character)
	end

    RunService:BindToRenderStep("SimulationRSUpdate", RENDER_PRIO, function(dt) 
        self:update(dt) 
    end)

	UserInputService.LastInputTypeChanged:Connect(function(newLastInputType)
		self:OnLastInputTypeChanged(newLastInputType)
	end)
end

function Simulation:update()
    
end
function Simulation:onCharAdded(character)
    self.character = character
    StateMachine:resetRefs(character)
end

function Simulation:onCharRemoving()
    self.character = nil
    StateMachine:resetRefs(nil)
end

return Simulation.new()