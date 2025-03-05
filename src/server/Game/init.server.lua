local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local NetApiDef = require(ReplicatedStorage.Shared.NetworkApiDef)
local ServApi = require(script.ServApi)

local spawns = Workspace.Spawns:GetChildren()
--local starterCharPreset = StarterPlayer.DefaultCharacter :: Model

local PLAYERS_FOLD_NAME = "ActivePlayers"

-- Workspace init
do
    if (not Workspace:FindFirstChild(PLAYERS_FOLD_NAME)) then
        local plrFold = Instance.new("Folder")
        plrFold.Name = PLAYERS_FOLD_NAME
        plrFold.Parent = Workspace
    end
end

local function removePlayerCharacter(plr: Player)
	if (plr.Character) then plr.Character:Destroy() end
end

local function spawnAndSetPlrChar(plr: Player)
    local playerModel = StarterPlayer:FindFirstChild("PlayerModel") -- TODO: proper PlayerModel selection

	local newCharacter = CharacterDef.createCharacter(playerModel)
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

local function onPlayerAdded(plr: Player)
    -- TODO
end

local function onPlayerRemoving(plr: Player)
    removePlayerCharacter(plr)
end

local rEventFunctions = {
    [NetApiDef.clientEvents.requestSpawn] = function(plr: Player)
        if (plr.Character) then
            warn(tostring(plr.Name).." attempted to spawn with active character") return
        end
        spawnAndSetPlrChar(plr)
    end,
    [NetApiDef.clientEvents.requestDespawn] = function(plr: Player)
        removePlayerCharacter(plr)
        -- TODO
    end
}

local rFuncFunctions = {}

ServApi.implementREvents(rEventFunctions)
ServApi.implementRFunctions(rFuncFunctions)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)