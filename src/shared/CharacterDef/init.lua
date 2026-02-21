local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CollisionGroup = require(ReplicatedStorage.Shared.Enums.CollisionGroup)

local PLAYERMDL_MASS_ENABLED = false
local PRINT_UNUSED_PARTS_WARNING = false

-- not to be confused with the actual primary part of the character
local PLAYERMDL_ROOTPART_NAME = "MdlRoot"
local JOINTS_FOLDER_NAME = "CharacterJoints"

local MAIN_ROOT_PRIO = 100

-----------------------------------------------------------------------------------------------------------------
-- character phys model parameters

local PARAMS = {
    ROOT_ATT_NAME = "Root",
    ROOTPART_SIZE = Vector3.new(1, 1, 1),
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
    for _, v: Instance in pairs(mdl:GetDescendants()) do
        if (v:IsA("BasePart")) then
            v.CollisionGroup = CollisionGroup.PLAYER
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
    part.Name = name; part.Size = size; part.CFrame = cFrame
    part.Shape = shape; part.Transparency = 1; part.Anchored = false
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

-- local function createCharacterIKRig(character: Model)

--     local function createIKControl(mdl: Model, name: string): IKControl
--         local iKControl = Instance.new("IKControl", mdl)
--         iKControl.Name = name
--         return iKControl
--     end

--     local function createHingeJoint(mdl: Model, joint: Motor6D, loAng: number, upAng: number, rotVec: Vector3?)
--         local hinge = Instance.new("HingeConstraint", mdl)
--         local hp0_att = Instance.new("Attachment", joint.Part0)
--         local hp1_att = Instance.new("Attachment", joint.Part1)
--         local rf = rotVec and rotVec or VEC3_ZERO

--         hp0_att.CFrame = joint.C0
--         hp1_att.CFrame = joint.C1
--         hp0_att.CFrame *= CFrame.Angles(rf.X, rf.Y, rf.Z)
--         hp1_att.CFrame *= CFrame.Angles(rf.X, rf.Y, rf.Z)
--         hinge.ActuatorType = Enum.ActuatorType.None
--         hinge.LimitsEnabled = true
--         hinge.LowerAngle = loAng
--         hinge.UpperAngle = upAng
--         hinge.Attachment0 = hp0_att
--         hinge.Attachment1 = hp1_att
--     end

--     local function createBallJoint(mdl: Model, joint: Motor6D, limit: number, rotVec: Vector3?)
--         local ballsocket = Instance.new("BallSocketConstraint", mdl)
--         local hp0_att = Instance.new("Attachment", joint.Part0)
--         local hp1_att = Instance.new("Attachment", joint.Part1)
--         local rf = rotVec and rotVec or VEC3_ZERO

--         hp0_att.CFrame = joint.C0
--         hp1_att.CFrame = joint.C1
--         hp0_att.CFrame *= CFrame.Angles(rf.X, rf.Y, rf.Z)
--         hp1_att.WorldCFrame = hp0_att.WorldCFrame
--         ballsocket.LimitsEnabled = true
--         ballsocket.TwistLimitsEnabled = true
--         ballsocket.MaxFrictionTorque = 0
--         ballsocket.UpperAngle = limit
--         ballsocket.TwistLowerAngle = -180
--         ballsocket.TwistUpperAngle = 180
--         ballsocket.Attachment0 = hp0_att
--         ballsocket.Attachment1 = hp1_att
--     end

--     assert(character.PrimaryPart, "Character has no primary part")
--     if (not joints) then error("Joints were not initialized") end

--     local vertOffs = VEC3_UP * SCAN_Y_OFFS
--     local primaryPart = character.PrimaryPart
--     -- fl
--     --local fl_paw = character[PART_NAMES.FL_PAW] :: BasePart
--     local fl_wrist = character[PART_NAMES.FL_WRIST] :: BasePart
--     local fl_bicep = character[PART_NAMES.FL_BICEP] :: BasePart
--     -- fr
--     --local fr_paw = character[PART_NAMES.FL_PAW] :: BasePart
--     local fr_wrist = character[PART_NAMES.FR_WRIST] :: BasePart
--     local fr_bicep = character[PART_NAMES.FR_BICEP] :: BasePart
--     -- rl
--     --local rl_paw = character[PART_NAMES.RL_PAW] :: BasePart
--     local rl_ankle = character[PART_NAMES.RL_ANKLE] :: BasePart
--     local rl_thigh = character[PART_NAMES.RL_THIGH] :: BasePart
--     -- rr
--     --local rr_paw = character[PART_NAMES.RR_PAW] :: BasePart
--     local rr_ankle = character[PART_NAMES.RR_ANKLE] :: BasePart
--     local rr_thigh = character[PART_NAMES.RR_THIGH] :: BasePart

--     -- offsets from root part
--     local fl_poleOffs = BASE_POLE_OFFSETS[PART_NAMES.FL_WRIST]
--     local fr_poleOffs = BASE_POLE_OFFSETS[PART_NAMES.FR_WRIST]
--     local rl_poleOffs = BASE_POLE_OFFSETS[PART_NAMES.RL_ANKLE]
--     local rr_poleOffs = BASE_POLE_OFFSETS[PART_NAMES.RR_ANKLE]

--     local fl_sens = createOffsetAttOnInst(primaryPart, fl_wrist.Position + vertOffs)
--     local fr_sens = createOffsetAttOnInst(primaryPart, fr_wrist.Position + vertOffs)
--     local rl_sens = createOffsetAttOnInst(primaryPart, rl_ankle.Position + vertOffs)
--     local rr_sens = createOffsetAttOnInst(primaryPart, rr_ankle.Position + vertOffs)

--     local fl_targ = createOffsetAttOnInst(primaryPart, fl_wrist.Position)
--     local fr_targ = createOffsetAttOnInst(primaryPart, fr_wrist.Position)
--     local rl_targ = createOffsetAttOnInst(primaryPart, rl_ankle.Position)
--     local rr_targ = createOffsetAttOnInst(primaryPart, rr_ankle.Position)

--     local fl_pole = createOffsetAttOnInst(primaryPart, primaryPart.Position + fl_poleOffs)
--     local fr_pole = createOffsetAttOnInst(primaryPart, primaryPart.Position + fr_poleOffs)
--     local rl_pole = createOffsetAttOnInst(primaryPart, primaryPart.Position + rl_poleOffs)
--     local rr_pole = createOffsetAttOnInst(primaryPart, primaryPart.Position + rr_poleOffs)
--     fl_pole.Name = "fl_pole"; fr_pole.Name = "fr_pole"; rl_pole.Name = "rl_pole"; rr_pole.Name = "rr_pole"

--     local fl_ik = createIKControl(character, PART_NAMES.FL_WRIST)
--     local fr_ik = createIKControl(character, PART_NAMES.FR_WRIST)
--     local rl_ik = createIKControl(character, PART_NAMES.RL_ANKLE)
--     local rr_ik = createIKControl(character, PART_NAMES.RR_ANKLE)

--     legSensAttTbl = {}
--     legSensAttTbl[PART_NAMES.FL_WRIST] = fl_sens
--     legSensAttTbl[PART_NAMES.FR_WRIST] = fr_sens
--     legSensAttTbl[PART_NAMES.RL_ANKLE] = rl_sens
--     legSensAttTbl[PART_NAMES.RR_ANKLE] = rr_sens

--     for nameInd: string, sens: Attachment in pairs(legSensAttTbl) do
--         sens.WorldCFrame = primaryPart.CFrame * CFrame.new(BASE_SENSOR_OFFSETS[nameInd])
--     end

--     legTargetAttTbl = {}
--     legTargetAttTbl[PART_NAMES.FL_WRIST] = fl_targ
--     legTargetAttTbl[PART_NAMES.FR_WRIST] = fr_targ
--     legTargetAttTbl[PART_NAMES.RL_ANKLE] = rl_targ
--     legTargetAttTbl[PART_NAMES.RR_ANKLE] = rr_targ

--     -- legRootRelativeAttTbl = {}
--     -- legRootRelativeAttTbl[PART_NAMES.FL_WRIST] = fl_rootRel
--     -- legRootRelativeAttTbl[PART_NAMES.FR_WRIST] = fr_rootRel
--     -- legRootRelativeAttTbl[PART_NAMES.RL_ANKLE] = rl_rootRel
--     -- legRootRelativeAttTbl[PART_NAMES.RR_ANKLE] = rr_rootRel

--     iKControlTbl = {}
--     iKControlTbl[PART_NAMES.FL_WRIST] = fl_ik
--     iKControlTbl[PART_NAMES.FR_WRIST] = fr_ik
--     iKControlTbl[PART_NAMES.RL_ANKLE] = rl_ik
--     iKControlTbl[PART_NAMES.RR_ANKLE] = rr_ik

--     local rot_y_180 = Vector3.new(0, RAD_180, 0)
--     local rot_yz_l = Vector3.new(0, RAD_180, RAD_90)
--     local rot_yz_r = Vector3.new(0, RAD_180, -RAD_90)
--     createBallJoint(character, joints[JOINT_NAMES.FL_LEG_0], 10, rot_y_180)
--     createHingeJoint(character, joints[JOINT_NAMES.FL_LEG_1], 0, 170)
--     createHingeJoint(character, joints[JOINT_NAMES.FL_LEG_2], -180, 5)
--     createBallJoint(character, joints[JOINT_NAMES.FL_PAW], 12, rot_yz_l)

--     createBallJoint(character, joints[JOINT_NAMES.FR_LEG_0], 10)
--     createHingeJoint(character, joints[JOINT_NAMES.FR_LEG_1], 0, 170)
--     createHingeJoint(character, joints[JOINT_NAMES.FR_LEG_2], -180, 5)
--     createBallJoint(character, joints[JOINT_NAMES.FR_PAW], 12, rot_yz_l)

--     createBallJoint(character, joints[JOINT_NAMES.RL_LEG_0], 6.5, rot_y_180)
--     createHingeJoint(character, joints[JOINT_NAMES.RL_LEG_1], -65, 0)
--     createHingeJoint(character, joints[JOINT_NAMES.RL_LEG_2], -180, 5)
--     createBallJoint(character, joints[JOINT_NAMES.RL_PAW], 12, rot_yz_r)

--     createBallJoint(character, joints[JOINT_NAMES.RR_LEG_0], 6.5)
--     createHingeJoint(character, joints[JOINT_NAMES.RR_LEG_1], -65, 0)
--     createHingeJoint(character, joints[JOINT_NAMES.RR_LEG_2], -180, 5)
--     createBallJoint(character, joints[JOINT_NAMES.RR_PAW], 12, rot_yz_r)

--     -- config IKControls
--     for _, ik: IKControl in pairs(iKControlTbl) do
--         ik.Type = Enum.IKControlType.Position
--         ik.SmoothTime = IK_CONTROL_SMOOTH_TIME
--         ik.Weight = 0
--     end

--     -- offset targets
--     for nameId: string, targ: Attachment in pairs(legTargetAttTbl) do
--         targ.WorldCFrame *= CFrame.new(TARGET_OFFSETS[nameId])
--     end

--     fl_ik.EndEffector = fl_wrist
--     fl_ik.ChainRoot = fl_bicep
--     fl_ik.Pole = fl_pole
--     fl_ik.Target = fl_targ

--     fr_ik.EndEffector = fr_wrist
--     fr_ik.ChainRoot = fr_bicep
--     fr_ik.Pole = fr_pole
--     fr_ik.Target = fr_targ

--     rl_ik.EndEffector = rl_ankle
--     rl_ik.ChainRoot = rl_thigh
--     rl_ik.Pole = rl_pole
--     rl_ik.Target = rl_targ

--     rr_ik.EndEffector = rr_ankle
--     rr_ik.ChainRoot = rr_thigh
--     rr_ik.Pole = rr_pole
--     rr_ik.Target = rr_targ
-- end

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

    -- Playermodel with assigned PrimaryPart is required
    if (not playerModel) then
        error("No PlayerModel found", 2)
    end
    if (not playerModel.PrimaryPart) then
        error("PlayerModel has no set PrimaryPart", 2)
    end

    local plrMdlClone = playerModel:Clone()
    local plrMdlPrimPart = plrMdlClone.PrimaryPart
    plrMdlPrimPart.Name = PLAYERMDL_ROOTPART_NAME

    for _, inst: Instance in pairs(plrMdlClone:GetDescendants()) do
        if (inst:IsA("BasePart")) then
            inst.Parent = character
            inst.CanCollide = false

            if (not PLAYERMDL_MASS_ENABLED) then
                inst.Massless = true
            end
        elseif (inst:IsA("Model") or inst:IsA("Folder")) then
            (inst :: Instance).Parent = character
        end
    end
    plrMdlPrimPart.CFrame = rootPart.CFrame * PARAMS.PLAYERMODEL_OFFSET_CF
    createParentedWeld(rootPart, plrMdlPrimPart)

    -- Discard playermodel with remaining unused components
    if (#(plrMdlClone:GetDescendants()) > 0 and PRINT_UNUSED_PARTS_WARNING) then
        warn("Playermodel included unused components, which were discarded:")
        warn(plrMdlClone:GetDescendants())
    end
    plrMdlClone:Destroy()

    -- Create Animator and AnimationController
    local animController = Instance.new("AnimationController", character)
    Instance.new("Animator", animController)

    -- Player characters should never be streamed out for other clients
    if (Workspace.StreamingEnabled) then
        character.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end

    return character
end

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------

local CharacterDef = {
    PARAMS = PARAMS,
    PLAYERMDL_ROOTPART_NAME = PLAYERMDL_ROOTPART_NAME,
    JOINTS_FOLDER_NAME = JOINTS_FOLDER_NAME
}

-- Can only be called on the server
function CharacterDef.createCharacter(playerModel: Model): Model
    if (not RunService:IsServer()) then
        error("character should be created from server")
    end

    local character = createCharacter(playerModel)
    setCollGroup(character)

    return character
end

return CharacterDef