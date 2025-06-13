local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")
local Torso = Character:WaitForChild("Torso1")
local TorsoJoint = Torso:WaitForChild("Joint")  -- Assuming this is the main joint
local C1 = TorsoJoint.C1
local RayParams = RaycastParams.new()
RayParams.FilterDescendantsInstances = {Character}

local MIN_HEIGHT = Humanoid.HipHeight + 2.179  -- Use the humanoid's hip height for the minimum height
local MAX_SLOPE_ANGLE = math.rad(100)  -- Maximum slope angle in radians (e.g., 30 degrees)

local function tweenRotation(newCFrame)
	local goal = {C1 = newCFrame}
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	local tween = TweenService:Create(TorsoJoint, tweenInfo, goal)
	tween:Play()
end

RunService.Heartbeat:Connect(function()
	local RaycastResult = workspace:Raycast(HumanoidRootPart.Position, Vector3.new(0, -MIN_HEIGHT - 0.5, 0), RayParams)
	if RaycastResult then
		local normal = RaycastResult.Normal
		local slopePitch = math.asin(normal:Cross(HumanoidRootPart.CFrame.rightVector).Y)
		if math.abs(slopePitch) > MAX_SLOPE_ANGLE then
			slopePitch = 0  -- Reset pitch to 0 if the slope exceeds the maximum angle
		end
		local newCFrame = C1 * CFrame.Angles(slopePitch, 0, 0)  -- Invert pitch to handle downhill slopes
		tweenRotation(newCFrame)
	else
		tweenRotation(C1)
	end
end)