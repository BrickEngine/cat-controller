--[[
    Preloads assets and manages loading and title screen
]]

local ReplicatedFirst = game:GetService("ReplicatedFirst")

--local Assets = require(ReplicatedFirst.SharedFirst.Assets)

ReplicatedFirst:RemoveDefaultLoadingScreen()

--Assets.preLoad()
--Assets.preLoadImgPhysical()

print("[LOAD] - Game has loaded")