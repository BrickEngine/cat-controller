local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")

local network = ReplicatedStorage.Network
local RequtestSpawn = network.ClientToServer.RequestSpawn

local spawns = workspace.Spawns:GetChildren()
local starterCharPreset = StarterPlayer.DefaultCharacter

local function removePlayer(plr: Player)
	if (plr.Character) then plr.Character:Destroy() end
end

local function plrCharConfig(plr: Player, mdl: Model, spawnPoint: SpawnLocation)
	mdl.Name = tostring(plr.UserId)
	mdl.Parent = workspace.ActivePlayers
	mdl:MoveTo(spawnPoint.Position)
	mdl.PrimaryPart:SetNetworkOwner(plr)
	plr.Character = mdl
end

local function initPlrCharacter(Plr: Player)
	local newCharacter = starterCharPreset:Clone()
	local SelectedSpawn = spawns[math.random(1, #spawns)]
	
	plrCharConfig(Plr, newCharacter, SelectedSpawn)
	return newCharacter
end

local function handleSpawnRequest(plr: Player)
	if (plr.Character) then
		warn(tostring(plr.Name).." attempted to spawn with active character") return
		--Plr.Character:Destroy()
	end
	local Char = initPlrCharacter(plr)
end

local function onPlayerJoin(plr: Player)
	-- TODO
end

local function onPlayerLeave(plr: Player)
	removePlayer(plr)
end


Players.PlayerAdded:Connect(onPlayerJoin)
Players.PlayerRemoving:Connect(onPlayerLeave)

RequtestSpawn.OnServerEvent:Connect(handleSpawnRequest)