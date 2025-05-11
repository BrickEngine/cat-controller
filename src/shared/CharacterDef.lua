local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)

local DEBUG = true
local DEBUG_DISABLE_CHAR = false
local DEBUG_COLL_COLOR3 = Color3.fromRGB(0, 0, 255)

local ADD_BUOYANCY_SENSOR = true
local CREATE_BASE_FORCES = false
local USE_PLAYERMDL_MASS = false
local MAIN_ROOT_PRIO = 100

-----------------------------------------------------------------------------------------------------------------
-- Character phys model parameters

local PARAMS = {
    ROOT_ATT_NAME = "Root",
    PHYS_TAG_NAME = "PhysAssemblyPart",
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
        0, 0.5, 0,
        1, 0, 0,
        0, 1, 0,
        0, 0, 1
    ),
    PHYS_PROPERTIES = PhysicalProperties.new(
        2, 0, 0, 100, 100
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

    for _, p: Instance in pairs(character:GetChildren()) do
        if (p:IsA("BasePart")) then
            p:AddTag(PARAMS.PHYS_TAG_NAME)
        end
    end

    if (DEBUG) then
        setMdlTransparency(character, 0.5)
        mainColl.Color = DEBUG_COLL_COLOR3
    end

    if (ADD_BUOYANCY_SENSOR) then
        local buoyancySensor = Instance.new("BuoyancySensor")
        buoyancySensor.Parent = mainColl
    end

    -- add PlayerModel
    if (not playerModel or DEBUG_DISABLE_CHAR) then
        warn("no PlayerModel set")

        local emptyPlayerModel = Instance.new("Model")
        emptyPlayerModel.Name = "PlayerModel"
        emptyPlayerModel.Parent = character
    else
        if (not playerModel.PrimaryPart) then
            error("no PrimaryPart defined for the PlayerModel")
        end

        local plrMdlClone = playerModel:Clone()
        local plrMdlPrimPart = plrMdlClone.PrimaryPart

        for _, inst: Instance in pairs(plrMdlClone:GetChildren()) do
            if (inst:IsA("BasePart")) then
                inst.Parent = character
                if (not USE_PLAYERMDL_MASS) then
                    (inst :: BasePart).Massless = true
                end
            end
            if (inst:IsA("Folder")) then
                inst.Parent = character
            end
        end
        plrMdlPrimPart.CFrame = rootPart.CFrame * PARAMS.PLAYERMODEL_OFFSET_CF
        createParentedWeld(rootPart, plrMdlPrimPart)
        plrMdlClone:Destroy()
    end

    local animController = Instance.new("AnimationController", character)
    Instance.new("Animator", animController)

    if (Workspace.StreamingEnabled) then
        character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end

    return character
end

local function createBaseForces(mdl: Model)
    local forcesAtt = Instance.new("Attachment")
    forcesAtt.Name = "BaseForceAtt"
    forcesAtt.Parent = mdl.PrimaryPart
    forcesAtt.WorldAxis = Vector3.new(0, 1, 0)

    local aliOri = Instance.new("AlignOrientation")
    aliOri.Parent = mdl.PrimaryPart
    aliOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    aliOri.AlignType = Enum.AlignType.PrimaryAxisParallel
    aliOri.ReactionTorqueEnabled, aliOri.RigidityEnabled = true, true
    aliOri.Attachment0 = forcesAtt
    aliOri.PrimaryAxis = Vector3.new(0, 1, 0)
end

-----------------------------------------------------------------------------------------------------------------

local CharacterDef = {}
CharacterDef.__index = CharacterDef

function CharacterDef.new()
    local self = setmetatable({}, CharacterDef)

    self.PARAMS = table.freeze(PARAMS)

    return self
end

function CharacterDef.createCharacter(playerModel: Model): Model
    if (not RunService:IsServer()) then
        error("character should be created from server")
    end

    local character = createCharacter(playerModel)
    if (CREATE_BASE_FORCES) then
        createBaseForces(character)
    end
    setCollGroup(character)

    return character
end

return CharacterDef.new()