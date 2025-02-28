local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local NetApiDef = require(ReplicatedStorage.Shared.NetworkApiDef)
local ServApi = require(script.ServApi)

local rEventFunctions = {}
local rFuncFunctions = {}

local spawns = Workspace.Spawns:GetChildren()
local starterCharPreset = StarterPlayer.DefaultCharacter :: Model

-- Workspace init
do
    if (not Workspace:FindFirstChild("ActivePlayers")) then
        local plrFold = Instance.new("Folder")
        plrFold.Name = "ActivePlayers"
        plrFold.Parent = Workspace
    end
end

local function removePlayer(plr: Player)
	if (plr.Character) then plr.Character:Destroy() end
end

local function spawnAndSetPlrChar(plr: Player, playerModel: Model)
    if (playerModel) then
        print("player requested model")
    end
	local newCharacter = starterCharPreset:Clone()
	local SelectedSpawn = spawns[math.random(1, #spawns)]
    do
        newCharacter.Name = tostring(plr.UserId)
        newCharacter.Parent = Workspace.ActivePlayers
        newCharacter:MoveTo(SelectedSpawn.Position)
        newCharacter.PrimaryPart:SetNetworkOwner(plr)
        plr.Character = newCharacter
    end
	return newCharacter
end

function rEventFunctions.requestSpawn(plr: Player, playerModel: Model?)
    if (plr.Character) then
		warn(tostring(plr.Name).." attempted to spawn with active character") return
	end
	spawnAndSetPlrChar(plr, playerModel)
end

function rEventFunctions.requestDespawn(plr: Player)
    
end

ServApi.implementREvents(rEventFunctions)
ServApi.implementRFunctions(rFuncFunctions)