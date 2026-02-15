--[[
    Dynamic animation logic for the playermodel:
    body rotation, foot-planting, head movement, etc.
]]

local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local REPLICATION_DELTA = 0.05 -- time interval between event calls (0.05 sec ~ 20 FPS)
local MAX_SLOPE_ANGLE = math.rad(30)
local VEC3_ZERO = Vector3.zero
local LERP_DT = 0.1

------------------------------------------------------------------------------------------------------------------------
-- Module and server data
------------------------------------------------------------------------------------------------------------------------

local DynamicAnim = {
    DATA_PACK_BYTES = DATA_PACK_BYTES
}
if (RunService:IsServer()) then
    return DynamicAnim
end

------------------------------------------------------------------------------------------------------------------------
-- Client
------------------------------------------------------------------------------------------------------------------------

-- Client requires
local Global = require(ReplicatedStorage.Shared.Global)
local Controller = require(ReplicatedStorage.Shared.CatController)
local PlayerStateId = require(ReplicatedStorage.Shared.Enums.PlayerStateId)
local Network = require(ReplicatedStorage.Shared.Network)
local CliNetApi = require(ReplicatedStorage.Shared.GameClient.CliNetApi)
local MathUtil = require(ReplicatedStorage.Shared.Util.MathUtil)

-- non character attached playermodel
local templatePlayermdl = StarterPlayer:FindFirstChild("PlayerModel"):Clone()
local baseJointsFolder = templatePlayermdl:FindFirstChild(CHAR_JOINTS_FOLDER_NAME)

-- default joint object-space CFrame offsets
local BASE_J_CF = table.freeze({
    root_c0 = baseJointsFolder:FindFirstChild(JOINT_NAMES.ROOT).C0,
    root_c1 = baseJointsFolder:FindFirstChild(JOINT_NAMES.ROOT).C1,
    torso0_c0 = baseJointsFolder:FindFirstChild(JOINT_NAMES.TORSO_0).C0,
    torso1_c0 = baseJointsFolder:FindFirstChild(JOINT_NAMES.TORSO_1).C0,
    neck0_c0 = baseJointsFolder:FindFirstChild(JOINT_NAMES.NECK_0).C0,
    tail0_c0 = baseJointsFolder:FindFirstChild(JOINT_NAMES.TAIL_0).C0,
    tail1_c0 = baseJointsFolder:FindFirstChild(JOINT_NAMES.TAIL_1).C0,
}) :: {[string]: CFrame}

local simulation = Controller:getSimulation()

-- initialized when init is called
local character: Model
local plrMdlRoot: BasePart
local joints: {[string]: Motor6D}
local connections = {
    updateConn = nil,
    charAddedConn = nil,
    charRemovingConn = nil,
    plrAddedConn = nil,
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
            error("Motor6D instance not found for string " .. n)
        end
    end
    return newJoints
end

-- compress root offset and joint rotations data into string
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

------------------------------------------------------------------------------------------------------------------------
-- Local update
------------------------------------------------------------------------------------------------------------------------

local function update(dt: number)
    local stateId = simulation:getCurrentStateId()
    local normal = simulation:getNormal()
    local primaryPart = character.PrimaryPart

    -- disconnect if the character RootPart stops existing
    if (not plrMdlRoot) then
        (connections.updateConn :: RBXScriptConnection):Disconnect(); return
    end

    -- update root rotation
    if (stateId == PlayerStateId.GROUNDED) then
        if (normal ~= VEC3_ZERO) then
            local root = joints[JOINT_NAMES.ROOT] :: Motor6D

            local rootRightVec = plrMdlRoot.CFrame.RightVector
            local rootLookVec = plrMdlRoot.CFrame.LookVector
            local crossDirVec = (normal:Cross(rootRightVec)).Unit

            local diffAngle = math.atan2(
                (rootLookVec:Cross(crossDirVec)):Dot(rootRightVec),
                rootLookVec:Dot(crossDirVec)
            )
            diffAngle = math.clamp(diffAngle, -MAX_SLOPE_ANGLE, MAX_SLOPE_ANGLE)
            local newRootCF = BASE_J_CF.root_c0 * CFrame.Angles(diffAngle, 0, 0)

            root.C0 = root.C0:Lerp(newRootCF, LERP_DT)
        end
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

        torso0.C0 = lerpJointAnglesCF(torso0.C0, BASE_J_CF.torso0_c0, rotVec)
        torso1.C0 = lerpJointAnglesCF(torso1.C0, BASE_J_CF.torso1_c0, -rotVec)
        tail0.C0 = lerpJointAnglesCF(tail0.C0, BASE_J_CF.tail0_c0, -rotVec * 1.175)
        tail1.C0 = lerpJointAnglesCF(tail1.C0, BASE_J_CF.tail1_c0, -rotVec * 0.85)
        neck0.C0 = lerpJointAnglesCF(neck0.C0, BASE_J_CF.neck0_c0, rotVec)
    end

    -- TODO: footplanting

    if (eventTime >= REPLICATION_DELTA) then
        eventTime = 0
        local posOffs, packQuatArr = packJointData()
        CliNetApi.fastEvents[Network.clientFastEvents.jointsDataToServer]:FireServer(posOffs, packQuatArr)
    end
    eventTime += dt
end

local function disconnectAllConnections()
    for _, conn: RBXScriptConnection in pairs(connections) do
        if (conn) then
            conn:Disconnect()
        end
    end
end

local function createPlrConnections(plr: Player, charAC: RBXScriptConnection, charRC: RBXScriptConnection)
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

    local function onCharacterAdded(newChar: Model)
        local newPlrMdlRoot = newChar:FindFirstChild(CharacterDef.PLAYERMDL_ROOTPART_NAME)
        if (not (newPlrMdlRoot and newPlrMdlRoot:IsA("BasePart"))) then
            error("Playermodel root not found or is not a BasePart")
        end

        character = newChar
        plrMdlRoot = newPlrMdlRoot
        joints = getJoints()

        connections.updateConn = RunService.PreAnimation:Connect(function(dt: number)
            update(dt)
        end)
    end

    local function onCharacterRemoving(char: Model)
        disconnectAllConnections()
        DynamicAnim.init()
    end

    -- disconnect existing connections
    for _, conn: RBXScriptConnection in pairs(connections) do
        if (conn) then
            conn:Disconnect()
        end
    end

    connections.charAddedConn = Players.LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
    connections.charRemovingConn = Players.LocalPlayer.CharacterRemoving:Connect(onCharacterRemoving)
    connections.plrAddedConn = Players.PlayerAdded:Connect(function(plr: Player)
        --plr.CharacterAdded:Connect()
    end)

    for _, p: Player in pairs(Players:GetChildren()) do
        
    end

    Global.logInfo("Initialized dynamic animations module")
end

-- Updates the joints of other players' models. Should be called after each joint update event
function DynamicAnim.updatePlrJointsFromData(plr:Player, dataString: string)
    if (plr == Players.LocalPlayer) then 
        return 
    end

    local character = plr.Character
    if (not character) then
        warn(`{plr.Name} has no character`); return
    end
    local jointFolder = character[CHAR_JOINTS_FOLDER_NAME] :: Folder
    if (typeof(jointFolder) ~= "Instance" and not jointFolder:IsA("Folder")) then
        warn(`{plr.Name} has no joints folder`); return
    end

    local posOffset, rotCFrameArr = unpackJointData(dataString)

    for i, j_name: string in JOINT_INDEX_ARR do
        local joint = jointFolder:FindFirstChild(JOINT_NAMES[j_name]) :: Motor6D
        if (not joint) then
            return
        end
        joint.C0 = CFrame.new(joint.C0.Position) * rotCFrameArr[i]
    end
    local jRoot = jointFolder:FindFirstChild(JOINT_NAMES.ROOT) :: Motor6D
    jRoot.C0 = CFrame.new(posOffset)
end

return DynamicAnim