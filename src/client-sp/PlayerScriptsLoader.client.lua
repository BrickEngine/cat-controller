local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatController = require(script.Parent.CatController)

ReplicatedStorage.Network.ClientToServer.RequestSpawn:FireServer()