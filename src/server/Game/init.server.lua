local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Global = require(ReplicatedStorage.Shared.Global)
local CollisionGroup = require(ReplicatedStorage.Shared.Enums.CollisionGroup)
local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local Network = require(ReplicatedStorage.Shared.Network)
local ServApi = require(script.ServNetApi)

------------------------------------------------------------------------------------------------------
-- Initialize Workspace
do
    -- Create Workspace folder for runtime player characters
    if (not Workspace:FindFirstChild(Global.PLAYERS_INST_FOLDER_NAME)) then
        Instance.new(
            "Folder", Workspace
        ).Name = Global.PLAYERS_INST_FOLDER_NAME
    end

    -- Check if all collision groups are registered
    for _, groupName in pairs(CollisionGroup) do
        if (not PhysicsService:IsCollisionGroupRegistered(groupName)) then
            warn("Unregistered collision group: " .. groupName)
        end
    end
end

------------------------------------------------------------------------------------------------------

local function removePlayerCharacter(plr: Player)
	if (plr.Character) then plr.Character:Destroy() end
end

-- local function setPlrReplicationFocus(plr: Player)
--     if (not Players[plr.Name]) then
--         error("player does not exist", 2)
--     end

--     local repPart: BasePart
--     local basePlate = Workspace:FindFirstChild("Baseplate")

--     if (basePlate) then
--         repPart = basePlate
--     else
--         repPart = Instance.new("Part", Workspace)
--         repPart.Anchored = true
--         repPart.CFrame = CFrame.identity
--         repPart.CanCollide, repPart.CanQuery, repPart.CanTouch = false, false, false
--         repPart.Transparency = 1
--     end
--     plr.ReplicationFocus = repPart
-- end

local function spawnAndSetPlrChar(plr: Player)
    -- TODO: proper PlayerModel selection
    local plrMdl = StarterPlayer:FindFirstChild("PlayerModel")
	local newCharacter = CharacterDef.createCharacter(plrMdl)

    -- TODO: proper spawn management
    local tmpSpawn : SpawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local spawnPos : Vector3 = (tmpSpawn.CFrame.Position + Vector3.new(0,2,0)) or Vector3.new(0, 50, 0)  --spawns[math.random(1, #spawns)]
    do
        newCharacter.Name = tostring(plr.UserId)
        newCharacter.Parent = Workspace:FindFirstChild(Global.PLAYERS_INST_FOLDER_NAME)
        newCharacter:MoveTo(spawnPos)

        plr.Character = newCharacter
        newCharacter.PrimaryPart:SetNetworkOwner(plr)
    end

    assert(plr.Character and plr.Character.PrimaryPart, "Player character must exist and have a primary part")

    if (Workspace.StreamingEnabled) then
        plr.ReplicationFocus = plr.Character.PrimaryPart
    end

	return newCharacter
end

local function onPlayerAdded(plr: Player)
    print(plr.Name .. " WAS ADDED")
    --setPlrReplicationFocus(plr)
end

local function onPlayerRemoving(plr: Player)
    removePlayerCharacter(plr)
end

-- Network events management
local remEventFunctions = {
    [Network.clientEvents.requestSpawn] = function(plr: Player)
        if (plr.Character) then
            warn(plr.Name.." attempted to spawn with active character")
            plr.Character = nil
        end
        spawnAndSetPlrChar(plr)
    end,
    [Network.clientEvents.requestDespawn] = function(plr: Player)
        removePlayerCharacter(plr)
        -- TODO
    end
}

local fastRemEventFunctions = {
    [Network.clientFastEvents.cJointsDataSend] = function(plr: Player)
        -- TODO
    end
}

local remFunctionFunctions = {}

ServApi.implementREvents(remEventFunctions)
ServApi.implementFastREvents(fastRemEventFunctions)
ServApi.implementRFunctions(remFunctionFunctions)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)