--[[
    Dynamic animation logic for the playermodel:
    body rotation, foot-planting, head movement, etc.
]]

local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local JointMap = require(script.JointMap)

--[[Definitions]]

local CHAR_JOINTS_FOLDER_NAME = CharacterDef.JOINTS_FOLDER_NAME
local JOINT_NAMES = JointMap.JOINT_NAMES
local JOINT_INDEX_ARR = JointMap.JOINT_INDEX_ARR
local PART_NAMES = JointMap.PART_NAMES

--[[Data]]

-- one Vector3 + n Quaternions as number
local NUM_PACKED_NUMBERS = 3 + (#JOINT_INDEX_ARR * 4)
-- format for compressing array of numbers into string
local DATA_PACK_FORMAT = string.rep("f", NUM_PACKED_NUMBERS)
-- total (min) expected size of the data packet in bytes
local DATA_PACK_BYTES = NUM_PACKED_NUMBERS * 4
-- for data validation
local MAX_QUAT_ABS = 2.0

--[[General]]

local VEC3_ZERO = Vector3.zero
local VEC3_UP = Vector3.new(0, 1, 0)
local RAD_90 = math.rad(90)
local RAD_180 = math.rad(180)

local SCAN_Y_OFFS = 1.5
local CAST_DIST = CharacterDef.PARAMS.LEGCOLL_SIZE.X * 5.5
local HIP_HEIGHT = CharacterDef.PARAMS.LEGCOLL_SIZE.X - 0.15
local SCAN_HIP_HEIGHT = HIP_HEIGHT + SCAN_Y_OFFS
local SCAN_RANGE_MAX = SCAN_Y_OFFS + 25.0
local SHOULDER_RANGE = SCAN_Y_OFFS + 1.15
local TARGET_FRONT_Y_OFFS = 0.35
local TARGET_REAR_Y_OFFS = 0.675
-- whether to compute a plane based on the smallest sum of foot scan points of either side of root joint
-- works well when you don't want floating limbs when only one is touching a step
local USE_LOWEST_PLANE = false

local EVENT_DT = 0.025 -- time interval between event calls (0.025 sec ~ 40 FPS)
local MAX_SLOPE_ANGLE = math.rad(45)
local MAX_ROOT_OFFS = 2
local LERP_FAC = 0.045--0.07
local NET_LERP_DT = 0.5 -- lerp for other players
local IK_CONTROL_SMOOTH_TIME = 0.1

------------------------------------------------------------------------------------------------------------------------
-- Module and server return point
------------------------------------------------------------------------------------------------------------------------

local DynamicAnim = {
    DATA_PACK_BYTES = DATA_PACK_BYTES
}
if (RunService:IsServer()) then
    return DynamicAnim
end

------------------------------------------------------------------------------------------------------------------------
-- Client return point
------------------------------------------------------------------------------------------------------------------------

if (not RunService:IsClient()) then
    error("This part of the module should not be accessed by the server", 2)
end

-- Client requires
local Global = require(ReplicatedStorage.Shared.Global)
local Controller = require(ReplicatedStorage.Shared.CatController)
local PlayerStateId = require(ReplicatedStorage.Shared.Enums.PlayerStateId)
local CollisionGroup = require(ReplicatedStorage.Shared.Enums.CollisionGroup)
local Network = require(ReplicatedStorage.Shared.Network)
local CliNetApi = require(ReplicatedStorage.Shared.GameClient.CliNetApi)
local MathUtil = require(ReplicatedStorage.Shared.Util.MathUtil)

-- non character attached playermodel
local templatePlayermdl = StarterPlayer:FindFirstChild("PlayerModel"):Clone()
local baseJointsFolder = templatePlayermdl:FindFirstChild(CHAR_JOINTS_FOLDER_NAME)

-- default joint object-space CFrame offsets
local BASE_C0_JCF = table.freeze({
    [JOINT_NAMES.ROOT] = baseJointsFolder:FindFirstChild(JOINT_NAMES.ROOT).C0 :: CFrame,
    [JOINT_NAMES.TORSO_0] = baseJointsFolder:FindFirstChild(JOINT_NAMES.TORSO_0).C0 :: CFrame,
    [JOINT_NAMES.TORSO_1] = baseJointsFolder:FindFirstChild(JOINT_NAMES.TORSO_1).C0 :: CFrame,
    [JOINT_NAMES.NECK_0] = baseJointsFolder:FindFirstChild(JOINT_NAMES.NECK_0).C0 :: CFrame,
    [JOINT_NAMES.TAIL_0] = baseJointsFolder:FindFirstChild(JOINT_NAMES.TAIL_0).C0 :: CFrame,
    [JOINT_NAMES.TAIL_1] = baseJointsFolder:FindFirstChild(JOINT_NAMES.TAIL_1).C0 :: CFrame,
})

-- offsets of the foot-planting scan points (from the root part)
local BASE_SENSOR_OFFSETS = table.freeze({
    [PART_NAMES.FL_WRIST] = Vector3.new(-0.327, SCAN_Y_OFFS, -1.3),
    [PART_NAMES.FR_WRIST] = Vector3.new(0.327, SCAN_Y_OFFS, -1.3),
    [PART_NAMES.RL_ANKLE] = Vector3.new(-0.349, SCAN_Y_OFFS, 1.876),
    [PART_NAMES.RR_ANKLE] = Vector3.new(0.349, SCAN_Y_OFFS, 1.876),
})

-- offsets of the poles of each IKControl (from the root part)
local BASE_POLE_OFFSETS = table.freeze({
    [PART_NAMES.FL_WRIST] = Vector3.new(-0.527, -0.5, 0.1),
    [PART_NAMES.FR_WRIST] = Vector3.new(0.527, -0.5, 0.1),
    [PART_NAMES.RL_ANKLE] = Vector3.new(-0.65, -1, -0.124),
    [PART_NAMES.RR_ANKLE] = Vector3.new(0.65, -1, -0.124),
})

local TARGET_OFFSETS = table.freeze({
    [PART_NAMES.FL_WRIST] = Vector3.new(0, TARGET_FRONT_Y_OFFS, 0.075),
    [PART_NAMES.FR_WRIST] = Vector3.new(0, TARGET_FRONT_Y_OFFS, 0.075),
    [PART_NAMES.RL_ANKLE] = Vector3.new(0, TARGET_REAR_Y_OFFS, 0),
    [PART_NAMES.RR_ANKLE] = Vector3.new(0, TARGET_REAR_Y_OFFS, 0),
})

local FOOT_JOINT_MAP = table.freeze({
    [PART_NAMES.FL_WRIST] = JOINT_NAMES.FL_PAW,
    [PART_NAMES.FR_WRIST] = JOINT_NAMES.FR_PAW,
    [PART_NAMES.RL_ANKLE] = JOINT_NAMES.RL_PAW,
    [PART_NAMES.RR_ANKLE] = JOINT_NAMES.RR_PAW,
})

local simulation = Controller:getSimulation()

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true
raycastParams.CollisionGroup = CollisionGroup.PLAYER

-- initialized when init is called
local character: Model
local plrMdlRoot: BasePart
local joints: {[string]: Motor6D}
local legSensAttTbl: {[string]: Attachment}
--local legRootRelativeAttTbl: {[string]: Attachment}
local legTargetAttTbl: {[string]: Attachment}
local iKControlTbl: {[string]: IKControl}

-- player tables
local plrCharTbl = {} :: {[Player]: Model}
local plrTargetDataTbl = {} :: {[Player]: {posOffset: Vector3, cFrameArr: CFrame}}

local connections = {
    updateConn = nil,
    charAddedConn = nil,
    charRemovingConn = nil,
    plrAddedConn = nil,
    plrRemovingConn = nil
}
local plrConnections = {} :: {[Player]: {RBXScriptConnection}}

local eventTime = 0

local function getJoints(): {[string]: Motor6D}
    local newJoints = {}
    for n, str: string in pairs(JOINT_NAMES) do
        local inst = character:FindFirstChild(str, true)
        if (inst :: Motor6D) then
            newJoints[str] = inst
        else
            error(`No Motor6D instance with name '{n}' found`)
        end
    end
    return newJoints
end

-- compress root offset and joint rotations data into formatted string
local function packJointData(): string
    if (not joints) then
        error("Joints were not initialized")
    end

    local compDataArr = table.create(NUM_PACKED_NUMBERS)
    local posOffs = joints[JOINT_NAMES.ROOT].C0.Position

    compDataArr[1] = posOffs.X
    compDataArr[2] = posOffs.Y
    compDataArr[3] = posOffs.Z
    local ind = #compDataArr + 1
    for _, j_ind_name: string in ipairs(JOINT_INDEX_ARR) do
        local joint = joints[JOINT_NAMES[j_ind_name]]
        local qX, qY, qZ, qW = MathUtil.createQuaternionFromCFrame(joint.C0)
        compDataArr[ind] = qX
        compDataArr[ind+1] = qY
        compDataArr[ind+2] = qZ
        compDataArr[ind+3] = qW
        ind += 4
    end
    -- compress data into a string
    local str = string.pack(
        DATA_PACK_FORMAT,
        table.unpack(compDataArr)
    )
    -- (3+28*4)*4 = 460 bytes in total
    return str
end

-- decode string into a Vector3 offset and an array of CFrames
local function unpackJointData(dataString: string): (Vector3, {CFrame})
    local numArr = table.pack(string.unpack(DATA_PACK_FORMAT, dataString))
    numArr[#numArr] = nil

    local offsVec = Vector3.new(numArr[1], numArr[2], numArr[3])
    local cFrameArr = {} :: {CFrame}
    local invalidData = false

    for i = 4, #numArr - 3, 4 do
        local qX = numArr[i]
        local qY = numArr[i+1]
        local qZ = numArr[i+2]
        local qW = numArr[i+3]
        if (math.abs(qX) > MAX_QUAT_ABS or math.abs(qY) > MAX_QUAT_ABS or
            math.abs(qZ) > MAX_QUAT_ABS or math.abs(qW) > MAX_QUAT_ABS
        ) then
            invalidData = true; break
        end

        local cFrame = MathUtil.getCFrameFromQuaternion(qX, qY, qZ, qW)
        cFrameArr[#cFrameArr + 1] = cFrame
    end

    if (invalidData) then
        return VEC3_ZERO, {}
    end
    return offsVec, cFrameArr
end

local function lerpJointAnglesCF(cf: CFrame, cf_base: CFrame, rVec: Vector3) : CFrame
    return cf * cf:ToObjectSpace(
        cf:Lerp(cf_base * CFrame.fromEulerAnglesXYZ(rVec.X, rVec.Y, rVec.Z), LERP_FAC)
    )
end

-- Attaches IKControl components and physical constraints to the character rig for foot-planting simulation
local function createOffsetAttOnInst(inst: Instance, offset: Vector3, isRelToPart: boolean?): Attachment
    local att = Instance.new("Attachment", inst)
    if (isRelToPart) then
        att.Position = offset
    else
        att.WorldPosition = offset
    end
    return att
end

local function createCharacterIKRig(character: Model)

    local function createIKControl(mdl: Model, name: string): IKControl
        local iKControl = Instance.new("IKControl", mdl)
        iKControl.Name = name
        return iKControl
    end

    local function createHingeJoint(mdl: Model, joint: Motor6D, loAng: number, upAng: number, rotVec: Vector3?)
        local hinge = Instance.new("HingeConstraint", mdl)
        local hp0_att = Instance.new("Attachment", joint.Part0)
        local hp1_att = Instance.new("Attachment", joint.Part1)
        local rf = rotVec and rotVec or VEC3_ZERO

        hp0_att.CFrame = joint.C0
        hp1_att.CFrame = joint.C1
        hp0_att.CFrame *= CFrame.Angles(rf.X, rf.Y, rf.Z)
        hp1_att.CFrame *= CFrame.Angles(rf.X, rf.Y, rf.Z)
        hinge.ActuatorType = Enum.ActuatorType.None
        hinge.LimitsEnabled = true
        hinge.LowerAngle = loAng
        hinge.UpperAngle = upAng
        hinge.Attachment0 = hp0_att
        hinge.Attachment1 = hp1_att
    end

    local function createBallJoint(mdl: Model, joint: Motor6D, limit: number, rotVec: Vector3?)
        local ballsocket = Instance.new("BallSocketConstraint", mdl)
        local hp0_att = Instance.new("Attachment", joint.Part0)
        local hp1_att = Instance.new("Attachment", joint.Part1)
        local rf = rotVec and rotVec or VEC3_ZERO

        hp0_att.CFrame = joint.C0
        hp1_att.CFrame = joint.C1
        hp0_att.CFrame *= CFrame.Angles(rf.X, rf.Y, rf.Z)
        hp1_att.WorldCFrame = hp0_att.WorldCFrame
        ballsocket.LimitsEnabled = true
        ballsocket.TwistLimitsEnabled = true
        ballsocket.MaxFrictionTorque = 0
        ballsocket.UpperAngle = limit
        ballsocket.TwistLowerAngle = -180
        ballsocket.TwistUpperAngle = 180
        ballsocket.Attachment0 = hp0_att
        ballsocket.Attachment1 = hp1_att
    end

    assert(character.PrimaryPart, "Character has no primary part")
    if (not joints) then error("Joints were not initialized") end

    local vertOffs = VEC3_UP * SCAN_Y_OFFS
    local primaryPart = character.PrimaryPart
    -- fl
    --local fl_paw = character[PART_NAMES.FL_PAW] :: BasePart
    local fl_wrist = character[PART_NAMES.FL_WRIST] :: BasePart
    local fl_bicep = character[PART_NAMES.FL_BICEP] :: BasePart
    -- fr
    --local fr_paw = character[PART_NAMES.FL_PAW] :: BasePart
    local fr_wrist = character[PART_NAMES.FR_WRIST] :: BasePart
    local fr_bicep = character[PART_NAMES.FR_BICEP] :: BasePart
    -- rl
    --local rl_paw = character[PART_NAMES.RL_PAW] :: BasePart
    local rl_ankle = character[PART_NAMES.RL_ANKLE] :: BasePart
    local rl_thigh = character[PART_NAMES.RL_THIGH] :: BasePart
    -- rr
    --local rr_paw = character[PART_NAMES.RR_PAW] :: BasePart
    local rr_ankle = character[PART_NAMES.RR_ANKLE] :: BasePart
    local rr_thigh = character[PART_NAMES.RR_THIGH] :: BasePart

    -- offsets from root part
    local fl_poleOffs = BASE_POLE_OFFSETS[PART_NAMES.FL_WRIST]
    local fr_poleOffs = BASE_POLE_OFFSETS[PART_NAMES.FR_WRIST]
    local rl_poleOffs = BASE_POLE_OFFSETS[PART_NAMES.RL_ANKLE]
    local rr_poleOffs = BASE_POLE_OFFSETS[PART_NAMES.RR_ANKLE]

    local fl_sens = createOffsetAttOnInst(primaryPart, fl_wrist.Position + vertOffs)
    local fr_sens = createOffsetAttOnInst(primaryPart, fr_wrist.Position + vertOffs)
    local rl_sens = createOffsetAttOnInst(primaryPart, rl_ankle.Position + vertOffs)
    local rr_sens = createOffsetAttOnInst(primaryPart, rr_ankle.Position + vertOffs)

    local fl_targ = createOffsetAttOnInst(primaryPart, fl_wrist.Position)
    local fr_targ = createOffsetAttOnInst(primaryPart, fr_wrist.Position)
    local rl_targ = createOffsetAttOnInst(primaryPart, rl_ankle.Position)
    local rr_targ = createOffsetAttOnInst(primaryPart, rr_ankle.Position)

    local fl_pole = createOffsetAttOnInst(primaryPart, primaryPart.Position + fl_poleOffs)
    local fr_pole = createOffsetAttOnInst(primaryPart, primaryPart.Position + fr_poleOffs)
    local rl_pole = createOffsetAttOnInst(primaryPart, primaryPart.Position + rl_poleOffs)
    local rr_pole = createOffsetAttOnInst(primaryPart, primaryPart.Position + rr_poleOffs)
    fl_pole.Name = "fl_pole"; fr_pole.Name = "fr_pole"; rl_pole.Name = "rl_pole"; rr_pole.Name = "rr_pole"

    local fl_ik = createIKControl(character, PART_NAMES.FL_WRIST)
    local fr_ik = createIKControl(character, PART_NAMES.FR_WRIST)
    local rl_ik = createIKControl(character, PART_NAMES.RL_ANKLE)
    local rr_ik = createIKControl(character, PART_NAMES.RR_ANKLE)

    legSensAttTbl = {}
    legSensAttTbl[PART_NAMES.FL_WRIST] = fl_sens
    legSensAttTbl[PART_NAMES.FR_WRIST] = fr_sens
    legSensAttTbl[PART_NAMES.RL_ANKLE] = rl_sens
    legSensAttTbl[PART_NAMES.RR_ANKLE] = rr_sens

    for nameInd: string, sens: Attachment in pairs(legSensAttTbl) do
        sens.WorldCFrame = primaryPart.CFrame * CFrame.new(BASE_SENSOR_OFFSETS[nameInd])
    end

    legTargetAttTbl = {}
    legTargetAttTbl[PART_NAMES.FL_WRIST] = fl_targ
    legTargetAttTbl[PART_NAMES.FR_WRIST] = fr_targ
    legTargetAttTbl[PART_NAMES.RL_ANKLE] = rl_targ
    legTargetAttTbl[PART_NAMES.RR_ANKLE] = rr_targ

    -- legRootRelativeAttTbl = {}
    -- legRootRelativeAttTbl[PART_NAMES.FL_WRIST] = fl_rootRel
    -- legRootRelativeAttTbl[PART_NAMES.FR_WRIST] = fr_rootRel
    -- legRootRelativeAttTbl[PART_NAMES.RL_ANKLE] = rl_rootRel
    -- legRootRelativeAttTbl[PART_NAMES.RR_ANKLE] = rr_rootRel

    iKControlTbl = {}
    iKControlTbl[PART_NAMES.FL_WRIST] = fl_ik
    iKControlTbl[PART_NAMES.FR_WRIST] = fr_ik
    iKControlTbl[PART_NAMES.RL_ANKLE] = rl_ik
    iKControlTbl[PART_NAMES.RR_ANKLE] = rr_ik

    local rot_y_180 = Vector3.new(0, RAD_180, 0)
    local rot_yz_l = Vector3.new(0, RAD_180, RAD_90)
    local rot_yz_r = Vector3.new(0, RAD_180, -RAD_90)
    createBallJoint(character, joints[JOINT_NAMES.FL_LEG_0], 10, rot_y_180)
    createHingeJoint(character, joints[JOINT_NAMES.FL_LEG_1], 0, 170)
    createHingeJoint(character, joints[JOINT_NAMES.FL_LEG_2], -180, 5)
    createBallJoint(character, joints[JOINT_NAMES.FL_PAW], 12, rot_yz_l)

    createBallJoint(character, joints[JOINT_NAMES.FR_LEG_0], 10)
    createHingeJoint(character, joints[JOINT_NAMES.FR_LEG_1], 0, 170)
    createHingeJoint(character, joints[JOINT_NAMES.FR_LEG_2], -180, 5)
    createBallJoint(character, joints[JOINT_NAMES.FR_PAW], 12, rot_yz_l)

    createBallJoint(character, joints[JOINT_NAMES.RL_LEG_0], 6.5, rot_y_180)
    createHingeJoint(character, joints[JOINT_NAMES.RL_LEG_1], -65, 0)
    createHingeJoint(character, joints[JOINT_NAMES.RL_LEG_2], -180, 5)
    createBallJoint(character, joints[JOINT_NAMES.RL_PAW], 12, rot_yz_r)

    createBallJoint(character, joints[JOINT_NAMES.RR_LEG_0], 6.5)
    createHingeJoint(character, joints[JOINT_NAMES.RR_LEG_1], -65, 0)
    createHingeJoint(character, joints[JOINT_NAMES.RR_LEG_2], -180, 5)
    createBallJoint(character, joints[JOINT_NAMES.RR_PAW], 12, rot_yz_r)

    -- config IKControls
    for _, ik: IKControl in pairs(iKControlTbl) do
        ik.Type = Enum.IKControlType.Position
        ik.SmoothTime = IK_CONTROL_SMOOTH_TIME
        ik.Weight = 0
    end

    -- offset targets
    for nameId: string, targ: Attachment in pairs(legTargetAttTbl) do
        targ.WorldCFrame *= CFrame.new(TARGET_OFFSETS[nameId])
    end

    fl_ik.EndEffector = fl_wrist
    fl_ik.ChainRoot = fl_bicep
    fl_ik.Pole = fl_pole
    fl_ik.Target = fl_targ

    fr_ik.EndEffector = fr_wrist
    fr_ik.ChainRoot = fr_bicep
    fr_ik.Pole = fr_pole
    fr_ik.Target = fr_targ

    rl_ik.EndEffector = rl_ankle
    rl_ik.ChainRoot = rl_thigh
    rl_ik.Pole = rl_pole
    rl_ik.Target = rl_targ

    rr_ik.EndEffector = rr_ankle
    rr_ik.ChainRoot = rr_thigh
    rr_ik.Pole = rr_pole
    rr_ik.Target = rr_targ
end

------------------------------------------------------------------------------------------------------------------------

-- Calculates foot-planting, playermodel root offset and rotation from 4 contact points
local function calcDynamicModelTransforms(grounded: boolean)

    if (not (plrMdlRoot and legSensAttTbl and legTargetAttTbl and iKControlTbl)) then
        error("IK rig not initialized")
    end
    assert(character, "No character")
    assert(character.PrimaryPart, "No primary part")

    local primaryPart = character.PrimaryPart
    local posMap = {} :: {[string]: Vector3}
    local posArr = {} :: {Vector3}
    local posYArr = {} :: {number}
    local lowestGndPosY = math.huge

    local jRoot = joints[JOINT_NAMES.ROOT] :: Motor6D

    -- update model ground offset
    for nameInd: string, sensAtt: Attachment in pairs(legSensAttTbl) do

        local ray = Workspace:Raycast(
            sensAtt.WorldPosition, -VEC3_UP * CAST_DIST, raycastParams
        ) :: RaycastResult

        -- determine pos vector and offset with limits
        local castPosY = sensAtt.WorldPosition.Y
        local newGndPosY = castPosY - SCAN_RANGE_MAX
        -- shoulder relative offset of the sensors for determining max and min leg height
        local rootJoint = joints[JOINT_NAMES.ROOT]
        local currSensOffsCF = CFrame.new(BASE_SENSOR_OFFSETS[nameInd])
        local rootRelShoulderCF = (rootJoint.Part0.CFrame * rootJoint.C0) * currSensOffsCF
        local defaulLegHeight = primaryPart.Position.Y - SCAN_HIP_HEIGHT

        if (ray) then
            if (ray.Distance < SCAN_RANGE_MAX) then
                newGndPosY = ray.Position.Y
                if (ray.Position.Y > (rootRelShoulderCF.Position.Y - SHOULDER_RANGE)) then
                    newGndPosY = rootRelShoulderCF.Position.Y - SHOULDER_RANGE
                end
            else
                newGndPosY = defaulLegHeight
            end
        else
            newGndPosY = defaulLegHeight
        end
        if (newGndPosY < lowestGndPosY) then
            lowestGndPosY = newGndPosY
        end

        local newGndPosVec = Vector3.new(sensAtt.WorldPosition.X, newGndPosY, sensAtt.WorldPosition.Z)
        posMap[nameInd] = newGndPosVec
        posArr[#posArr + 1] = newGndPosVec
        posYArr[#posYArr + 1] = newGndPosY

        local targetYOffset = newGndPosY + TARGET_OFFSETS[nameInd].Y

        -- set position of target attachment
        local targetAtt = legTargetAttTbl[nameInd]
        targetAtt.WorldPosition = Vector3.new(
            targetAtt.WorldPosition.X, targetYOffset, targetAtt.WorldPosition.Z
        )

        -- set relative orientation of current foot joint
        -- TODO: make feet align angle limited with normal
        local jFoot = joints[FOOT_JOINT_MAP[nameInd]]
        local jFootPart0CF = jFoot.Part0.CFrame
        local jointWorldCF = jFootPart0CF * jFoot.C0 -- world space CF
        local primPartLookVec = primaryPart.CFrame.LookVector
        local right = primPartLookVec:Cross(VEC3_UP)
        local up = right:Cross(primPartLookVec)

        local newJFootWorldCF = CFrame.fromMatrix(
            jointWorldCF.Position, right, up, -primPartLookVec
        )
        jFoot.C0 = jFootPart0CF:ToObjectSpace(newJFootWorldCF)
    end

    if (#posYArr < 4) then warn("Missing posArr entries"); return end

    -- setup a plane without z-axis bank, if enabled
    local planePointsArr: {Vector3}
    if (USE_LOWEST_PLANE) then
        local fl_vec = posMap[PART_NAMES.FL_WRIST]
        local fr_vec = posMap[PART_NAMES.FR_WRIST]
        local rl_vec = posMap[PART_NAMES.RL_ANKLE]
        local rr_vec = posMap[PART_NAMES.RR_ANKLE]
        local leftSideTotal = math.abs(fl_vec.Y - rl_vec.Y)
        local rightSideTotal = math.abs(rl_vec.Y - rr_vec.Y)
        planePointsArr = {fl_vec, fr_vec, rl_vec, rr_vec}

        if (leftSideTotal <= rightSideTotal) then
            local new_fr_vec = Vector3.new(fr_vec.X, fl_vec.Y, fr_vec.Z)
            local new_rr_vec = Vector3.new(rr_vec.X, rl_vec.Y, rr_vec.Z)
            planePointsArr = {fl_vec, rl_vec, new_fr_vec, new_rr_vec}
        else
            local new_fl_vec = Vector3.new(fl_vec.X, fr_vec.Y, fl_vec.Z)
            local new_rl_vec = Vector3.new(rl_vec.X, rr_vec.Y, rl_vec.Z)
            planePointsArr = {new_fl_vec, new_rl_vec, fr_vec, rr_vec}
        end
    else
        planePointsArr = posArr
    end

    local planeData = MathUtil.avgPlaneFromPoints(planePointsArr)
    local centroid = planeData.centroid
    local normal = planeData.normal
    if (normal == VEC3_ZERO) then warn("Invalid normal vector"); return end

    -- compute joint offset CFrame
    local rootWorldOffsY = primaryPart.Position.Y - (centroid.Y + HIP_HEIGHT)
    rootWorldOffsY = math.clamp(rootWorldOffsY, -MAX_ROOT_OFFS, MAX_ROOT_OFFS)
    local rootWorldOffsetCF = CFrame.new(-VEC3_UP * rootWorldOffsY)

    -- compute slope rotation CFrame
    local rootRightVec = plrMdlRoot.CFrame.RightVector
    local rootLookVec = plrMdlRoot.CFrame.LookVector
    local crossDirVec = (normal:Cross(rootRightVec)).Unit

    local diffAngle = math.atan2(
        (rootLookVec:Cross(crossDirVec)):Dot(rootRightVec),
        rootLookVec:Dot(crossDirVec)
    )
    diffAngle = math.clamp(diffAngle, -MAX_SLOPE_ANGLE, MAX_SLOPE_ANGLE)
    local rootWorldRotCF = CFrame.Angles(diffAngle, 0, 0)

    -- compute total object space CFrame
    local baseRootCF = BASE_C0_JCF[JOINT_NAMES.ROOT]
    local totalTargetRootCF = jRoot.C0:ToObjectSpace(jRoot.C0 * rootWorldOffsetCF * rootWorldRotCF)
    if (not grounded) then
        totalTargetRootCF = baseRootCF
    end

    -- compute lerp speed
    local horiVel = Vector3.new(
        primaryPart.AssemblyLinearVelocity.X, 0, primaryPart.AssemblyLinearVelocity.Z
    ).Magnitude
    math.max(1, horiVel)
    local speedLerpDt =  (1 / horiVel)
    speedLerpDt = math.clamp(speedLerpDt, 0.001, 0.05)

    -- apply root transform
    jRoot.C0 = jRoot.C0:Lerp(totalTargetRootCF, speedLerpDt)
end

------------------------------------------------------------------------------------------------------------------------
-- Local update
------------------------------------------------------------------------------------------------------------------------

local function update(dt: number)
    local stateId = simulation:getCurrentStateId()
    --local normal = simulation:getNormal()
    local grounded = simulation:getIsGrounded()
    local primaryPart = character.PrimaryPart

    -- disconnect if the character RootPart stops existing
    if (not plrMdlRoot) then
        warn("No playermodel root found");
        (connections.updateConn :: RBXScriptConnection):Disconnect(); return
    end

    -- update body and tail bending
    do
        local rotSpeedY = primaryPart.AssemblyAngularVelocity.Y * 0.045
        rotSpeedY = math.clamp(rotSpeedY, -1, 1)
        if (math.abs(rotSpeedY) < 0.01) then
            rotSpeedY = 0
        end

        local rotVec = Vector3.new(0, rotSpeedY)

        local torso0 = joints[JOINT_NAMES.TORSO_0] :: Motor6D
        local torso1 = joints[JOINT_NAMES.TORSO_1] :: Motor6D
        local tail0 = joints[JOINT_NAMES.TAIL_0] :: Motor6D
        local tail1 = joints[JOINT_NAMES.TAIL_1] :: Motor6D
        local neck0 = joints[JOINT_NAMES.NECK_0] :: Motor6D

        torso0.C0 = lerpJointAnglesCF(torso0.C0, BASE_C0_JCF[JOINT_NAMES.TORSO_0], rotVec)
        torso1.C0 = lerpJointAnglesCF(torso1.C0, BASE_C0_JCF[JOINT_NAMES.TORSO_1], -rotVec)
        tail0.C0 = lerpJointAnglesCF(tail0.C0, BASE_C0_JCF[JOINT_NAMES.TAIL_0], -rotVec * 1.175)
        tail1.C0 = lerpJointAnglesCF(tail1.C0, BASE_C0_JCF[JOINT_NAMES.TAIL_1], -rotVec * 0.85)
        neck0.C0 = lerpJointAnglesCF(neck0.C0, BASE_C0_JCF[JOINT_NAMES.NECK_0], rotVec)
    end

    -- foot-planting
    if (stateId == PlayerStateId.GROUNDED) then
        local assemblyLinVelFac = math.max(1, primaryPart.AssemblyLinearVelocity.Magnitude * 1.45)
        local weight = math.clamp((1 / assemblyLinVelFac), 0, 1)
        if (weight < 0.1 or not grounded) then
            weight = 0
        end

        for _, ikc: IKControl in pairs(iKControlTbl) do
            ikc.Weight = weight
        end

        -- heavy lifting happens here
        calcDynamicModelTransforms(grounded)
    end

    -- lerp CFrame targets for each existing other player's character
    do
        for plr: Player, plrChar: Model in pairs(plrCharTbl) do
            if (not (plrChar and plrTargetDataTbl[plr])) then
                continue
            end

            local posOffset = plrTargetDataTbl[plr].posOffset
            local cFrameArr = plrTargetDataTbl[plr].cFrameArr

            if (not (posOffset and cFrameArr)) then
                continue
            end

            local plrJFolder = plrChar[CHAR_JOINTS_FOLDER_NAME] :: Folder
            if (typeof(plrJFolder) ~= "Instance" and not plrJFolder:IsA("Folder")) then
                warn(`{plr.Name} has no joints folder`); continue
            end

            for i, j_name: string in JOINT_INDEX_ARR do
                local joint = plrJFolder:FindFirstChild(JOINT_NAMES[j_name]) :: Motor6D
                if (not joint) then
                    break
                end
                joint.C0 = joint.C0:Lerp((CFrame.new(joint.C0.Position) * cFrameArr[i]), NET_LERP_DT)
            end
            local jRoot = plrJFolder:FindFirstChild(JOINT_NAMES.ROOT) :: Motor6D
            jRoot.C0 = jRoot.C0:Lerp(CFrame.new(posOffset), NET_LERP_DT)
        end
    end

    if (eventTime >= EVENT_DT) then
        eventTime = 0
        local posOffs, packQuatArr = packJointData()
        CliNetApi.fastEvents[Network.clientFastEvents.jointsDataToServer]:FireServer(posOffs, packQuatArr)
    end
    eventTime += dt
end

-- Disconnects connections of a given player
local function disconnectPlrCharConnections(plr: Player)
    if (plrConnections[plr]) then
        for _, conn: RBXScriptConnection in pairs(plrConnections[plr]) do
            conn:Disconnect()
        end
    end
end

-- Disconnects connection of a given player if they exist and registeres the new ones
local function registerPlrCharConnections(plr: Player, charAC: RBXScriptConnection, charRC: RBXScriptConnection)
    disconnectPlrCharConnections(plr)
    plrConnections[plr] = {
        charAddedConn = charAC,
        charRemovingConn = charRC
    }
end

------------------------------------------------------------------------------------------------------------------------
-- Module functions
------------------------------------------------------------------------------------------------------------------------

-- Initializes this module or resets it, if initialized before
function DynamicAnim.init()

    local function onLocalCharacterAdded(newChar: Model)
        local newPlrMdlRoot = newChar:FindFirstChild(CharacterDef.PLAYERMDL_ROOTPART_NAME)
        if (not (newPlrMdlRoot and newPlrMdlRoot:IsA("BasePart"))) then
            error("Playermodel root not found or is not a BasePart")
        end

        character = newChar
        plrMdlRoot = newPlrMdlRoot
        joints = getJoints()

        raycastParams:AddToFilter(character:GetDescendants())
        createCharacterIKRig(character)

        connections.updateConn = RunService.PreAnimation:Connect(function(dt: number)
            update(dt)
        end)
    end

    local function onLocalCharacterRemoving(char: Model)
        -- reset the module
        DynamicAnim.init()
    end

    -- global players

    local function onCharacterAdded(plr: Player, newChar: Model)
        if (not newChar.PrimaryPart) then
            warn(`{plr.Name}'s character has no primary part`); return
        end
        plrCharTbl[plr] = newChar
    end

    local function onCharacterRemoving(plr: Player, char: Model)
        plrCharTbl[plr] = nil
    end

    local function onPlayerAdded(plr: Player)
        -- only register other players
        if (plr == Players.LocalPlayer) then
            return
        end
        local plrCharAddedConn = plr.CharacterAdded:Connect(function(newChar: Model)
            onCharacterAdded(plr, newChar)
        end)
        local plrCharRemovingConn = plr.CharacterRemoving:Connect(function(char: Model)
            onCharacterRemoving(plr, char)
        end)
        registerPlrCharConnections(plr, plrCharAddedConn, plrCharRemovingConn)

        if (plr.Character) then
            onCharacterAdded(plr, plr.Character)
        end
    end

    local function onPlayerRemoving(plr: Player)
        disconnectPlrCharConnections(plr)
        plrConnections[plr] = nil
        plrTargetDataTbl[plr] = nil
        plrCharTbl[plr] = nil
    end

    -- disconnect existing connections
    for _, conn: RBXScriptConnection in pairs(connections) do
        if (conn) then
            conn:Disconnect()
        end
    end

    connections.charAddedConn = Players.LocalPlayer.CharacterAdded:Connect(onLocalCharacterAdded)
    connections.charRemovingConn = Players.LocalPlayer.CharacterRemoving:Connect(onLocalCharacterRemoving)

    connections.plrAddedConn = Players.PlayerAdded:Connect(onPlayerAdded)
    connections.plrRemovingConn = Players.PlayerRemoving:Connect(onPlayerRemoving)

    for _, plr: Player in pairs(Players:GetChildren()) do
        onPlayerAdded(plr)
    end

    Global.logInfo("Initialized dynamic animations module")
end

-- Updates the joints of other players' models. Should be called after each joint update event
function DynamicAnim.updatePlrJointsFromData(plr:Player, dataString: string)
    if (plr == Players.LocalPlayer) then
        return
    end

    local character = plr.Character
    if (not (character and character.PrimaryPart)) then
        warn(`{plr.Name} has no valid character`); return
    end
    -- local jointFolder = character[CHAR_JOINTS_FOLDER_NAME] :: Folder
    -- if (typeof(jointFolder) ~= "Instance" and not jointFolder:IsA("Folder")) then
    --     warn(`{plr.Name} has no joints folder`); return
    -- end

    local posOffset, cFrameArr = unpackJointData(dataString)

    -- for i, j_name: string in JOINT_INDEX_ARR do
    --     local joint = jointFolder:FindFirstChild(JOINT_NAMES[j_name]) :: Motor6D
    --     if (not joint) then
    --         return
    --     end
    --    joint.C0 = CFrame.new(joint.C0.Position) * cFrameArr[i]
    -- end
    -- local jRoot = jointFolder:FindFirstChild(JOINT_NAMES.ROOT) :: Motor6D
    -- jRoot.C0 = CFrame.new(posOffset)

    plrTargetDataTbl[plr] = {
        posOffset = posOffset,
        cFrameArr = cFrameArr
    }
end

return DynamicAnim