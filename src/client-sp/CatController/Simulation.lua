local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local Animation = require(script.Parent.Animation)
local DebugVisualize = require(script.Parent.Common.DebugVisualize)

local simStates = script.Parent.SimStates
local BaseState = require(simStates.BaseState)
local Ground = require(simStates.Ground) :: BaseState.BaseStateType
local Water = require(simStates.Water) :: BaseState.BaseStateType
local Air = require(simStates.Air) :: BaseState.BaseStateType

-- local vars
local primaryPartListener: RBXScriptConnection
local state_free = true

local Simulation = {}
Simulation.__index = Simulation

function Simulation.new()
    local self = setmetatable({}, Simulation) :: any
    self.states = {}
    self.currentState = nil
    self.simUpdateConn = nil
    self.animation = nil

    self.character = Players.LocalPlayer.Character

    Players.LocalPlayer.CharacterAdded:Connect(function(char) self:onCharAdded(char) end)
    Players.LocalPlayer.CharacterRemoving:Connect(function(char) self:onCharRemoving(char) end)

    if Players.LocalPlayer.Character then
		self:onCharAdded(Players.LocalPlayer.Character)
	end

    print("Simulation initialized")

    return self
end

------------------------------------------------------------------------------------------------------------------------------

-- should be bound to RunService.PreSimulation
function Simulation:update(dt: number)
    if (not self.character.PrimaryPart) then
        warn("missing PrimaryPart of character, skipping simulation update")
        self.simUpdateConn:Disconnect(); return
    end
    if (not state_free) then
        return
    end

    self.currentState:update(dt)
    DebugVisualize.step()
end

function Simulation:transitionState(newState: BaseState.BaseStateType)
    state_free = false

    if (not newState) then
        error("cannot transition to nonexistent state")
    end

    self.currentState:stateLeave()
    self.currentState = newState
    self.currentState:stateEnter()

    state_free = true
end

function Simulation:getCurrentStateId(): number
    if (self.currentState) then
        return self.currentState.id
    end
    return -1
end

function Simulation:getNormal(): Vector3
    if (self.currentState and self.currentState.normal) then
        return self.currentState.normal
    end
    return Vector3.zero
end

function Simulation:onRootPartChanged()
    if (not self.character.PrimaryPart) then
        warn("missing PrimaryPart -> halting simulation, removing character")
        self:onCharRemoving(Players.LocalPlayer.Character)
    end
end

function Simulation:resetSimulation()
    if (self.simUpdateConn :: RBXScriptConnection) then
        self.simUpdateConn:Disconnect()
    end
    if (self.animation) then
        self.animation:destroy()
    end

    self.animation = Animation.new(self)

    if (self.states :: {[string]: BaseState.BaseStateType}) then
        for name: string, _ in pairs(self.states) do
            self.states[name]:destroy()
            self.states[name] = nil
        end
    end

    self.states = {
        Ground = Ground.new(self),
        Water = Water.new(self)
    }
    self.currentState = self.states.Ground
    self.currentState:stateEnter()

    self.simUpdateConn = RunService.PreSimulation:Connect(function(dt)
        self:update(dt)
    end)
end

-- TESTING PURPOSES
local function TEST_DESPAWNING()
    print("TESTING RANDOM CHARACTER BREAKING")
    task.spawn(function()
        local pTbl = {}
        local char = Players.LocalPlayer.Character
        for i,v in pairs(char:GetChildren()) do
            if (v:IsA("BasePart")) then
                table.insert(pTbl, v)
            end
        end
        while (#pTbl > 0) do
            task.wait(0.001)
            local rdm = math.random(1, #pTbl)
            pTbl[rdm]:Destroy()
            table.remove(pTbl, rdm)
        end
        --Players.LocalPlayer.Character:Destroy()
    end)
end

function Simulation:onCharAdded(character: Model)
    self.character = character

    if (primaryPartListener) then
        primaryPartListener:Disconnect()
    end
    if (not self.character.PrimaryPart) then
        error("character missing PrimaryPart")
    end
    primaryPartListener = self.character.PrimaryPart.Changed:Connect(function()
        self:onRootPartChanged()
    end)

    for _, s: Instance in pairs(StarterPlayer.StarterCharacterScripts:GetChildren()) do
        print(tostring(s.ClassName))
        if (s.ClassName ~= ("LocalScript" or "Script" or "ModuleScript")) then
            warn("instance within StarterCharacterScripts is not a script")
        end
        local sClone = s:Clone()
        sClone.Parent = self.character
    end

    self:resetSimulation()

    --TEST_DESPAWNING()
end

function Simulation:onCharRemoving(character: Model)
    self.simUpdateConn:Disconnect()

    if (Players.LocalPlayer.Character) then
        Players.LocalPlayer.Character:Destroy()
        Players.LocalPlayer.Character = nil
    end
end

return Simulation.new()