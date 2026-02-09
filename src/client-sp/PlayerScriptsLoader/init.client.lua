-- Entry point of all CatController client modules

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameClient = require(ReplicatedStorage.Shared.GameClient)

GameClient:reset()
GameClient:InitPlayer()