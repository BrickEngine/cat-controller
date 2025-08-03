local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local NetApiDef = require(ReplicatedStorage.Shared.NetworkApiDef)
local ServApi = require(script.ServApi)

local spawns = Workspace.Spawns:GetChildren()
--local starterCharPreset = StarterPlayer.DefaultCharacter :: Model

local PLAYERS_FOLD_NAME = "ActivePlayers"

-- Workspace init
do
    -- create workspace folder for runtime player characters
    if (not Workspace:FindFirstChild(PLAYERS_FOLD_NAME)) then
        local plrFold = Instance.new("Folder")
        plrFold.Name = PLAYERS_FOLD_NAME
        plrFold.Parent = Workspace
    end
    -- check if all collision groups are registered
    for _, groupName in pairs(CollisionGroups) do
        if (not PhysicsService:IsCollisionGroupRegistered(groupName)) then
            warn("unregistered collision group: " .. groupName)
        end
    end
end

local function removePlayerCharacter(plr: Player)
	if (plr.Character) then plr.Character:Destroy() end
end

local function setPlrReplicationFocus(plr: Player)
    if (not Players[plr.Name]) then
        error("player does not exist", 2)
    end

    local repPart: BasePart

    if (Workspace.Baseplate) then
        repPart = Workspace.Baseplate
    else
        repPart = Instance.new("Part")
        repPart.Anchored = true
        repPart.CFrame = CFrame.identity
        repPart.CanCollide, repPart.CanQuery, repPart.CanTouch = false, false, false
        repPart.Transparency = 1
        repPart.Parent = Workspace
    end
    plr.ReplicationFocus = repPart
end

local function spawnAndSetPlrChar(plr: Player)
    -- TODO: proper PlayerModel selection
    local plrMdl = StarterPlayer:FindFirstChild("PlayerModel")
	local newCharacter = CharacterDef.createCharacter(plrMdl)

	local SelectedSpawn = spawns[math.random(1, #spawns)]
    do
        newCharacter.Name = tostring(plr.UserId)
        newCharacter.Parent = Workspace.ActivePlayers
        newCharacter:MoveTo(SelectedSpawn.Position)
        newCharacter.PrimaryPart:SetNetworkOwner(plr)
        plr.Character = newCharacter
    end

    if (Workspace.StreamingEnabled) then
        plr.ReplicationFocus = plr.Character.PrimaryPart
    end

	return newCharacter
end

local function onPlayerAdded(plr: Player)
    print(plr.Name .. " WAS ADDED")
    setPlrReplicationFocus(plr)
end

local function onPlayerRemoving(plr: Player)
    removePlayerCharacter(plr)
end

local remEventFunctions = {
    [NetApiDef.clientEvents.requestSpawn] = function(plr: Player)
        if (plr.Character) then
            warn(plr.Name.." attempted to spawn with active character")
            plr.Character = nil
        end
        spawnAndSetPlrChar(plr)
    end,
    [NetApiDef.clientEvents.requestDespawn] = function(plr: Player)
        removePlayerCharacter(plr)
        -- TODO
    end
}

local fastRemEventFunctions = {
    [NetApiDef.clientFastEvents.cJointsDataSend] = function(plr: Player)
        -- TODO
    end
}

local remFunctionFunctions = {}

ServApi.implementREvents(remEventFunctions)
ServApi.implementFastREvents(fastRemEventFunctions)
ServApi.implementRFunctions(remFunctionFunctions)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)