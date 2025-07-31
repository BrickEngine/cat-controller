local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local Controller = require(Players.LocalPlayer.PlayerScripts:FindFirstChild("CatController"))
local simulation = Controller:getSimulation()

local CHARACTER_ROOT_NAME = "PMRoot"
local JOINT_NAME = "PMRoot-TorsoMiddleTop"

local MAX_SLOPE_ANGLE = math.rad(60)

local VEC3_ZERO = Vector3.zero
local VEC3_UP = Vector3.new(0, 1, 0)

local character = Players.LocalPlayer.Character
local charRoot = character:FindFirstChild(CHARACTER_ROOT_NAME, true) :: BasePart

local joint = character:FindFirstChild(JOINT_NAME, true) :: Motor6D
local c0 = joint.C0

local JOINTS = {
    root = "PMRoot-TorsoMiddleTop",
    body = {
        j0 = "TorsoMiddleTop-TorsoLowerTop",
        j1 = "TorsoMiddleTop-TorsoUpperTop",
    },
    tail = {
        j0 = "TorsoLowerTop-TopTail1",
        j1 = "TopTail1-TopTail2",
        j2 = "TopTail2-TopTail3",
        j3 = "TopTail3-TopTail4",
        j4 = "TopTail4-TopTail5",
        j5 = "TopTail5-TopTail6",
        j6 = "TopTail6-TopTail7"
    },
    fl = {
        j0 = "TorsoUpperTop-BicepLeft",
        j1 = "BicepLeft-ShoulderTopLeft",
        j2 = "ShoulderTopLeft-ArmTopLeft",
        j3 = "ArmTopLeft-WristTopLeft",
        j4 = "WristTopLeft-PawLeftFront"
    },
    fr = {
        j0 = "TorsoUpperTop-BicepRight",
        j1 = "BicepRight-ShoulderTopRight",
        j2 = "ShoulderTopRight-ArmTopRight",
        j3 = "ArmTopRight-WristTopRight",
        j4 = "WristTopRight-PawRightFront"
    },
    rl = {
        j0 = "TorsoLowerTop-ThighLeft",
        j1 = "ThighLeft-LegTopLeft",
        j2 = "LegTopLeft-AnkleTopLeft",
        j3 = "AnkleTopLeft-PawLeftBack"
    },
    rr = {
        j0 = "TorsoLowerTop-ThighRight",
        j1 = "ThighRight-LegTopRight",
        j2 = "LegTopRight-AnkleTopRight",
        j3 = "AnkleTopRight-PawRightBack"
    }
}

local activeJoints = {}
for n,tbl: any in pairs(JOINTS) do
    if (type(tbl) == "table") then
        for i,v in pairs(tbl) do
            if (not activeJoints[n]) then
                activeJoints[n] = {}
            end
            activeJoints[n][i] = character:FindFirstChild(v, true)
        end
    end
end


local function tweenRotation(newCFrame)
	local goal = {C1 = newCFrame}
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(joint, tweenInfo, goal)
	tween:Play()
end

local p = Instance.new("Part")
p.Anchored = true
p.CanCollide = false
p.Size = Vector3.new(0.1,0.1,11)
p.BrickColor = BrickColor.Green()
p.Parent = workspace
local function debugShowSlopePart(pos, dir)
    local posOffs = dir*5
    p.CFrame = CFrame.lookAlong(pos+dir*5, dir)
end

local function update(dt: number)
    local stateId = simulation:getCurrentStateId()
    local normal = simulation:getNormal()
    
    if (stateId == 0) then
        if (normal ~= VEC3_ZERO) then
            local rootRightVec = charRoot.CFrame.RightVector
            local rootLookVec = charRoot.CFrame.LookVector
            local crossDirVec = (normal:Cross(rootRightVec)).Unit
            local slopePitch = math.acos(rootLookVec:Dot(crossDirVec)) --math.asin(crossDirVec.Y)
            --print(cross.Y)
            -- if (math.abs(slopePitch) < QUART_PI) then
            --     slopePitch = -slopePitch
            -- end
            local diffAngle = math.atan2(
                (rootLookVec:Cross(crossDirVec)):Dot(rootRightVec),
                rootLookVec:Dot(crossDirVec)
            )
            -- if (diffAngle <= -math.pi) then
            --     diffAngle += math.pi
            -- end
            diffAngle = math.min(diffAngle, MAX_SLOPE_ANGLE)
            local newCFrame = c0 * CFrame.Angles(-diffAngle, 0, 0)
            --  local newCFrame = c1 * CFrame.new(
            --     0, 0, 0,
                
            -- )--lookRot--CFrame.Angles(-slopePitch, 0, 0)
            tweenRotation(newCFrame)
            debugShowSlopePart(charRoot.CFrame.Position, crossDirVec)
        end
    end
end

local updateConn = RunService.PreAnimation:Connect(update)

character.DescendantRemoving:Connect(function(descendant)
    if (descendant == charRoot) then
        updateConn:Disconnect()
    end
end)