local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local simStates = script.Parent.SimStates
local StateGround = require(simStates.Ground)
local StateWater = require(simStates.Water)
local StateAir = require(simStates.Air)

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

function Simulation:onCharAdded(character)
    self.character = character
end

function Simulation:onCharRemoving()
    self.character = nil
end

return Simulation.new()