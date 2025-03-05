local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = script.Parent
local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local StateMachine = require(Controller.StateMachine)

local ACTION_PRIO = 100
local SIM_UPDATE_FUNC = "SimRSUpdate"

local Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
    local self = setmetatable({}, Simulation)

    self.character = Players.LocalPlayer.Character
    self.stateMachine = nil
    self.currentStateId = 0

    Players.LocalPlayer.CharacterAdded:Connect(function(char) self:onCharAdded(char) end)
    Players.LocalPlayer.CharacterRemoving:Connect(function(char) self:onCharRemoving(char) end)
    if Players.LocalPlayer.Character then
		self:onCharAdded(Players.LocalPlayer.Character)
	end

    -- RunService:BindToRenderStep(SIM_UPDATE_FUNC, ACTION_PRIO, function(dt)
    --     self:update(dt)
    -- end)

    return self
end

------------------------------------------------------------------------------------------------------------------------------

function Simulation:getStateId()
    return self.currentStateId
end

function Simulation:update(dt: number)
    self.currentStateId = self.stateMachine:update(dt)
end

function Simulation:onCharAdded(character)
    self.character = character
    self.stateMachine = StateMachine.new(self.character)

    RunService:BindToRenderStep(SIM_UPDATE_FUNC, ACTION_PRIO, function(dt)
        self:update(dt)
    end)
end

function Simulation:onCharRemoving()
    RunService:UnbindFromRenderStep(SIM_UPDATE_FUNC)
    -- if (self.stateMachine) then
    --     self.stateMachine:destroy()
    -- end
end

return Simulation.new()