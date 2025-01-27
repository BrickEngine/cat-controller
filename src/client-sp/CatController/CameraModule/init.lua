--[[
	CameraModule implements a singleton class to manage the
	selection, activation, and deactivation of the current camera controller, character occlusion controller.
	This script binds to RenderStepped at Camera priority and calls the Update() methods on the active controller instances.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local CameraModule = {}
CameraModule.__index = CameraModule

-- NOTICE: Player property names do not all match their StarterPlayer equivalents,
local PLAYER_CAMERA_PROPERTIES = {
	"CameraMinZoomDistance",
	"CameraMaxZoomDistance",
	"CameraMode",
	"DevCameraOcclusionMode",
	"DevComputerCameraMode",			-- Corresponds to StarterPlayer.DevComputerCameraMovementMode
	"DevTouchCameraMode",				-- Corresponds to StarterPlayer.DevTouchCameraMovementMode

	-- Character movement mode
	"DevComputerMovementMode",
	"DevTouchMovementMode",
	"DevEnableMouseLock",				-- Corresponds to StarterPlayer.EnableMouseLockOption
}

local USER_GAME_SETTINGS_PROPERTIES = {
	"ComputerCameraMovementMode",
	"ComputerMovementMode",
	"ControlMode",
	"GamepadCameraSensitivity",
	"MouseSensitivity",
	"RotationType",
	"TouchCameraMovementMode",
	"TouchMovementMode",
}

local CamUtils = require(script.CamUtils)
local CamInput = require(script.CamInput)
local ClassicCam = require(script.ClassicCam)
local Poppercam = require(script.PopperCam)

local instantiatedCameraControllers = {}
local instantiatedOcclusionModules = {}

-- Management of which options appear on the Roblox User Settings screen
do
	local PlayerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
	PlayerScripts:RegisterTouchCameraMovementMode(Enum.TouchCameraMovementMode.Default)
	PlayerScripts:RegisterComputerCameraMovementMode(Enum.ComputerCameraMovementMode.Default)
end

function CameraModule.new()
	local self = setmetatable({},CameraModule)

	-- Current active controller instances
	self.activeCameraController = nil
	self.activeOcclusionModule = nil
	self.currentComputerCameraMovementMode = nil

	-- Connections to events
	self.cameraSubjectChangedConn = nil
	self.cameraTypeChangedConn = nil

	-- Adds CharacterAdded and CharacterRemoving event handlers for all current players
	for _,player in pairs(Players:GetPlayers()) do
		self:OnPlayerAdded(player)
	end

	-- Adds CharacterAdded and CharacterRemoving event handlers for all players who join in the future
	Players.PlayerAdded:Connect(function(player)
		self:OnPlayerAdded(player)
	end)

	self:activateCamController(self:getCamControlChoice())

	self:ActivateOcclusionModule(Players.LocalPlayer.DevCameraOcclusionMode)
	self:OnCurrentCameraChanged() -- Does initializations and makes first camera controller
	RunService:BindToRenderStep("cameraRenderUpdate", Enum.RenderPriority.Camera.Value, function(dt) self:Update(dt) end)

	-- Connect listeners to camera-related properties
	for _, propertyName in pairs(PLAYER_CAMERA_PROPERTIES) do
		Players.LocalPlayer:GetPropertyChangedSignal(propertyName):Connect(function()
			self:OnLocalPlayerCameraPropertyChanged(propertyName)
		end)
	end

	for _, propertyName in pairs(USER_GAME_SETTINGS_PROPERTIES) do
		UserGameSettings:GetPropertyChangedSignal(propertyName):Connect(function()
			self:OnUserGameSettingsPropertyChanged(propertyName)
		end)
	end
	game.Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:OnCurrentCameraChanged()
	end)

	return self
end

function CameraModule:GetCameraMovementModeFromSettings()
	local cameraMode = Players.LocalPlayer.CameraMode

	-- Lock First Person trumps all other settings and forces ClassicCamera
	if cameraMode == Enum.CameraMode.LockFirstPerson then
		return CamUtils.ConvertCameraModeEnumToStandard(Enum.ComputerCameraMovementMode.Classic)
	end

	local devMode, userMode
	if UserInputService.TouchEnabled then
		devMode = CamUtils.ConvertCameraModeEnumToStandard(Players.LocalPlayer.DevTouchCameraMode)
		userMode = CamUtils.ConvertCameraModeEnumToStandard(UserGameSettings.TouchCameraMovementMode)
	else
		devMode = CamUtils.ConvertCameraModeEnumToStandard(Players.LocalPlayer.DevComputerCameraMode)
		userMode = CamUtils.ConvertCameraModeEnumToStandard(UserGameSettings.ComputerCameraMovementMode)
	end

	if devMode == Enum.DevComputerCameraMovementMode.UserChoice then
		-- Developer is allowing user choice, so user setting is respected
		return userMode
	end

	return devMode
end

function CameraModule:activateOcclusionModule()
	local newModuleCreator = Poppercam

	if self.activeOcclusionModule then
		if (not self.activeOcclusionModule:GetEnabled()) then
			self.activeOcclusionModule:Enable(true)
		end
		return
	end

	local prevOcclusionModule = self.activeOcclusionModule
	self.activeOcclusionModule = instantiatedOcclusionModules[newModuleCreator]

	if (not self.activeOcclusionModule) then
		self.activeOcclusionModule = newModuleCreator.new()
		if self.activeOcclusionModule then
			instantiatedOcclusionModules[newModuleCreator] = self.activeOcclusionModule
		end
	end

	if self.activeOcclusionModule then
		if (prevOcclusionModule) then
			if prevOcclusionModule ~= self.activeOcclusionModule then
				prevOcclusionModule:Enable(false)
			else
				warn("CameraScript ActivateOcclusionModule failure to detect already running correct module")
			end
		end
        
        for _, player in pairs(Players:GetPlayers()) do
            if player and player.Character then
                self.activeOcclusionModule:CharacterAdded(player.Character, player)
            end
        end
        self.activeOcclusionModule:OnCameraSubjectChanged((game.Workspace.CurrentCamera :: Camera).CameraSubject)
		self.activeOcclusionModule:Enable(true)
	end
end

function CameraModule:activateCamController(cameraMovementMode, legacyCameraType: Enum.CameraType?)
	local newCameraCreator = nil

	if (legacyCameraType ~= nil) then
		if legacyCameraType == Enum.CameraType.Scriptable then
			if self.activeCameraController then
				self.activeCameraController:Enable(false)
				self.activeCameraController = nil
			end
			return
		elseif legacyCameraType == Enum.CameraType.Custom then
			cameraMovementMode = self:GetCameraMovementModeFromSettings()
		elseif legacyCameraType == Enum.CameraType.Track then
			cameraMovementMode = Enum.ComputerCameraMovementMode.Classic
		elseif legacyCameraType == Enum.CameraType.Follow then
			cameraMovementMode = Enum.ComputerCameraMovementMode.Follow
		elseif legacyCameraType == Enum.CameraType.Orbital then
			cameraMovementMode = Enum.ComputerCameraMovementMode.Orbital
		elseif
			legacyCameraType == Enum.CameraType.Attach
			or legacyCameraType == Enum.CameraType.Watch
			or legacyCameraType == Enum.CameraType.Fixed
		then
			newCameraCreator = ClassicCam
		else
			warn("CameraScript encountered an unhandled Camera.CameraType value: ", legacyCameraType)
		end
	end

	if not newCameraCreator then
        if cameraMovementMode == Enum.ComputerCameraMovementMode.Classic or
			cameraMovementMode == Enum.ComputerCameraMovementMode.Follow or
			cameraMovementMode == Enum.ComputerCameraMovementMode.Default or
			cameraMovementMode == Enum.ComputerCameraMovementMode.CameraToggle then
			newCameraCreator = ClassicCam
		else
			warn("ActivateCameraController did not select a module.")
			return
		end
	end

	-- Create the camera control module we need if it does not already exist in instantiatedCameraControllers
	local newCameraController
	if not instantiatedCameraControllers[newCameraCreator] then
		newCameraController = newCameraCreator.new()
		instantiatedCameraControllers[newCameraCreator] = newCameraController
	else
		newCameraController = instantiatedCameraControllers[newCameraCreator]
		if newCameraController.Reset then
			newCameraController:Reset()
		end
	end

	if self.activeCameraController then
		-- deactivate the old controller and activate the new one
		if self.activeCameraController ~= newCameraController then
			self.activeCameraController:Enable(false)
			self.activeCameraController = newCameraController
			self.activeCameraController:Enable(true)
		elseif not self.activeCameraController:GetEnabled() then
			self.activeCameraController:Enable(true)
		end
	elseif newCameraController ~= nil then
		-- only activate the new controller
		self.activeCameraController = newCameraController
		self.activeCameraController:Enable(true)
	end

	if self.activeCameraController then
        if cameraMovementMode ~= nil then
            self.activeCameraController:SetCameraMovementMode(cameraMovementMode)
        elseif legacyCameraType ~= nil then
            self.activeCameraController:SetCameraType(legacyCameraType)
        end
	end
end

-- Note: The active transparency controller could be made to listen for this event itself.
function CameraModule:OnCameraSubjectChanged()
	local camera = workspace.CurrentCamera
	local cameraSubject = camera and camera.CameraSubject

	if self.activeTransparencyController then
		self.activeTransparencyController:SetSubject(cameraSubject)
	end

	if self.activeOcclusionModule then
		self.activeOcclusionModule:OnCameraSubjectChanged(cameraSubject)
	end

	self:ActivateCameraController(nil, camera.CameraType)
end

function CameraModule:OnCameraTypeChanged(newCameraType: Enum.CameraType)
	if newCameraType == Enum.CameraType.Scriptable then
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			CamUtils.restoreMouseBehavior()
		end
	end

	-- Forward the change to ActivateCameraController to handle
	self:ActivateCameraController(nil, newCameraType)
end

-- Note: Called whenever workspace.CurrentCamera changes, but also on initialization of this script
function CameraModule:OnCurrentCameraChanged()
	local currentCamera = game.Workspace.CurrentCamera
	if not currentCamera then return end

	if self.cameraSubjectChangedConn then
		self.cameraSubjectChangedConn:Disconnect()
	end

	if self.cameraTypeChangedConn then
		self.cameraTypeChangedConn:Disconnect()
	end

	self.cameraSubjectChangedConn = currentCamera:GetPropertyChangedSignal("CameraSubject"):Connect(function()
		self:OnCameraSubjectChanged(currentCamera.CameraSubject)
	end)

	self.cameraTypeChangedConn = currentCamera:GetPropertyChangedSignal("CameraType"):Connect(function()
		self:OnCameraTypeChanged(currentCamera.CameraType)
	end)

	self:OnCameraSubjectChanged(currentCamera.CameraSubject)
	self:OnCameraTypeChanged(currentCamera.CameraType)
end

function CameraModule:OnLocalPlayerCameraPropertyChanged(propertyName: string)
	if propertyName == "CameraMode" then
		-- CameraMode is only used to turn on/off forcing the player into first person view. The
		-- Note: The case "Classic" is used for all other views and does not correspond only to the ClassicCamera module
		if Players.LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson then
			-- Locked in first person, use ClassicCamera which supports this
			if not self.activeCameraController or self.activeCameraController:GetModuleName() ~= "ClassicCamera" then
				self:ActivateCameraController(CamUtils.ConvertCameraModeEnumToStandard(Enum.DevComputerCameraMovementMode.Classic))
			end

			if self.activeCameraController then
				self.activeCameraController:UpdateForDistancePropertyChange()
			end
		elseif Players.LocalPlayer.CameraMode == Enum.CameraMode.Classic then
			-- Not locked in first person view
			local cameraMovementMode = self:GetCameraMovementModeFromSettings()
			self:ActivateCameraController(CamUtils.ConvertCameraModeEnumToStandard(cameraMovementMode))
		else
			warn("Unhandled value for property player.CameraMode: ",Players.LocalPlayer.CameraMode)
		end

	elseif propertyName == "DevComputerCameraMode" or
		   propertyName == "DevTouchCameraMode" then
		local cameraMovementMode = self:GetCameraMovementModeFromSettings()
		self:ActivateCameraController(CamUtils.ConvertCameraModeEnumToStandard(cameraMovementMode))

	elseif propertyName == "DevCameraOcclusionMode" then
		self:ActivateOcclusionModule(Players.LocalPlayer.DevCameraOcclusionMode)

	elseif propertyName == "CameraMinZoomDistance" or propertyName == "CameraMaxZoomDistance" then
		if self.activeCameraController then
			self.activeCameraController:UpdateForDistancePropertyChange()
		end
	elseif propertyName == "DevTouchMovementMode" then
	elseif propertyName == "DevComputerMovementMode" then
	elseif propertyName == "DevEnableMouseLock" then
		-- This is the enabling/disabling of "Shift Lock" mode, not LockFirstPerson (which is a CameraMode)
		-- Note: Enabling and disabling of MouseLock mode is normally only a publish-time choice made via
		-- the corresponding EnableMouseLockOption checkbox of StarterPlayer, and this script does not have
		-- support for changing the availability of MouseLock at runtime (this would require listening to
		-- Player.DevEnableMouseLock changes)
	end
end

function CameraModule:OnUserGameSettingsPropertyChanged(propertyName: string)
	if propertyName == "ComputerCameraMovementMode" then
		local cameraMovementMode = self:GetCameraMovementModeFromSettings()
		self:ActivateCameraController(CamUtils.ConvertCameraModeEnumToStandard(cameraMovementMode))
	end
end

--[[
	Main RenderStep Update. The camera controller and occlusion module both have opportunities
	to set and modify (respectively) the CFrame and Focus before it is set once on CurrentCamera.
	The camera and occlusion modules should only return CFrames, not set the CFrame property of
	CurrentCamera directly.
--]]
function CameraModule:Update(dt)
	if self.activeCameraController then
		self.activeCameraController:UpdateMouseBehavior()

		local newCameraCFrame, newCameraFocus = self.activeCameraController:Update(dt)

		if self.activeOcclusionModule then
			newCameraCFrame, newCameraFocus = self.activeOcclusionModule:Update(dt, newCameraCFrame, newCameraFocus)
		end

		-- Here is where the new CFrame and Focus are set for this render frame
		local currentCamera = game.Workspace.CurrentCamera :: Camera
		currentCamera.CFrame = newCameraCFrame
		currentCamera.Focus = newCameraFocus

		-- Update to character local transparency as needed based on camera-to-subject distance
		if self.activeTransparencyController then
			self.activeTransparencyController:Update(dt)
		end

		if CamInput.getInputEnabled() then
			CamInput.resetInputForFrameEnd()
		end
	end
end

function CameraModule:getCamControlChoice()
    local player = Players.LocalPlayer

    if player then
        if UserInputService:GetLastInputType() == Enum.UserInputType.Touch or UserInputService.TouchEnabled then
            -- Touch
            if player.DevTouchCameraMode == Enum.DevTouchCameraMovementMode.UserChoice then
                return CamUtils.ConvertCameraModeEnumToStandard(UserGameSettings.TouchCameraMovementMode)
            else
                return CamUtils.ConvertCameraModeEnumToStandard(player.DevTouchCameraMode)
            end
        else
            -- Computer
            if player.DevComputerCameraMode == Enum.DevComputerCameraMovementMode.UserChoice then
                local computerMovementMode = CamUtils.ConvertCameraModeEnumToStandard(UserGameSettings.ComputerCameraMovementMode)
                return CamUtils.ConvertCameraModeEnumToStandard(computerMovementMode)
            else
                return CamUtils.ConvertCameraModeEnumToStandard(player.DevComputerCameraMode)
            end
        end
    end
end

function CameraModule:OnCharacterAdded(char, player)
	if self.activeOcclusionModule then
		self.activeOcclusionModule:CharacterAdded(char, player)
	end
end

function CameraModule:OnCharacterRemoving(char, player)
	if self.activeOcclusionModule then
		self.activeOcclusionModule:CharacterRemoving(char, player)
	end
end

function CameraModule:OnPlayerAdded(player)
	player.CharacterAdded:Connect(function(char)
		self:OnCharacterAdded(char, player)
	end)
	player.CharacterRemoving:Connect(function(char)
		self:OnCharacterRemoving(char, player)
	end)
end

function CameraModule:OnMouseLockToggled()
	if self.activeMouseLockController then
		local mouseLocked = self.activeMouseLockController:GetIsMouseLocked()
		local mouseLockOffset = self.activeMouseLockController:GetMouseLockOffset()
		if self.activeCameraController then
			self.activeCameraController:SetIsMouseLocked(mouseLocked)
			self.activeCameraController:SetMouseLockOffset(mouseLockOffset)
		end
	end
end

local cameraModuleObject = CameraModule.new()

return {}