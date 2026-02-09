local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")
local Workspace = game:GetService("Workspace")

local UNIT_Z = Vector3.new(0,0,1)
local X1_Y0_Z1 = Vector3.new(1,0,1)

local DEFAULT_DISTANCE = 12.5

-- Note: DotProduct check in CoordinateFrame::lookAt() prevents using values within about
-- 8.11 degrees of the +/- Y axis, that's why these limits are currently 80 degrees
local MIN_Y = math.rad(-80)
local MAX_Y = math.rad(80)

local VEC3_ZERO = Vector3.new(0,0,0)

local HEAD_OFFSET = Vector3.new(0,1.5,0)
local ZOOM_SENSITIVITY_CURVATURE = 0.5
local ZOOM_MIN = 1

local ZoomController = require(script.Parent.ZoomController)
local CamUtils = require(script.Parent.CamUtils)
local CamInput = require(script.Parent.CamInput)

local player = Players.LocalPlayer

local BaseCamera = {}
BaseCamera.__index = BaseCamera

function BaseCamera.new()
	local self = setmetatable({}, BaseCamera)
	
	-- So that derived classes have access to this
	self.cameraType = nil
	self.cameraMovementMode = nil

	self.lastCameraTransform = nil
	self.lastUserPanCamera = tick()

	-- Subject and position on last update call
	self.lastSubject = nil
	self.lastSubjectPosition = Vector3.new(0, 5, 0)
	self.lastSubjectCFrame = CFrame.new(self.lastSubjectPosition)

	self.currentSubjectDistance = math.clamp(DEFAULT_DISTANCE, player.CameraMinZoomDistance, player.CameraMaxZoomDistance)

	self.inMouseLockedMode = false
	self.isSmallTouchScreen = false
	self.portraitMode = false

	-- Used by modules which want to reset the camera angle on respawn.
	self.resetCameraAngle = true

	self.enabled = false

	-- Input Event Connections

	self.PlayerGui = nil

	self.cameraChangedConn = nil
	self.viewportSizeChangedConn = nil

	-- Mouse locked formerly known as shift lock mode
	self.mouseLockOffset = VEC3_ZERO

	-- Initialization things used to always execute at game load time, but now these camera modules are instantiated
	-- when needed, so the code here may run well after the start of the game

	if player.Character then
		self:onCharacterAdded(player.Character)
	end

	player.CharacterAdded:Connect(function(char)
		self:onCharacterAdded(char)
	end)

	if self.playerCameraModeChangeConn then self.playerCameraModeChangeConn:Disconnect() end
	self.playerCameraModeChangeConn = player:GetPropertyChangedSignal("CameraMode"):Connect(function()
		self:onPlayerCameraPropertyChange()
	end)

	if self.minDistanceChangeConn then self.minDistanceChangeConn:Disconnect() end
	self.minDistanceChangeConn = player:GetPropertyChangedSignal("CameraMinZoomDistance"):Connect(function()
		self:onPlayerCameraPropertyChange()
	end)

	if self.maxDistanceChangeConn then self.maxDistanceChangeConn:Disconnect() end
	self.maxDistanceChangeConn = player:GetPropertyChangedSignal("CameraMaxZoomDistance"):Connect(function()
		self:onPlayerCameraPropertyChange()
	end)

	if self.playerDevTouchMoveModeChangeConn then self.playerDevTouchMoveModeChangeConn:Disconnect() end
	self.playerDevTouchMoveModeChangeConn = player:GetPropertyChangedSignal("DevTouchMovementMode"):Connect(function()
		self:onDevTouchMovementModeChanged()
	end)
	self:onDevTouchMovementModeChanged() -- Init

	if self.gameSettingsTouchMoveMoveChangeConn then self.gameSettingsTouchMoveMoveChangeConn:Disconnect() end
	self.gameSettingsTouchMoveMoveChangeConn = UserGameSettings:GetPropertyChangedSignal("TouchMovementMode"):Connect(function()
		self:onGameSettingsTouchMovementModeChanged()
	end)

	self:onGameSettingsTouchMovementModeChanged() -- Init

	UserGameSettings:setCameraYInvertVisible()
	UserGameSettings:setGamepadCameraSensitivityVisible()

	self.hasGameLoaded = game:IsLoaded()
	if not self.hasGameLoaded then
		self.gameLoadedConn = game.Loaded:Connect(function()
			self.hasGameLoaded = true
			self.gameLoadedConn:Disconnect()
			self.gameLoadedConn = nil
		end)
	end

	self:onPlayerCameraPropertyChange()

	return self
end

function BaseCamera:getModuleName()
	return "BaseCamera"
end

function BaseCamera:onCharacterAdded(char)
	self.resetCameraAngle = self.resetCameraAngle or self:getEnabled()
	if UserInputService.TouchEnabled then
		self.PlayerGui = player:WaitForChild("PlayerGui")
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") then
				self.isAToolEquipped = true
			end
		end
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				self.isAToolEquipped = true
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				self.isAToolEquipped = false
			end
		end)
	end
end

function BaseCamera:getSubjectCFrame(): CFrame
	local result = self.lastSubjectCFrame
	local camera = workspace.CurrentCamera
	local cameraSubject = camera and camera.CameraSubject

	if not cameraSubject then
		return result
	end

    -- Should always be a player character
    if (cameraSubject:IsA("Model")) then
        if cameraSubject.PrimaryPart then
			result = (cameraSubject :: PVInstance):GetPivot() * CFrame.new(HEAD_OFFSET)
		else
			result = CFrame.new()
		end
    end

	if result then
		self.lastSubjectCFrame = result
	end

	return result
end

function BaseCamera:getSubjectVelocity(): Vector3
	local camera = workspace.CurrentCamera
	local cameraSubject = camera and camera.CameraSubject

	if not cameraSubject then
		return VEC3_ZERO
	end

	if cameraSubject:IsA("BasePart") then
		return cameraSubject.AssemblyLinearVelocity

	elseif cameraSubject:IsA("Model") then
		local primaryPart = cameraSubject.PrimaryPart

		if primaryPart then
			return primaryPart.AssemblyLinearVelocity
		end
	end

	return VEC3_ZERO
end

function BaseCamera:getSubjectRotVelocity(): Vector3
	local camera = workspace.CurrentCamera
	local cameraSubject = camera and camera.CameraSubject

	if not cameraSubject then
		return VEC3_ZERO
	end

	if cameraSubject:IsA("BasePart") then
		return cameraSubject.AssemblyAngularVelocity

	elseif cameraSubject:IsA("Model") then
		local primaryPart = cameraSubject.PrimaryPart

		if primaryPart then
			return primaryPart.AssemblyAngularVelocity
		end
	end

	return VEC3_ZERO
end

function BaseCamera:stepZoom()
	local zoom: number = self.currentSubjectDistance
	local zoomDelta: number = CamInput.getZoomDelta()

	if math.abs(zoomDelta) > 0 then
		local newZoom

		if zoomDelta > 0 then
			newZoom = zoom + zoomDelta*(1 + zoom * ZOOM_SENSITIVITY_CURVATURE)
			newZoom = math.max(newZoom, ZOOM_MIN)
		else
			newZoom = (zoom + zoomDelta)/(1 - zoomDelta * ZOOM_SENSITIVITY_CURVATURE)
			newZoom = math.max(newZoom, ZOOM_MIN)
		end

		if newZoom < ZOOM_MIN then
			newZoom = ZOOM_MIN
		end

		self:setCameraToSubjectDistance(newZoom)
	end

	return ZoomController.getZoomRadius()
end

function BaseCamera:getSubjectPosition(): Vector3?
	local result = self.lastSubjectPosition
	local camera = game.Workspace.CurrentCamera
	local cameraSubject = camera and camera.CameraSubject

	if cameraSubject then
        if cameraSubject:IsA("Model") and cameraSubject:IsA("PVInstance") then
			if cameraSubject.PrimaryPart then
				result = (cameraSubject :: PVInstance):GetPivot().Position
			end
		end
	else
		return nil
	end

	self.lastSubject = cameraSubject
	self.lastSubjectPosition = result

	return result
end

function BaseCamera:onViewportSizeChanged()
	local camera = game.Workspace.CurrentCamera
	local size = camera.ViewportSize
	self.portraitMode = size.X < size.Y
	self.isSmallTouchScreen = UserInputService.TouchEnabled and (size.Y < 500 or size.X < 700)
end

-- Listener for changes to workspace.CurrentCamera
function BaseCamera:onCurrentCameraChanged()
	if UserInputService.TouchEnabled then
		if self.viewportSizeChangedConn then
			self.viewportSizeChangedConn:Disconnect()
			self.viewportSizeChangedConn = nil
		end

		local newCamera = game.Workspace.CurrentCamera

		if newCamera then
			self:onViewportSizeChanged()
			self.viewportSizeChangedConn = newCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
				self:onViewportSizeChanged()
			end)
		end
	end

	if self.cameraSubjectChangedConn then
		self.cameraSubjectChangedConn:Disconnect()
		self.cameraSubjectChangedConn = nil
	end

	local camera = game.Workspace.CurrentCamera
	if camera then
		self.cameraSubjectChangedConn = camera:getPropertyChangedSignal("CameraSubject"):Connect(function()
			self:onNewCameraSubject()
		end)
		self:onNewCameraSubject()
	end
end

function BaseCamera:onDynamicThumbstickEnabled()
	if UserInputService.TouchEnabled then
		self.isDynamicThumbstickEnabled = true
	end
end

function BaseCamera:onDynamicThumbstickDisabled()
	self.isDynamicThumbstickEnabled = false
end

function BaseCamera:onGameSettingsTouchMovementModeChanged()
	if player.DevTouchMovementMode == Enum.DevTouchMovementMode.UserChoice then
		if (UserGameSettings.TouchMovementMode == Enum.TouchMovementMode.DynamicThumbstick
			or UserGameSettings.TouchMovementMode == Enum.TouchMovementMode.Default) then
			self:onDynamicThumbstickEnabled()
		else
			self:onDynamicThumbstickDisabled()
		end
	end
end

function BaseCamera:onDevTouchMovementModeChanged()
	if player.DevTouchMovementMode == Enum.DevTouchMovementMode.DynamicThumbstick then
		self:onDynamicThumbstickEnabled()
	else
		self:onGameSettingsTouchMovementModeChanged()
	end
end

function BaseCamera:onPlayerCameraPropertyChange()
	-- This call forces re-evaluation of player.CameraMode and clamping to min/max distance which may have changed
	self:setCameraToSubjectDistance(self.currentSubjectDistance)
end

function BaseCamera:inputTranslationToCameraAngleChange(translationVector, sensitivity)
	return translationVector * sensitivity
end

function BaseCamera:enable(enable: boolean)
	if self.enabled ~= enable then
		self.enabled = enable

		self:onEnabledChanged()
	end
end

function BaseCamera:onEnabledChanged()
	if self.enabled then
		CamInput.setInputEnabled(true)

		if self.cameraChangedConn then self.cameraChangedConn:Disconnect(); self.cameraChangedConn = nil end
		self.cameraChangedConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			self:onCurrentCameraChanged()
		end)
		self:onCurrentCameraChanged()
	else
		CamInput.setInputEnabled(false)
		self:cleanup()
	end
end

function BaseCamera:getEnabled(): boolean
	return self.enabled
end

function BaseCamera:cleanup()
	if self.subjectStateChangedConn then
		self.subjectStateChangedConn:Disconnect()
		self.subjectStateChangedConn = nil
	end
	if self.viewportSizeChangedConn then
		self.viewportSizeChangedConn:Disconnect()
		self.viewportSizeChangedConn = nil
	end
	if self.cameraChangedConn then 
		self.cameraChangedConn:Disconnect()
		self.cameraChangedConn = nil 
	end

	self.lastCameraTransform = nil
	self.lastSubjectCFrame = nil

	-- Unlock mouse for example if right mouse button was being held down
	CamUtils.restoreMouseBehavior()
end

function BaseCamera:updateMouseBehavior()
	CamUtils.restoreRotationType()
	CamInput.disableCameraToggleInput()

	local rotationActivated = CamInput.getRotationActivated()
	if rotationActivated then
		CamUtils.setMouseBehaviorOverride(Enum.MouseBehavior.LockCurrentPosition)
	else
		CamUtils.restoreMouseBehavior()
	end
end

function BaseCamera:updateForDistancePropertyChange()
	self:setCameraToSubjectDistance(self.currentSubjectDistance)
end

function BaseCamera:setCameraToSubjectDistance(desiredSubjectDistance: number): number
	local lastSubjectDistance = self.currentSubjectDistance
	local newSubjectDistance = math.clamp(desiredSubjectDistance, player.CameraMinZoomDistance, player.CameraMaxZoomDistance)

	if newSubjectDistance < ZOOM_MIN then
		self.currentSubjectDistance = ZOOM_MIN
	else
		self.currentSubjectDistance = newSubjectDistance
	end
	ZoomController.setZoomParameters(self.currentSubjectDistance, math.sign(desiredSubjectDistance - lastSubjectDistance))

	return self.currentSubjectDistance
end

function BaseCamera:setCameraType(cameraType)
	--Used by derived classes
	self.cameraType = cameraType
end

function BaseCamera:getCameraType()
	return self.cameraType
end

-- Movement mode standardized to Enum.ComputerCameraMovementMode values
function BaseCamera:setCameraMovementMode( cameraMovementMode )
	self.cameraMovementMode = cameraMovementMode
end

function BaseCamera:getCameraMovementMode()
	return self.cameraMovementMode
end

function BaseCamera:setIsMouseLocked(mouseLocked: boolean)
	self.inMouseLockedMode = mouseLocked
end

function BaseCamera:getIsMouseLocked(): boolean
	return self.inMouseLockedMode
end

function BaseCamera:setMouseLockOffset(offsetVector)
	self.mouseLockOffset = offsetVector
end

function BaseCamera:getMouseLockOffset()
	return self.mouseLockOffset
end

-- Nominal distance, set by dollying in and out with the mouse wheel or equivalent, not measured distance
function BaseCamera:getCameraToSubjectDistance(): number
	return self.currentSubjectDistance
end

-- Actual measured distance to the camera Focus point, which may be needed in special circumstances, but should
-- never be used as the starting point for updating the nominal camera-to-subject distance (self.currentSubjectDistance)
-- since that is a desired target value set only by mouse wheel (or equivalent) input, PopperCam, and clamped to min max camera distance
function BaseCamera:getMeasuredDistanceToFocus(): number?
	local camera = game.Workspace.CurrentCamera
	if camera then
		return (camera.CFrame.Position - camera.Focus.Position).magnitude
	end
	return nil
end

function BaseCamera:getCameraLookVector(): Vector3
	return game.Workspace.CurrentCamera and game.Workspace.CurrentCamera.CFrame.LookVector or UNIT_Z
end

function BaseCamera:getRootPart()
	if (Players.LocalPlayer.Character) then
		return Players.LocalPlayer.Character.PrimaryPart
	end
	return nil
end

function BaseCamera:calculateNewLookCFrameFromArg(suppliedLookVector: Vector3?, rotateInput: Vector2): CFrame
	local currLookVector: Vector3 = suppliedLookVector or self:getCameraLookVector()
	local currPitchAngle = math.asin(currLookVector.Y)
	local yTheta = math.clamp(rotateInput.Y, -MAX_Y + currPitchAngle, -MIN_Y + currPitchAngle)
	local constrainedRotateInput = Vector2.new(rotateInput.X, yTheta)
	local startCFrame = CFrame.new(VEC3_ZERO, currLookVector)
	local newLookCFrame = CFrame.Angles(0, -constrainedRotateInput.X, 0) * startCFrame * CFrame.Angles(-constrainedRotateInput.Y,0,0)
	return newLookCFrame
end

function BaseCamera:calculateNewLookVectorFromArg(suppliedLookVector: Vector3?, rotateInput: Vector2): Vector3
	local newLookCFrame = self:calculateNewLookCFrameFromArg(suppliedLookVector, rotateInput)
	return newLookCFrame.LookVector
end

function BaseCamera:calculateNewLookVectorVRFromArg(rotateInput: Vector2): Vector3
	local subjectPosition: Vector3 = self:getSubjectPosition()
	local vecToSubject: Vector3 = (subjectPosition - (game.Workspace.CurrentCamera :: Camera).CFrame.Position)
	local currLookVector: Vector3 = (vecToSubject * X1_Y0_Z1).Unit
	local vrRotateInput: Vector2 = Vector2.new(rotateInput.X, 0)
	local startCFrame: CFrame = CFrame.new(VEC3_ZERO, currLookVector)
	local yawRotatedVector: Vector3 = (CFrame.Angles(0, -vrRotateInput.X, 0) * startCFrame * CFrame.Angles(-vrRotateInput.Y,0,0)).LookVector
	return (yawRotatedVector * X1_Y0_Z1).Unit
end

function BaseCamera:onNewCameraSubject()
	if self.subjectStateChangedConn then
		self.subjectStateChangedConn:Disconnect()
		self.subjectStateChangedConn = nil
	end
end

function BaseCamera:update(dt)
	error("BaseCamera:Update() This is a virtual function that should never be getting called.", 2)
end

return BaseCamera