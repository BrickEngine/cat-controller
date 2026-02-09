--[[
    Main module for all client-side player and game logic.

    lots and lot of TODO here
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Network = require(ReplicatedStorage.Shared.Network)
local CliApi = require(ReplicatedStorage.Shared.Network.CliNetApi)

-- Init Controller singleton
require(ReplicatedStorage.Shared.CatController)

local clientEvents = Network.clientEvents

local DEFAULT_HEALTH = 100

type Counter = {
    t: number,
    cooldown: number
}

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------
local updateConn = nil

local GameClient = {
    gameTime = 0,
}
GameClient.__index = GameClient

function GameClient.init()
    
end

function GameClient:InitPlayer()
    local function respawnAfterCharRemove(character: Model)
        print(character.Name .. " was removed")
        --task.wait(1.5)
        CliApi[clientEvents.requestSpawn]()
    end

    CliApi[clientEvents.requestSpawn]()
    Players.LocalPlayer.CharacterRemoving:Connect(respawnAfterCharRemove)
end

function GameClient:updateGameTime(dt: number, override: number?)
    if (override) then self.gameTime = override end
    self.gameTime += dt
end

------------------------------------------------------------------------------------------------------------------------
-- GameClient update
------------------------------------------------------------------------------------------------------------------------
function GameClient:update(dt: number)
    self:updateGameTime(dt)
end

-- Sets player data default values and stops execution
function GameClient:reset()
    self.gameTime = 0
    self.currentInvSlot = 0
    self.health = DEFAULT_HEALTH

    if (updateConn) then
        (updateConn :: RBXScriptConnection):Disconnect()
    end
    updateConn = RunService.PreSimulation:Connect(
        function(dt) self:update(dt) end
    )
end

return GameClient