local PlayersService = game:GetService("Players")

local tweenAcceleration = math.rad(220) -- Radians/Second^2
local tweenSpeed = math.rad(0)          -- Radians/Second
local tweenMaxSpeed = math.rad(250)     -- Radians/Second

local INITIAL_CAMERA_ANGLE = CFrame.fromOrientation(math.rad(-15), 0, 0)
local SMOOTH_DELTA = 0.08

local Util = require(script.Parent.CamUtils)
local CamInput = require(script.Parent.CamInput)
local BaseCam = require(script.Parent.BaseCam)

local ClassicCamera = setmetatable({}, BaseCam)
ClassicCamera.__index = ClassicCamera

function ClassicCamera.new()
	local self = setmetatable(BaseCam.new(), ClassicCamera)

	self.isFollowCamera = false
	self.isCameraToggle = false
	self.lastUpdate = tick()
	--self.cameraToggleSpring = Util.Spring.new(5, 0)

	return self
end

-- function ClassicCamera:getCameraToggleOffset(dt: number)
-- 	if self.isCameraToggle then
-- 		local zoom = self.currentSubjectDistance
-- 		self.cameraToggleSpring.goal = 0

-- 		local distanceOffset: number = math.clamp(Util.map(zoom, 0.5, 64, 0, 1), 0, 1) + 1
-- 		return Vector3.new(0, self.cameraToggleSpring:step(dt)*distanceOffset, 0)
-- 	end

-- 	return Vector3.new()
-- end

-- Movement mode standardized to Enum.ComputerCameraMovementMode values
function ClassicCamera:setCameraMovementMode(cameraMovementMode: Enum.ComputerCameraMovementMode)
	BaseCam.setCameraMovementMode(self, cameraMovementMode)

	self.isFollowCamera = cameraMovementMode == Enum.ComputerCameraMovementMode.Follow
	self.isCameraToggle = cameraMovementMode == Enum.ComputerCameraMovementMode.CameraToggle
end

function ClassicCamera:update(dt)
	local now = tick()
	local camera = workspace.CurrentCamera
	local newCameraCFrame = camera.CFrame
	local newCameraFocus = camera.Focus

	local overrideCameraLookVector = nil
	if self.resetCameraAngle then
		local rootPart: BasePart = self:getRootPart()
		if rootPart then
			overrideCameraLookVector = (rootPart.CFrame * INITIAL_CAMERA_ANGLE).LookVector
		else
			overrideCameraLookVector = INITIAL_CAMERA_ANGLE.LookVector
		end
		self.resetCameraAngle = false
	end

	local player = PlayersService.LocalPlayer
	local cameraSubject = camera.CameraSubject

	if self.lastUpdate == nil or dt > 1 then
		self.lastCameraTransform = nil
	end

	local rotateInput = CamInput.getRotation(dt)
	if (rotateInput.Magnitude > 1) then
		rotateInput = rotateInput.Unit
	end
	self:stepZoom()

	-- Reset tween speed if user is panning
	if rotateInput ~= Vector2.new() then
		self.lastUserPanCamera = tick()
	end

	local subjectPosition: Vector3 = self:getSubjectPosition()

	if subjectPosition and player and camera then
		local zoom = self:getCameraToSubjectDistance()
		local currCamVel = self.camVelocity

		if zoom < 0.5 then
			zoom = 0.5
		end

		newCameraFocus = CFrame.new(subjectPosition)
		local newLookVector = self:calculateNewLookVectorFromArg(overrideCameraLookVector, rotateInput)
		newCameraCFrame = CFrame.lookAlong(newCameraFocus.Position - (zoom * newLookVector), newLookVector)

		-- local toggleOffset = self:getCameraToggleOffset(dt)
		-- newCameraFocus = newCameraFocus + toggleOffset
		-- newCameraCFrame = newCameraCFrame + toggleOffset

		self.lastCameraTransform = newCameraCFrame
		self.lastCameraFocus = newCameraFocus
		self.lastSubjectCFrame = nil
	end

	self.lastUpdate = now
	return newCameraCFrame, newCameraFocus
end

return ClassicCamera