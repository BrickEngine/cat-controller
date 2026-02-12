--[[
    Dynamic animation logic for the playermodel:
    body rotation, foot-planting, head movement, etc.
]]

local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controller = require(ReplicatedStorage.Shared.CatController)
local simulation = Controller:getSimulation()

local CHARACTER_ROOT_NAME = "PMRoot"
local MAX_SLOPE_ANGLE = math.rad(30)
local VEC3_ZERO = Vector3.zero
local LERP_DT = 0.1

local JOINT_NAMES = {
    -- torso
    root = "ROOT",
    torso0 = "CHEST",
    torso1 = "HIP",
    --neck
    neck0 = "NECK_0",
    neck1 = "NECK_1",
    -- tail
    tail0 = "TAIL_0",
    tail1 = "TAIL_1",
    tail2 = "TAIL_2",
    tail3 = "TAIL_3",
    tail4 = "TAIL_4",
    tail5 = "TAIL_5",
    tail6 = "TAIL_6",
    -- front left
    fl_leg0 = "FL_LEG_0",
    fl_leg1 = "FL_LEG_1",
    fl_leg2 = "FL_LEG_2",
    fl_paw = "FL_PAW",
    -- front right
    fr_leg0 = "FR_LEG_0",
    fr_leg1 = "FR_LEG_0",
    fr_leg2 = "FR_LEG_0",
    fr_paw = "FR_PAW",
    -- rear left
    rl_leg0 = "RL_LEG_0",
    rl_leg1 = "RL_LEG_0",
    rl_leg2 = "RL_LEG_0",
    rl_paw = "RL_PAW",
    -- rear right
    rr_leg0 = "RR_LEG_0",
    rr_leg1 = "RR_LEG_0",
    rr_leg2 = "RR_LEG_0",
    rr_paw = "RR_PAW"
}

local character = Players.LocalPlayer.Character
local charRoot = character:FindFirstChild(CHARACTER_ROOT_NAME, true) :: BasePart
local mdlRoot = character.PrimaryPart

-- non character attached playermodel
local basePlrMdl = StarterPlayer:FindFirstChild("PlayerModel")
local baseJoints = basePlrMdl:FindFirstChild("CharacterJoints")

-- default joint object-space CFrame offsets
local baseJOffsets = {
    -- root
    root_c0 = baseJoints:FindFirstChild(JOINT_NAMES.root).C0,
    root_c1 = baseJoints:FindFirstChild(JOINT_NAMES.root).C1,
    -- torso
    torso0_c0 = baseJoints:FindFirstChild(JOINT_NAMES.torso0).C0,
    torso1_c1 = baseJoints:FindFirstChild(JOINT_NAMES.torso1).C1,
    -- neck
    neck0_c0 = baseJoints:FindFirstChild(JOINT_NAMES.neck0).C0,
    -- tail
    tail0_c0 = baseJoints:FindFirstChild(JOINT_NAMES.tail0).C0,
    tail1_c0 = baseJoints:FindFirstChild(JOINT_NAMES.tail1).C0,
}

local joints = {} :: {[string]: Motor6D}
for n, str: string in pairs(JOINT_NAMES) do
    local inst = character:FindFirstChild(str, true)
    if (inst :: Motor6D) then
        joints[str] = inst
    else
        error("Motor6D instance not found for string " .. n)
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Update
------------------------------------------------------------------------------------------------------------------------

local function update(dt: number)
    local stateId = simulation:getCurrentStateId()
    local normal = simulation:getNormal()

    -- update root rotation
    if (stateId == 0) then
        if (normal ~= VEC3_ZERO) then
            local rootRightVec = charRoot.CFrame.RightVector
            local rootLookVec = charRoot.CFrame.LookVector
            local crossDirVec = (normal:Cross(rootRightVec)).Unit
            local root = joints[JOINT_NAMES.root]

            local diffAngle = math.atan2(
                (rootLookVec:Cross(crossDirVec)):Dot(rootRightVec),
                rootLookVec:Dot(crossDirVec)
            )
            diffAngle = math.clamp(diffAngle, -MAX_SLOPE_ANGLE, MAX_SLOPE_ANGLE)
            local newRootCF = baseJOffsets.root_c0 * CFrame.Angles(diffAngle, 0, 0)


            root.C0 = root.C0:Lerp(newRootCF, LERP_DT)
            --tweenRotation(newCFrame, joints[JOINT_NAMES.root])
        end
    end

    -- update body and tail bending
    do
        local rotSpeedY = mdlRoot.AssemblyAngularVelocity.Y * 0.045
        rotSpeedY = math.clamp(rotSpeedY, -1, 1)
        if (math.abs(rotSpeedY) < 0.01) then
            rotSpeedY = 0
        end

        local rotVec = Vector3.new(0, rotSpeedY)

        local torso0 = joints[JOINT_NAMES.torso0] :: Motor6D
        local torso1 = joints[JOINT_NAMES.torso1] :: Motor6D
        local tail0 = joints[JOINT_NAMES.tail0] :: Motor6D
        local tail1 = joints[JOINT_NAMES.tail1] :: Motor6D
        local neck0 = joints[JOINT_NAMES.neck0] :: Motor6D

        local function lerpJointAnglesCF(cf: CFrame, cf_base: CFrame, rVec: Vector3) : CFrame
            return cf * cf:ToObjectSpace(
                cf:Lerp(cf_base * CFrame.fromEulerAnglesXYZ(rVec.X, rVec.Y, rVec.Z), LERP_DT)
            )
        end

        torso0.C0 = lerpJointAnglesCF(torso0.C0, baseJOffsets.torso0_c0, rotVec)
        torso1.C1 = lerpJointAnglesCF(torso1.C1, baseJOffsets.torso1_c1, rotVec)
        tail0.C0 = lerpJointAnglesCF(tail0.C0, baseJOffsets.tail0_c0, -rotVec * 1.175)
        tail1.C0 = lerpJointAnglesCF(tail1.C0, baseJOffsets.tail1_c0, -rotVec * 0.85)
        neck0.C0 = lerpJointAnglesCF(neck0.C0, baseJOffsets.neck0_c0, rotVec)
    end

    -- TODO: footplanting
end

local updateConn = RunService.PostSimulation:Connect(update)
local descConn

descConn = character.DescendantRemoving:Connect(function(descendant)
    if (descendant == charRoot) then
        updateConn:Disconnect()
        descConn:Disconnect()
        descConn = nil
        updateConn = nil
    end
end)