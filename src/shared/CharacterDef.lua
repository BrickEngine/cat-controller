local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)

local DEBUG = true
local COLLIDER_DEBUG_COLOR3 = Color3.fromRGB(0, 0, 255)
local CREATE_BASE_FORCES = true

-----------------------------------------------------------------------------------------------------------------
-- Character phys model parameters

local PARAMS = {
    ROOTPART_SIZE = Vector3.new(0, 0, 0),
    MAINCOLL_SIZE = Vector3.new(1, 2, 2),
    LEGCOLL_SIZE = Vector3.new(2, 2, 2),
    ROOTPART_SHAPE = Enum.PartType.Block,
    COLLIDER_SHAPE = Enum.PartType.Cylinder,
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
        0, 0.4, -0.8,
        -1, 0, 0,
        0, 1, 0,
        0, 0, -1
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

local function unanchorMdl(mdl: Model)
    for _, v in pairs(mdl:GetDescendants()) do
        if (v:IsA("BasePart")) then
            v.Anchored = false
        end
    end
end

local function createPart(name: string, size: Vector3, cFrame: CFrame, shape: Enum.PartType): BasePart
    local part = Instance.new("Part")
    part.Name = name; part.Size = size; part.CFrame = cFrame; part.Shape = shape; part.Transparency = 1; part.Anchored = false
    part.CustomPhysicalProperties = PARAMS.PHYS_PROPERTIES
    return part
end

local function createParentedWeld(p0: Part, p1: Part)
    local weldConstraint = Instance.new("WeldConstraint")
    weldConstraint.Part0 = p0; weldConstraint.Part1 = p1
    weldConstraint.Parent = p0
end

local function createCharacter(playerModel: Model?): Model
    local character = Instance.new("Model")
    local rootPart = createPart("RootPart", PARAMS.ROOTPART_SIZE, PARAMS.ROOTPART_CF, PARAMS.ROOTPART_SHAPE)
    local mainColl = createPart("MainColl", PARAMS.MAINCOLL_SIZE, PARAMS.MAINCOLL_CF, PARAMS.COLLIDER_SHAPE)
    local legColl = createPart("LegColl", PARAMS.LEGCOLL_SIZE, PARAMS.LEGCOLL_CF, PARAMS.COLLIDER_SHAPE)

    rootPart.Parent, mainColl.Parent, legColl.Parent = character, character, character
    createParentedWeld(rootPart, mainColl); createParentedWeld(rootPart, legColl)
    rootPart.CanCollide, rootPart.CanQuery, rootPart.CanTouch = false, false, false
    rootPart.Massless = true
    legColl.CanCollide = false
    character.PrimaryPart = rootPart

    if (DEBUG) then
        for _, p: BasePart in pairs(character:GetChildren()) do
            p.Transparency = 0.5
        end
        mainColl.Color = COLLIDER_DEBUG_COLOR3
    end

    if (not playerModel) then
        warn("no PlayerModel set")
        
        local emptyPlayerModel = Instance.new("Model")
        emptyPlayerModel.Name = "PlayerModel"
        emptyPlayerModel.Parent = character
    else
        if (not playerModel.PrimaryPart) then
            error("no PrimaryPart defined for the PlayerModel")
        end
        playerModel.PrimaryPart.CFrame = rootPart.CFrame * PARAMS.PLAYERMODEL_OFFSET_CF
        createParentedWeld(rootPart, playerModel.PrimaryPart)
        playerModel.Parent = character
    end

    return character
end

local function createForces(mdl: Model)
    local attachment = Instance.new("Attachment")
    attachment.Name = "Root"
    attachment.Parent = mdl.PrimaryPart
    attachment.WorldAxis = Vector3.new(0, 1, 0)

    local aliOri = Instance.new("AlignOrientation")
    aliOri.Parent = mdl.PrimaryPart
    aliOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    aliOri.AlignType = Enum.AlignType.PrimaryAxisParallel
    aliOri.ReactionTorqueEnabled, aliOri.RigidityEnabled = true, true
    aliOri.Attachment0 = attachment
    aliOri.PrimaryAxis = Vector3.new(0, 1, 0)
end

-----------------------------------------------------------------------------------------------------------------

local CharacterDef = {}
CharacterDef.__index = CharacterDef

function CharacterDef.new()
    local self = setmetatable({}, CharacterDef)

    self.PARAMS = PARAMS

    return self
end

function CharacterDef.createCharacter(playerModel: Model): Model
    if (not RunService:IsServer()) then
        error("character should be created from server")
    end

    local character = createCharacter(playerModel)
    if (CREATE_BASE_FORCES) then
        createForces(character)
    end
    setCollGroup(character)

    return character
end

return CharacterDef.new()