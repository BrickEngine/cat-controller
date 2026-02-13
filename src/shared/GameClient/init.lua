--[[
    Main module for all client-side player and game logic.

    lots and lot of TODO here
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Network = require(ReplicatedStorage.Shared.Network)
local CliApi = require(script.CliNetApi)
local Global = require(ReplicatedStorage.Shared.Global)
local SoundManager = require(ReplicatedStorage.Shared.SoundManager)

-- Init Controller singleton
require(ReplicatedStorage.Shared.CatController)

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
    local function respawnAfterCharRemove(char: Model)
        Global.logInfo(`Removing character of {char.Name}`)
        --task.wait(1.5)
        CliApi.events[Network.clientEvents.requestSpawn]:FireServer()
    end

    Global.logInfo(`LocalPlayer requests spawn`)
    CliApi.events[Network.clientEvents.requestSpawn]:FireServer()
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

------------------
local cliREFunction = {
    [Network.serverEvents.playSound] = function(plr: Player, item: string, play: boolean)
        SoundManager.updatePlayerSound(plr, item, play)
    end
}

local cliFastREFunctions = {
    [Network.serverFastEvents.jointsDataToClient] = function(plr: Player)
        -- TODO
    end,
}

CliApi.implementREvents(cliREFunction)
CliApi.implementFastREvents(cliFastREFunctions)

return GameClient