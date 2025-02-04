local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local CatController = require(StarterPlayer.StarterPlayerScripts.CatController)
local CliApi = require(script.CliApi)

CliApi.requestSpawn()