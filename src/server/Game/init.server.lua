local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Global = require(ReplicatedStorage.Shared.Global)
local CollisionGroup = require(ReplicatedStorage.Shared.Enums.CollisionGroup)
local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local Network = require(ReplicatedStorage.Shared.Network)
local ServNetApi = require(script.ServNetApi)
local DynamicAnim = require(ReplicatedStorage.Shared.DynamicAnim)

local MAX_INVALID_FAST_EVENTS_COUNT = 500

local fastEventPlayerBlacklist = {} :: {Player}
local illegalPlayerCallsMap = {} :: {[Player]: number}

------------------------------------------------------------------------------------------------------------------------
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

------------------------------------------------------------------------------------------------------------------------

-- local function validateTableOfType(tbl: any, elemTypeName: string): boolean
--     if (type(tbl) ~= "table") then return false end
--     if (#tbl > MAX_DATA_ARR_SIZE) then return false end

--     for _, v: any in pairs(tbl) do
--         if (typeof(v) ~= elemTypeName) then
--             return false
--         end
--     end
--     return true
-- end

-- Registers an illegal fast event for a given player and returns true if they
-- exceeded the max numbers of illegal fast events
local function registerIllegalFastEvent(plr: Player)
    if (not illegalPlayerCallsMap[plr]) then
        illegalPlayerCallsMap[plr] = 0
    end
    if (illegalPlayerCallsMap[plr] >= MAX_INVALID_FAST_EVENTS_COUNT) then
        fastEventPlayerBlacklist[plr] = true; return
    end
    illegalPlayerCallsMap[plr] += 1
end

local function removePlayerCharacter(plr: Player)
	if (plr.Character) then plr.Character:Destroy() end
end

local function spawnAndSetPlrChar(plr: Player)
    -- TODO: proper PlayerModel selection
    local plrMdl = StarterPlayer:FindFirstChild("PlayerModel")
	local newCharacter = CharacterDef.createCharacter(plrMdl)

    -- TODO: proper spawn management
    local tmpSpawn : SpawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local spawnPos : Vector3 = (tmpSpawn.CFrame.Position + Vector3.new(0,2,0)) or Vector3.new(0, 50, 0)
    do
        newCharacter.Name = tostring(plr.UserId)
        newCharacter.Parent = Workspace:FindFirstChild(Global.PLAYERS_INST_FOLDER_NAME)
        newCharacter:MoveTo(spawnPos)

        plr.Character = newCharacter
        newCharacter.PrimaryPart:SetNetworkOwner(plr)
        for _, v: Instance in newCharacter:GetDescendants() do
            if (v:IsA("BasePart")) then
                v:SetNetworkOwner(plr)
            end
        end
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

local function onPlayerRequestSound(plr: Player, item: string?, play: boolean?)
    if (type(item) ~= "string" or type(play) ~= "boolean") then
        warn(`{plr.Name} sent illegal sound item arg`); return
    end
    ServNetApi.events[Network.serverEvents.playSound]:FireAllClients(plr, item, play)
end

local function onJointDataSend(plr: Player, dataString: string)
    if (not plr.Character) then
        warn(`{plr} attempted to send joint data without active character`)
        registerIllegalFastEvent(plr); return
    end
    --dataString = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    -- validate sent player data
    local isValidData = true
    if ((typeof(dataString) ~= "string") or
        (dataString:len() < DynamicAnim.DATA_PACK_BYTES)
    ) then 
        isValidData = false 
    end

    if (not isValidData) then
        warn(`{plr} sent invalid payload`)
        registerIllegalFastEvent(plr); return
    end
    ServNetApi.fastEvents[Network.serverFastEvents.jointsDataToClient]:FireAllClients(plr, dataString)
end

------------------------------------------------------------------------------------------------------------------------
-- Network implementation
------------------------------------------------------------------------------------------------------------------------

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
    end,

    [Network.clientEvents.requestSound] = function(plr: Player, ...)
        onPlayerRequestSound(plr, ...)
    end,
}

local fastRemEventFunctions = {
    [Network.clientFastEvents.jointsDataToServer] = function(plr: Player, ...)
        if (fastEventPlayerBlacklist[plr]) then
            return
        end
        onJointDataSend(plr, ...)
    end,
}

local remFunctionFunctions = {}

ServNetApi.implementREvents(remEventFunctions)
ServNetApi.implementFastREvents(fastRemEventFunctions)
ServNetApi.implementRFunctions(remFunctionFunctions)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)