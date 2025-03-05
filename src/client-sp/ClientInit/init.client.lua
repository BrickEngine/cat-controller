local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local CatController = require(StarterPlayer.StarterPlayerScripts.CatController)
local NetApiDef = require(ReplicatedStorage.Shared.NetworkApiDef)
local CliApi = require(script.CliApi)

local clientEvents = NetApiDef.clientEvents

CliApi[clientEvents.requestSpawn]()