--!strict

local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local DebugVisualize = require(script.Parent.Common.DebugVisualize)

local simStates = script.Parent.SimStates
local BaseState = require(simStates.BaseState)
local Ground = require(simStates.Ground) :: BaseState.BaseStateType
local Water = require(simStates.Water) :: BaseState.BaseStateType
local Air = require(simStates.Air) :: BaseState.BaseStateType

local ACTION_PRIO = 100
local FUNCNAME_UPDATE = "SimRSUpdate"

local primaryPartListener: RBXScriptConnection

local Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
    local self = setmetatable({}, Simulation) :: any

    self.states = {}
    self.currentState = nil
    self.currentStateId = nil
    self.simUpdateConn = nil

    self.character = Players.LocalPlayer.Character

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

-- should be bound to RunService.PreSimulation
function Simulation:update(dt: number)
    if (not self.character.PrimaryPart) then
        error("missing PrimaryPart of character, skipping simulation update"); return
    end
    self.currentState:update(dt)
    DebugVisualize.step()
end

function Simulation:transitionState(newState: BaseState.BaseStateType)
    if (not newState) then
        error("cannot transition to nonexistent state")
    end

    self.currentState:stateLeave()
    self.currentState = newState
    self.currentState:stateEnter()
end

function Simulation:getCurrentStateId()
    return self.currentStateId
end

function Simulation:onRootPartChanged()
    if (not self.character.PrimaryPart) then
        warn("something removed the PrimaryPart, halting simulation")
        self:onCharRemoving(Players.LocalPlayer.Character)
    end
end

function Simulation:resetSimulation()
    if (self.currentState) then
        self.currentState:stateLeave()
    end
    -- TODO: add a state:destroy() function to each state, which is called here
    -- all state controlled instances will be reacted with .new() instead of :stateEnter()
    -- any forces that are required for the state are enabled with state:stateEnter(), and disabled with state:stateLeave()
    if (self.states) then
        for name, _ in pairs(self.states) do
            self.states[name] = nil
        end
    end

    self.states = {
        Ground = Ground.new(self),
        Air = Air.new(self),
        Water = Water.new(self)
    }
    self.currentState = self.states.Ground
    self.currentState:stateEnter()

    if (self.simUpdateConn :: RBXScriptConnection) then
        self.simUpdateConn:Disconnect()
    end
    self.simUpdateConn = RunService.PreSimulation:Connect(function(dt)
        self:update(dt)
    end)
end

-- TESTING PURPOSES
local function TEST_DESPAWNING()
    print("TESTING RANDOM CHARACTER BREAKING")
    task.spawn(function()
        task.wait(0.05)
        local char = Players.LocalPlayer.Character
        for i,v in pairs(char:GetChildren()) do
            local rdm = math.random(1, #char:GetChildren())
            char:GetChildren()[rdm]:Destroy()
            task.wait(0.1)
        end
        --Players.LocalPlayer.Character:Destroy()
    end)
end

function Simulation:onCharAdded(character: Model)
    self.character = character

    if (not character.PrimaryPart) then
        error("A")
    end

    self:resetSimulation()

    if (primaryPartListener) then
        primaryPartListener:Disconnect()
    end
    primaryPartListener = character.PrimaryPart.Changed:Connect(function()
        self:onRootPartChanged()
    end)

    -- RunService:BindToRenderStep(FUNCNAME_UPDATE, ACTION_PRIO, function(dt)
    --     self:update(dt)
    -- end)

    --TEST_DESPAWNING()
end

function Simulation:onCharRemoving(character: Model)
    print("::: CHARACTER REMOVING :::")
    if (Players.LocalPlayer.Character) then
        warn("onCharRemoving called with existing character")
        Players.LocalPlayer.Character = nil
        return
    end

    RunService:UnbindFromRenderStep(FUNCNAME_UPDATE)
end

-- task.spawn(function()
--     print("char test delete")
--     task.wait(5)
--     Players.LocalPlayer.Character.PrimaryPart:Destroy()
-- end)

return Simulation.new()