local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Controller = require(Players.LocalPlayer.PlayerScripts:FindFirstChild("CatController"))
local simulation = Controller:getSimulation()

local CHARACTER_ROOT_NAME = "PMRoot"
local MAX_SLOPE_ANGLE = math.rad(60)
local VEC3_ZERO = Vector3.zero
local VEC3_UP = Vector3.new(0, 1, 0)
local LERP_DT = 0.1

local JOINT_NAMES = {
    root = "PMRoot-TorsoMiddleTop",
    -- torso
    torso0 = "TorsoMiddleTop-TorsoLowerTop",
    torso1 = "TorsoMiddleTop-TorsoUpperTop",
    -- tail
    tail0 = "TorsoLowerTop-TopTail1",
    tail1 = "TopTail1-TopTail2",
    tail2 = "TopTail2-TopTail3",
    tail3 = "TopTail3-TopTail4",
    tail4 = "TopTail4-TopTail5",
    tail5 = "TopTail5-TopTail6",
    tail6 = "TopTail6-TopTail7",
    -- front left
    fl_leg0 = "TorsoUpperTop-BicepLeft",
    fl_leg1 = "BicepLeft-ShoulderTopLeft",
    fl_leg2 = "ShoulderTopLeft-ArmTopLeft",
    fl_leg3 = "ArmTopLeft-WristTopLeft",
    fl_leg4 = "WristTopLeft-PawLeftFront",
    -- front right
    fr_leg0 = "TorsoUpperTop-BicepRight",
    fr_leg1 = "BicepRight-ShoulderTopRight",
    fr_leg2 = "ShoulderTopRight-ArmTopRight",
    fr_leg3 = "ArmTopRight-WristTopRight",
    fr_leg4 = "WristTopRight-PawRightFront",
    -- rear left
    rl_leg0 = "TorsoLowerTop-ThighLeft",
    rl_leg1 = "ThighLeft-LegTopLeft",
    rl_leg2 = "LegTopLeft-AnkleTopLeft",
    rl_leg3 = "AnkleTopLeft-PawLeftBack",
    -- rear right
    rr_leg0 = "TorsoLowerTop-ThighRight",
    rr_leg1 = "ThighRight-LegTopRight",
    rr_leg2 = "LegTopRight-AnkleTopRight",
    rr_leg3 = "AnkleTopRight-PawRightBack"
}

local character = Players.LocalPlayer.Character
local basePlrMdl = StarterPlayer:FindFirstChild("PlayerModel")
local baseJoints = basePlrMdl:FindFirstChild("CharacterJoints")
local charRoot = character:FindFirstChild(CHARACTER_ROOT_NAME, true) :: BasePart
local mdlRoot = character.PrimaryPart

local baseJointOffsets = {
    root_c0 = baseJoints:FindFirstChild(JOINT_NAMES.root).C0,
    root_c1 = baseJoints:FindFirstChild(JOINT_NAMES.root).C1,
    torso0_c0 = baseJoints:FindFirstChild(JOINT_NAMES.torso0).C0,
    torso0_c1 = baseJoints:FindFirstChild(JOINT_NAMES.torso0).C1,
    torso1_c0 = baseJoints:FindFirstChild(JOINT_NAMES.torso1).C0,
    torso1_c1 = baseJoints:FindFirstChild(JOINT_NAMES.torso1).C1,
    tail0_c0 = baseJoints:FindFirstChild(JOINT_NAMES.tail0).C0,
    tail1_c0 = baseJoints:FindFirstChild(JOINT_NAMES.tail1).C0,
}

-- local joints = {
--     root = "PMRoot-TorsoMiddleTop",
--     body = {
--         j0 = "TorsoMiddleTop-TorsoLowerTop",
--         j1 = "TorsoMiddleTop-TorsoUpperTop",
--     },
--     tail = {
--         j0 = "TorsoLowerTop-TopTail1",
--         j1 = "TopTail1-TopTail2",
--         j2 = "TopTail2-TopTail3",
--         j3 = "TopTail3-TopTail4",
--         j4 = "TopTail4-TopTail5",
--         j5 = "TopTail5-TopTail6",
--         j6 = "TopTail6-TopTail7"
--     },
--     fl = {
--         j0 = "TorsoUpperTop-BicepLeft",
--         j1 = "BicepLeft-ShoulderTopLeft",
--         j2 = "ShoulderTopLeft-ArmTopLeft",
--         j3 = "ArmTopLeft-WristTopLeft",
--         j4 = "WristTopLeft-PawLeftFront"
--     },
--     fr = {
--         j0 = "TorsoUpperTop-BicepRight",
--         j1 = "BicepRight-ShoulderTopRight",
--         j2 = "ShoulderTopRight-ArmTopRight",
--         j3 = "ArmTopRight-WristTopRight",
--         j4 = "WristTopRight-PawRightFront"
--     },
--     rl = {
--         j0 = "TorsoLowerTop-ThighLeft",
--         j1 = "ThighLeft-LegTopLeft",
--         j2 = "LegTopLeft-AnkleTopLeft",
--         j3 = "AnkleTopLeft-PawLeftBack"
--     },
--     rr = {
--         j0 = "TorsoLowerTop-ThighRight",
--         j1 = "ThighRight-LegTopRight",
--         j2 = "LegTopRight-AnkleTopRight",
--         j3 = "AnkleTopRight-PawRightBack"
--     }
-- }

local joints = {} :: {[string]: Motor6D}
for n, str: string in pairs(JOINT_NAMES) do
    local inst = character:FindFirstChild(str, true)
    if (inst :: Motor6D) then
        joints[str] = inst
    else
        error("instance not found for " .. n)
    end
end

local function tweenRotation(newCFrame: CFrame, joint: Motor6D)
	local goal = {C1 = newCFrame}
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(joint, tweenInfo, goal)
	tween:Play()
end

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
            diffAngle = math.min(diffAngle, MAX_SLOPE_ANGLE)
            local newRootCF = baseJointOffsets.root_c0 * CFrame.Angles(diffAngle, 0, 0)


            root.C0 = root.C0:Lerp(newRootCF, LERP_DT)
            --tweenRotation(newCFrame, joints[JOINT_NAMES.root])
        end
    end

    -- update body and tail bending
    do
        local rotSpeedY = mdlRoot.AssemblyAngularVelocity.Y * 0.065
        rotSpeedY = math.clamp(rotSpeedY, -1, 1)
        if (math.abs(rotSpeedY) < 0.01) then
            rotSpeedY = 0
        end

        local torso0 = joints[JOINT_NAMES.torso0]
        local torso1 = joints[JOINT_NAMES.torso1]
        local tail0 = joints[JOINT_NAMES.tail0]
        local tail1 = joints[JOINT_NAMES.tail1]

        local rotCF0 = torso0.C0:Lerp(
            baseJointOffsets.torso0_c0 * CFrame.fromEulerAnglesXYZ(0, -rotSpeedY, 0), LERP_DT
        )
        local rotCF1 = torso1.C1:Lerp(
            baseJointOffsets.torso1_c1 * CFrame.fromEulerAnglesXYZ(0, -rotSpeedY, 0), LERP_DT
        )
        local rotCF2 = tail0.C0:Lerp(
            baseJointOffsets.tail0_c0 * CFrame.fromEulerAnglesXYZ(0, -rotSpeedY * 1.175, 0), LERP_DT
        )
        local rotCF3 = tail1.C0:Lerp(
            baseJointOffsets.tail1_c0 * CFrame.fromEulerAnglesXYZ(0, -rotSpeedY * 0.85, 0), LERP_DT
        )
        torso0.C0 = torso0.C0 * torso0.C0:ToObjectSpace(rotCF0)
        torso1.C1 = torso1.C1 * torso1.C1:ToObjectSpace(rotCF1)
        tail0.C0 = tail0.C0 * tail0.C0:ToObjectSpace(rotCF2)
        tail1.C0 = tail1.C0 * tail1.C0:ToObjectSpace(rotCF3)
    end
end

local updateConn = RunService.PreAnimation:Connect(update)

character.DescendantRemoving:Connect(function(descendant)
    if (descendant == charRoot) then
        updateConn:Disconnect()
    end
end)