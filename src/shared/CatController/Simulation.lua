local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local Animation = require(script.Parent.Animation)
local DebugVisualize = require(script.Parent.Common.DebugVisualize)

local PlayerStateId = require(ReplicatedStorage.Shared.Enums.PlayerStateId)
local Global = require(ReplicatedStorage.Shared.Global)
local simStates = script.Parent.SimStates
local BaseState = require(simStates.BaseState)
local Ground = require(simStates.Ground) :: BaseState.BaseState
local Water = require(simStates.Water) :: BaseState.BaseState

-- Local vars
local primaryPartListener: RBXScriptConnection
local state_free = true

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------
local Simulation = {}
Simulation.__index = Simulation

export type Simulation = typeof(Simulation)

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

    return self
end

------------------------------------------------------------------------------------------------------------------------
-- Simulation update
------------------------------------------------------------------------------------------------------------------------

-- Should be bound to RunService.PostSimulation
function Simulation:update(dt: number)
    if (not self.character.PrimaryPart) then
        warn("Missing PrimaryPart of character, disconnecting simulation update func")
        self.simUpdateConn:Disconnect(); return
    end

    -- Skip the update cycle, if state transition not complete
    if (not state_free) then
        return
    end

    self.currentState:update(dt)
    DebugVisualize.step()
end

function Simulation:transitionState(newStateId: number, params: any?)
    state_free = false

    if (Global.PRINT_SIM_DEBUG) then
        print(`Transitioning from {self.currentState.id} to {newStateId}`)
    end

    local newState = self.states[newStateId]
    assert(newState, "cannot transition to nonexistent state")

    self.currentState:stateLeave()
    self.currentState = newState
    self.currentState:stateEnter(params)

    state_free = true
end

function Simulation:getCurrentStateId(): number
    if (self.currentState) then
        return self.currentState.id
    end
    return PlayerStateId.NONE
end

function Simulation:getNormal(): Vector3
    if (self.currentState and self.currentState.normal) then
        return self.currentState.normal
    end
    return Vector3.zero
end

function Simulation:getIsDashing(): boolean
    if (self.currentState) then
        return self.currentState.isDashing
    end
    return false
end

function Simulation:getNearWall(): (boolean, boolean)
    if (self.currentState) then
        return self.currentState.nearWall, self.currentState.isRightSideWall
    end
    return false, false
end

function Simulation:onRootPartChanged()
    if (not self.character.PrimaryPart) then
        warn("PrimaryPart of character removed -> halting simulation, removing character")
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

    if (self.states :: {[number]: BaseState.BaseState}) then
        for id: number, _ in pairs(self.states) do
            self.states[id]:destroy()
            self.states[id] = nil
        end
    end

    self.states = {
        [PlayerStateId.GROUNDED] = Ground.new(self),
        [PlayerStateId.IN_WATER] = Water.new(self),
    }
    self.currentState = self.states[PlayerStateId.GROUNDED]
    self.currentState:stateEnter()

    self.simUpdateConn = RunService.PostSimulation:Connect(function(dt)
        self:update(dt)
    end)
end

-- TESTING PURPOSES
-- local function TEST_DESPAWNING()
--     print("TESTING RANDOM CHARACTER BREAKING")
--     task.spawn(function()
--         local pTbl = {}
--         local char = Players.LocalPlayer.Character
--         for i,v in pairs(char:GetChildren()) do
--             if (v:IsA("BasePart")) then
--                 table.insert(pTbl, v)
--             end
--         end
--         while (#pTbl > 0) do
--             task.wait(0.001)
--             local rdm = math.random(1, #pTbl)
--             pTbl[rdm]:Destroy()
--             table.remove(pTbl, rdm)
--         end
--         --Players.LocalPlayer.Character:Destroy()
--     end)
-- end

function Simulation:onCharAdded(character: Model)
    self.character = character

    if (primaryPartListener) then
        primaryPartListener:Disconnect()
    end
    if (not self.character.PrimaryPart) then
        error("character missing PrimaryPart")
    end
    --self.character.PrimaryPart.Removing
    primaryPartListener = self.character.DescendantRemoving:Connect(function()
        self:onRootPartChanged()
    end)

    -- Copy over Instances from StarterCharacterScripts
    -- TODO: move logic over to GameClient
    for _, s: Instance in pairs(StarterPlayer.StarterCharacterScripts:GetChildren()) do
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