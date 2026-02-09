local PlayersService = game:GetService("Players")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Settings = UserSettings()	-- ignore warning
local GameSettings = Settings.GameSettings

local CameraUtils = require(script.Parent.CamUtils)

local CONTEXT_ACTION_NAME = "MouseLockSwitchAction"
local MOUSELOCK_ACTION_PRIORITY = Enum.ContextActionPriority.Medium.Value
local LOCK_KEY = Enum.KeyCode.Tab

--[[ The Module ]]--
local MouseLockController = {}
MouseLockController.__index = MouseLockController

function MouseLockController.new()
	local self = setmetatable({}, MouseLockController)

	self.isMouseLocked = false
	self.savedMouseCursor = nil
	self.boundKeys = {LOCK_KEY} -- defaults

	self.mouseLockToggledEvent = Instance.new("BindableEvent")

	-- Watch for changes to user's ControlMode and ComputerMovementMode settings and update the feature availability accordingly
	GameSettings.Changed:Connect(function(property)
		if property == "ControlMode" or property == "ComputerMovementMode" then
			self:updateMouseLockAvailability()
		end
	end)

	-- Watch for changes to DevEnableMouseLock and update the feature availability accordingly
	PlayersService.LocalPlayer:GetPropertyChangedSignal("DevEnableMouseLock"):Connect(function()
		self:updateMouseLockAvailability()
	end)

	-- Watch for changes to DevEnableMouseLock and update the feature availability accordingly
	PlayersService.LocalPlayer:GetPropertyChangedSignal("DevComputerMovementMode"):Connect(function()
		self:updateMouseLockAvailability()
	end)

    UserInputService:GetPropertyChangedSignal("PreferredInput"):Connect(function()
        self:updateMouseLockAvailability()
    end)

	self:updateMouseLockAvailability()

	return self
end

function MouseLockController:getIsMouseLocked()
	return self.isMouseLocked
end

function MouseLockController:getBindableToggleEvent()
	return self.mouseLockToggledEvent.Event
end

function MouseLockController:updateMouseLockAvailability()
	local MouseLockAvailable = UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse

	if MouseLockAvailable ~= self.enabled then
		self:enableMouseLock(MouseLockAvailable)
	end
end

--[[ Local Functions ]]--
function MouseLockController:onMouseLockToggled()
	self.isMouseLocked = not self.isMouseLocked

    if (self.isMouseLocked) then
        UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
    else
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    end
    CameraUtils.setMouseIconEnabled(not self.isMouseLocked)

	self.mouseLockToggledEvent:Fire()
end

function MouseLockController:doMouseLockSwitch(name, state, input)
	if state == Enum.UserInputState.Begin then
		self:onMouseLockToggled()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

function MouseLockController:bindContextActions()
	ContextActionService:BindActionAtPriority(CONTEXT_ACTION_NAME, function(name, state, input)
		return self:doMouseLockSwitch(name, state, input)
	end, false, MOUSELOCK_ACTION_PRIORITY, unpack(self.boundKeys))
end

function MouseLockController:unbindContextActions()
	ContextActionService:UnbindAction(CONTEXT_ACTION_NAME)
end

function MouseLockController:isMouseLocked(): boolean
	return self.enabled and self.isMouseLocked
end

function MouseLockController:enableMouseLock(enable: boolean)
	if enable ~= self.enabled then

		self.enabled = enable

		if self.enabled then
			-- Enabling the mode
			self:bindContextActions()
		else
			-- Disabling
			-- Restore mouse cursor
			CameraUtils.restoreMouseIcon()

			self:unbindContextActions()

			-- If the mode is disabled while being used, fire the event to toggle it off
			if self.isMouseLocked then
				self.mouseLockToggledEvent:Fire()
			end

			self.isMouseLocked = false
		end

	end
end

return MouseLockController
