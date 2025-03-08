local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local CatController = require(StarterPlayer.StarterPlayerScripts.CatController)
local NetApiDef = require(ReplicatedStorage.Shared.NetworkApiDef)
local CliApi = require(script.CliApi)

local clientEvents = NetApiDef.clientEvents

local function respawnAfterCharRemove(character: Model)
    print(character.Name .. " was removed")
    --task.wait(1.5)
    CliApi[clientEvents.requestSpawn]()
end

CliApi[clientEvents.requestSpawn]()

Players.LocalPlayer.CharacterRemoving:Connect(respawnAfterCharRemove)