local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local playerScripts = script.Parent

local CatController = require(playerScripts:WaitForChild("CatController"))
local NetApiDef = require(ReplicatedStorage.Shared.NetworkApiDef)
local CliApi = require(script.CliApi)

local clientEvents = NetApiDef.clientEvents

-- TODO:
-- request streaming position with RequestStreamAroundAsync(), which is returned from
-- the CliApi[clientEvents.requestSpawn]() RemoteFunction instead of RemoteEvent

-- while (not Players.LocalPlayer.ReplicationFocus) do
--     print("waiting")
--     task.wait()
-- end

local function respawnAfterCharRemove(character: Model)
    print(character.Name .. " was removed")
    --task.wait(1.5)
    CliApi[clientEvents.requestSpawn]()
end

print("client requests character for first time")
CliApi[clientEvents.requestSpawn]()

Players.LocalPlayer.CharacterRemoving:Connect(respawnAfterCharRemove)