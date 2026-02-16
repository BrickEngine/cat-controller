--[[
    Dynamic animation logic for the playermodel:
    body rotation, foot-planting, head movement, etc.
]]

local PartyEmulatorService = game:GetService("PartyEmulatorService")
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
local FOOT_FLOOR_OFFS = 0.47

local SCAN_Y_OFFS = 1.5
local CAST_DIST = CharacterDef.PARAMS.LEGCOLL_SIZE.X * 3
local HIP_HEIGHT = CharacterDef.PARAMS.LEGCOLL_SIZE.X
local SCAN_HIP_HEIGHT = CharacterDef.PARAMS.LEGCOLL_SIZE.X + SCAN_Y_OFFS
local SCAN_HIP_RANGE_MAX = CharacterDef.PARAMS.LEGCOLL_SIZE.X + 4.5 + SCAN_Y_OFFS
local SCAN_HIP_RANGE_MIN = 0.35 + SCAN_Y_OFFS
local HIP_OFFS = 0.4

local EVENT_DT = 0.025 -- time interval between event calls (0.025 sec ~ 40 FPS)
local MAX_SLOPE_ANGLE = math.rad(45)
local BALL_JOINT_ANG_LIM = 0--1.2
local LERP_DT = 0.07
local NET_LERP_DT = 0.5 -- lerp for other players

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

-- offsets for the foot-planting scan point (from the root bone)
local BASE_JOINT_OFFSETS = table.freeze({
    [PART_NAMES.FL_WRIST] = Vector3.new(-0.327, SCAN_Y_OFFS, -1.3),
    [PART_NAMES.FR_WRIST] = Vector3.new(0.327, SCAN_Y_OFFS, -1.3),
    [PART_NAMES.RL_ANKLE] = Vector3.new(-0.349, SCAN_Y_OFFS, 1.876),
    [PART_NAMES.RR_ANKLE] = Vector3.new(0.349, SCAN_Y_OFFS, 1.876),
})

-- local LEG_PART_JOINT_MAP = table.freeze({
--     [PART_NAMES.FL_WRIST] = JOINT_NAMES.FL_PAW,
--     [PART_NAMES.FR_WRIST] = JOINT_NAMES.FR_PAW,
--     [PART_NAMES.RL_ANKLE] = JOINT_NAMES.RL_PAW,
--     [PART_NAMES.RR_ANKLE] = JOINT_NAMES.RR_PAW,
-- })

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
    -- if (offsVec.Magnitude > 2.4 or #numArr < NUM_PACKED_NUMBERS + 2) then 
    --     invalidData = true 
    -- end
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
        cf:Lerp(cf_base * CFrame.fromEulerAnglesXYZ(rVec.X, rVec.Y, rVec.Z), LERP_DT)
    )
end

-- Attaches IKControl components and physical constraints to the character rig for foot-planting simulation
local function createOffsetAttOnInst(inst: Instance, offset: Vector3, isRelToPart: boolean?): Attachment
    local att = Instance.new("Attachment", inst)
    att.Name = "RigAtt"
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

    local function createHingeJoint(mdl: Model, joint: Motor6D, rotFac: number?)
        local constraint = Instance.new("BallSocketConstraint", mdl)
        local hp0_att = Instance.new("Attachment", joint.Part0)
        local hp1_att = Instance.new("Attachment", joint.Part1)
        local rf = rotFac and rotFac or 0
        
        hp0_att.CFrame = joint.C0
        hp1_att.CFrame = joint.C1
        hp0_att.CFrame *= CFrame.Angles(0, rf, 0)
        hp1_att.CFrame *= CFrame.Angles(0, rf, 0)
        constraint.LimitsEnabled = true
        constraint.Restitution = 1
        constraint.MaxFrictionTorque = 0
        constraint.UpperAngle = BALL_JOINT_ANG_LIM
        constraint.Attachment0 = hp0_att
        constraint.Attachment1 = hp1_att
    end

    assert(character.PrimaryPart, "Character has no primary part")
    if (not joints) then error("Joints were not initialized") end

    local vertOffs = VEC3_UP * 2.2
    local primaryPart = character.PrimaryPart
    local fl_poleOffs = BASE_JOINT_OFFSETS[PART_NAMES.FL_WRIST] + Vector3.new(0, -1.2, 2)
    local fr_poleOffs = BASE_JOINT_OFFSETS[PART_NAMES.FR_WRIST] + Vector3.new(0, -1.2, 2)
    local rl_poleOffs = BASE_JOINT_OFFSETS[PART_NAMES.RL_ANKLE] + Vector3.new(0, -1.2, -2)
    local rr_poleOffs = BASE_JOINT_OFFSETS[PART_NAMES.RR_ANKLE] + Vector3.new(0, -1.2, -2)
    -- fl
    local fl_wrist = character[PART_NAMES.FL_WRIST] :: BasePart
    local fl_arm = character[PART_NAMES.FL_ARM] :: BasePart
    local fl_bicep = character[PART_NAMES.FL_BICEP] :: BasePart
    -- fr
    local fr_wrist = character[PART_NAMES.FR_WRIST] :: BasePart
    local fr_arm = character[PART_NAMES.FR_ARM] :: BasePart
    local fr_bicep = character[PART_NAMES.FR_BICEP] :: BasePart
    -- rl
    local rl_ankle = character[PART_NAMES.RL_ANKLE] :: BasePart
    local rl_leg = character[PART_NAMES.RL_LEG] :: BasePart
    local rl_thigh = character[PART_NAMES.RL_THIGH] :: BasePart
    -- rr
    local rr_ankle = character[PART_NAMES.RR_ANKLE] :: BasePart
    local rr_leg = character[PART_NAMES.RR_LEG] :: BasePart
    local rr_thigh = character[PART_NAMES.RR_THIGH] :: BasePart

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
        sens.WorldCFrame = primaryPart.CFrame * CFrame.new(BASE_JOINT_OFFSETS[nameInd]) 
    end

    legTargetAttTbl = {}
    legTargetAttTbl[PART_NAMES.FL_WRIST] = fl_targ
    legTargetAttTbl[PART_NAMES.FR_WRIST] = fr_targ
    legTargetAttTbl[PART_NAMES.RL_ANKLE] = rl_targ
    legTargetAttTbl[PART_NAMES.RR_ANKLE] = rr_targ

    iKControlTbl = {}
    iKControlTbl[PART_NAMES.FL_WRIST] = fl_ik
    iKControlTbl[PART_NAMES.FR_WRIST] = fr_ik
    iKControlTbl[PART_NAMES.RL_ANKLE] = rl_ik
    iKControlTbl[PART_NAMES.RR_ANKLE] = rr_ik

    local invAng = math.rad(180)
    createHingeJoint(character, joints[JOINT_NAMES.FL_LEG_0], invAng)
    createHingeJoint(character, joints[JOINT_NAMES.FL_LEG_1])
    createHingeJoint(character, joints[JOINT_NAMES.FL_LEG_2])
    createHingeJoint(character, joints[JOINT_NAMES.FR_LEG_0])--, invAng)
    createHingeJoint(character, joints[JOINT_NAMES.FR_LEG_1], invAng)
    createHingeJoint(character, joints[JOINT_NAMES.FR_LEG_2], invAng)
    createHingeJoint(character, joints[JOINT_NAMES.RL_LEG_0], invAng)
    createHingeJoint(character, joints[JOINT_NAMES.RL_LEG_1])
    createHingeJoint(character, joints[JOINT_NAMES.RL_LEG_2])
    createHingeJoint(character, joints[JOINT_NAMES.RR_LEG_0])--, invAng)
    createHingeJoint(character, joints[JOINT_NAMES.RR_LEG_1], invAng)
    createHingeJoint(character, joints[JOINT_NAMES.RR_LEG_2], invAng)

    -- config IKControls
    for _, ik: IKControl in pairs(iKControlTbl) do
        ik.Type = Enum.IKControlType.Position
        ik.Weight = 0
    end

    fl_ik.EndEffector = fl_wrist
    fl_ik.ChainRoot = fl_bicep
    --fl_ik.Pole = fl_pole
    fl_ik.Target = fl_targ

    fr_ik.EndEffector = fr_wrist
    fr_ik.ChainRoot = fr_bicep
    --fr_ik.Pole = fr_pole
    fr_ik.Target = fr_targ

    rl_ik.EndEffector = rl_ankle
    rl_ik.ChainRoot = rl_thigh
    --rl_ik.Pole = rl_pole
    rl_ik.Target = rl_targ
    
    rr_ik.EndEffector = rr_ankle
    rr_ik.ChainRoot = rr_thigh
    --rr_ik.Pole = rr_pole
    rr_ik.Target = rr_targ
end

olddebugpartlist = {}
-- Calculates foot-planting, playermodel root offset and rotation from 4 contact points
local function calcDynamicModelTransforms(grounded: boolean)

        for i,v in pairs(olddebugpartlist) do
        if (v) then
            v:Destroy()
        end
    end


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
    for nameInd: string, att: Attachment in pairs(legSensAttTbl) do

        local ray = Workspace:Raycast(
            att.WorldPosition, -VEC3_UP * CAST_DIST, raycastParams
        ) :: RaycastResult

        -- determine pos vector and offset with limits
        local castPosY = att.WorldPosition.Y - HIP_OFFS
        local newGndPosY = castPosY - SCAN_HIP_RANGE_MAX
        if (ray) then
            if (ray.Distance < SCAN_HIP_RANGE_MAX) then
                newGndPosY = ray.Position.Y
            elseif (ray.Distance < SCAN_HIP_RANGE_MIN) then
                newGndPosY = castPosY - SCAN_HIP_RANGE_MIN
            end
        else
            newGndPosY = castPosY - SCAN_HIP_HEIGHT
        end
        if (newGndPosY < lowestGndPosY) then
            lowestGndPosY = newGndPosY
        end

        local newGndPosVec = Vector3.new(att.WorldPosition.X, newGndPosY, att.WorldPosition.Z)
        posMap[nameInd] = newGndPosVec
        posArr[#posArr + 1] = newGndPosVec
        posYArr[#posYArr + 1] = newGndPosY

        local targetAtt = legTargetAttTbl[nameInd]
        local adjTargetPosY = newGndPosY
        -- if (math.abs(adjTargetPosY - att.WorldPosition.Y) > SCAN_HIP_HEIGHT) then
        --     adjTargetPosY = att.WorldPosition.Y - SCAN_HIP_HEIGHT
        -- end
        targetAtt.WorldPosition = Vector3.new(
            targetAtt.WorldPosition.X, adjTargetPosY, targetAtt.WorldPosition.Z
        )

        local function debugpart()
            local p = Instance.new("Part", targetAtt)
            p.CanCollide = false
            p.Size = 0.3 * Vector3.one
            p.CollisionGroup = "PLAYER"
            p.Position = targetAtt.WorldPosition
            olddebugpartlist[#olddebugpartlist + 1] = p
        end
        debugpart()
    end

    if (#posYArr < 4) then warn("Missing posArr entries"); return end

    -- setup a plane without z-axis bank
    -- local fl_vec = posMap[PART_NAMES.FL_WRIST]
    -- local fr_vec = posMap[PART_NAMES.FR_WRIST]
    -- local rl_vec = posMap[PART_NAMES.RL_ANKLE]
    -- local rr_vec = posMap[PART_NAMES.RR_ANKLE]
    -- local leftSideTotal = math.abs(fl_vec.Y - rl_vec.Y)
    -- local rightSideTotal = math.abs(rl_vec.Y - rr_vec.Y)
    -- local planePointsArr = {} :: {Vector3}
    -- planePointsArr = {fl_vec, fr_vec, rl_vec, rr_vec}

    -- if (leftSideTotal <= rightSideTotal) then
    --     local new_fr_vec = Vector3.new(fr_vec.X, fl_vec.Y, fr_vec.Z)
    --     local new_rr_vec = Vector3.new(rr_vec.X, rl_vec.Y, rr_vec.Z)
    --     planePointsArr = {fl_vec, rl_vec, new_fr_vec, new_rr_vec}
    -- else
    --     local new_fl_vec = Vector3.new(fl_vec.X, fr_vec.Y, fl_vec.Z)
    --     local new_rl_vec = Vector3.new(rl_vec.X, rr_vec.Y, rl_vec.Z)
    --     planePointsArr = {new_fl_vec, new_rl_vec, fr_vec, rr_vec}
    -- end

    local planeData = MathUtil.avgPlaneFromPoints(posArr)
    local centroid = lowestGndPosY * VEC3_UP--planeData.centroid
    local normal = planeData.normal
    if (normal == VEC3_ZERO) then warn("Invalid normal vector"); return end

    -- compute joint offset
    local rootWorldOffsY 
        = plrMdlRoot.Position.Y - (centroid.Y + (SCAN_HIP_HEIGHT - SCAN_Y_OFFS) + HIP_OFFS)
    local baseRootOffsCF = BASE_C0_JCF[JOINT_NAMES.ROOT]
    local newRootOffsCF: CFrame
    if (grounded) then
        newRootOffsCF = jRoot.C0:ToObjectSpace(CFrame.new(-VEC3_UP * rootWorldOffsY))
    else
        newRootOffsCF = baseRootOffsCF
    end

    -- adjust leg offsets
    -- for nameInd: string, targetAtt: Attachment in pairs(legTargetAttTbl) do
    --     local newOffs = posMap[nameInd] + FOOT_FLOOR_OFFS + baseRootOffsCF
    --     targetAtt.WorldPosition = Vector3.new(
    --         targetAtt.WorldPosition.X, posMap[nameInd] + FOOT_FLOOR_OFFS, targetAtt.WorldPosition.Z
    --     )
    -- end

    -- compute slope rotation
    local rootRightVec = plrMdlRoot.CFrame.RightVector
    local rootLookVec = plrMdlRoot.CFrame.LookVector
    local crossDirVec = (normal:Cross(rootRightVec)).Unit

    local diffAngle = math.atan2(
        (rootLookVec:Cross(crossDirVec)):Dot(rootRightVec),
        rootLookVec:Dot(crossDirVec)
    )
    if (not grounded) then
        --diffAngle = 0
    end
    diffAngle = math.clamp(diffAngle, -MAX_SLOPE_ANGLE, MAX_SLOPE_ANGLE)
    local newRootCF = baseRootOffsCF * CFrame.Angles(diffAngle, 0, 0)

    jRoot.C0 = jRoot.C0:Lerp(newRootCF * newRootOffsCF, LERP_DT)
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

    -- update root rotation
    -- if (stateId == PlayerStateId.GROUNDED) then
    --     if (normal ~= VEC3_ZERO) then
    --         local root = joints[JOINT_NAMES.ROOT] :: Motor6D

    --         local rootRightVec = plrMdlRoot.CFrame.RightVector
    --         local rootLookVec = plrMdlRoot.CFrame.LookVector
    --         local crossDirVec = (normal:Cross(rootRightVec)).Unit

    --         local diffAngle = math.atan2(
    --             (rootLookVec:Cross(crossDirVec)):Dot(rootRightVec),
    --             rootLookVec:Dot(crossDirVec)
    --         )
    --         diffAngle = math.clamp(diffAngle, -MAX_SLOPE_ANGLE, MAX_SLOPE_ANGLE)
    --         local newRootCF = BASE_C0_JCF[JOINT_NAMES.ROOT] * CFrame.Angles(diffAngle, 0, 0)

    --         root.C0 = root.C0:Lerp(newRootCF, LERP_DT)
    --     end
    -- end

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

    -- footplanting
    if (stateId == PlayerStateId.GROUNDED) then
        local assemblyLinVelFac = math.max(1, primaryPart.AssemblyLinearVelocity.Magnitude * 1.15)
        local weight = math.clamp((1 / assemblyLinVelFac), 0, 1)
        if (weight < 0.1 or not grounded) then 
            weight = 0 
        end
        for _, ikc: IKControl in pairs(iKControlTbl) do
            ikc.Weight = weight
        end
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