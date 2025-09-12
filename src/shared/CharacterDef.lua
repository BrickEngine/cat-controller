local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Gobal = require(ReplicatedStorage.Shared.Global)
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)

local DEBUG_COLL_COLOR3 = Color3.fromRGB(0, 0, 255)

local PLAYERMDL_MASS_ENABLED = false
local MAIN_ROOT_PRIO = 100

-----------------------------------------------------------------------------------------------------------------
-- character phys model parameters

local PARAMS = {
    ROOT_ATT_NAME = "Root",
    ROOTPART_SIZE = Vector3.new(0, 0, 0),
    MAINCOLL_SIZE = Vector3.new(1, 2, 2),
    LEGCOLL_SIZE = Vector3.new(2, 2, 2),
    ROOTPART_SHAPE = Enum.PartType.Block,
    MAINCOLL_SHAPE = Enum.PartType.Cylinder,
    LEGCOLL_SHAPE = Enum.PartType.Cylinder,
    ROOTPART_CF = CFrame.identity,
    MAINCOLL_CF = CFrame.new(
        0, 0.5, 0,
        0, -1, 0,
        1, 0, 0,
        0, 0, 1
    ),
    LEGCOLL_CF = CFrame.new(
        0, -1, 0,
        0, -1, 0,
        1, 0, 0,
        0, 0, 1
    ),
    PLAYERMODEL_OFFSET_CF = CFrame.new(
        0, 0.72, 0,
        1, 0, 0,
        0, 1, 0,
        0, 0, 1
    ),
    PHYS_PROPERTIES = PhysicalProperties.new(
        1, 0, 0, 100, 100
    )
}

-----------------------------------------------------------------------------------------------------------------

local function setCollGroup(mdl: Model)
    for _, v: BasePart in pairs(mdl:GetDescendants()) do
        if (v:IsA("BasePart")) then
            v.CollisionGroup = CollisionGroups.PLAYER
        end
    end
end

local function setMdlTransparency(mdl: Model, val: number)
    for _, v: Instance in pairs(mdl:GetChildren()) do
        if (v:IsA("BasePart")) then
            v.Transparency = val
        elseif (v:IsA("Model")) then
            setMdlTransparency(v, val)
        end
    end
end

local function createPart(name: string, size: Vector3, cFrame: CFrame, shape: Enum.PartType): BasePart
    local part = Instance.new("Part")
    part.Name = name; part.Size = size; part.CFrame = cFrame; part.Shape = shape; part.Transparency = 1; part.Anchored = false
    part.CustomPhysicalProperties = PARAMS.PHYS_PROPERTIES
    return part
end

local function createParentedAttachment(name: string, parent: BasePart): Attachment
    local attachment = Instance.new("Attachment")
    attachment.Parent = parent
    return attachment
end

local function createParentedWeld(p0: BasePart, p1: BasePart): WeldConstraint
    local weldConstraint = Instance.new("WeldConstraint")
    weldConstraint.Part0 = p0; weldConstraint.Part1 = p1
    weldConstraint.Parent = p0
    return weldConstraint
end

local function createCharacter(playerModel: Model?): Model
    if (not RunService:IsServer()) then
        error("createCharacter should only be called on the server")
    end

    local character = Instance.new("Model")
    local rootPart = createPart("RootPart", PARAMS.ROOTPART_SIZE, PARAMS.ROOTPART_CF, PARAMS.ROOTPART_SHAPE)
    local mainColl = createPart("MainColl", PARAMS.MAINCOLL_SIZE, PARAMS.MAINCOLL_CF, PARAMS.MAINCOLL_SHAPE)
    local legColl = createPart("LegColl", PARAMS.LEGCOLL_SIZE, PARAMS.LEGCOLL_CF, PARAMS.LEGCOLL_SHAPE)

    rootPart.Parent, mainColl.Parent, legColl.Parent = character, character, character
    rootPart.CanCollide, rootPart.CanQuery, rootPart.CanTouch = false, false, false
    createParentedWeld(rootPart, mainColl)
    createParentedWeld(rootPart, legColl)
    rootPart.Massless = true
    rootPart.RootPriority = MAIN_ROOT_PRIO
    legColl.CanCollide = false
    character.PrimaryPart = rootPart
    createParentedAttachment("Root", rootPart)

    if (Gobal.GAME_PHYS_DEBUG) then
        setMdlTransparency(character, 0.5)
        mainColl.Color = DEBUG_COLL_COLOR3
    end

    -- add playermodel
    if (not playerModel) then
        error("No PlayerModel found", 2)
    end
    if (not playerModel.PrimaryPart) then
        error("PlayerModel has no set PrimaryPart", 2)
    end

    local plrMdlClone = playerModel:Clone()
    local plrMdlPrimPart = plrMdlClone.PrimaryPart

    for _, inst: Instance in pairs(plrMdlClone:GetChildren()) do
        if (inst:IsA("BasePart")) then
            inst.Parent = character
            if (not PLAYERMDL_MASS_ENABLED) then
                inst.Massless = true
            end
        end
        if (inst:IsA("Folder") or inst:IsA("Model")) then
            inst.Parent = character
        end
    end
    plrMdlPrimPart.CFrame = rootPart.CFrame * PARAMS.PLAYERMODEL_OFFSET_CF
    createParentedWeld(rootPart, plrMdlPrimPart)
    plrMdlClone:Destroy()

    -- create Animator and AnimationController
    local animController = Instance.new("AnimationController", character)
    Instance.new("Animator", animController)

    -- create universal BuoyancySensor
    local buoySens = Instance.new("BuoyancySensor", plrMdlPrimPart)
    buoySens.UpdateType = Enum.SensorUpdateType.OnRead

    -- setup instance streaming
    if (Workspace.StreamingEnabled) then
        character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end

    return character
end

-----------------------------------------------------------------------------------------------------------------

local CharacterDef = {}
CharacterDef.__index = CharacterDef

function CharacterDef.new()
    local self = setmetatable({}, CharacterDef)

    self.PARAMS = table.freeze(PARAMS)

    return self
end

-- must be called on the server
function CharacterDef.createCharacter(playerModel: Model): Model
    if (not RunService:IsServer()) then
        error("character should be created from server")
    end

    local character = createCharacter(playerModel)
    setCollGroup(character)

    return character
end

return CharacterDef.new()