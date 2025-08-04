local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local controller = script.Parent
local MoveKeyboard = require(controller.MoveKeyboard)
local MoveTouch = require(controller.MoveTouch)

local lastInpType

local ACTION_PRIO = 100
local NORMALIZE_INPUT = true
local VEC3_ZERO = Vector3.zero

local MOVEMENT_MODE_MAP = {
	[Enum.TouchMovementMode.DPad] = MoveTouch,
	[Enum.DevTouchMovementMode.DPad] = MoveTouch,
	[Enum.TouchMovementMode.Thumbpad] = MoveTouch,
	[Enum.DevTouchMovementMode.Thumbpad] = MoveTouch,
	[Enum.TouchMovementMode.Thumbstick] = MoveTouch,
	[Enum.DevTouchMovementMode.Thumbstick] = MoveTouch,
	[Enum.TouchMovementMode.DynamicThumbstick] = MoveTouch,
	[Enum.DevTouchMovementMode.DynamicThumbstick] = MoveTouch,
	[Enum.TouchMovementMode.Default] = MoveTouch,
	[Enum.ComputerMovementMode.Default] = MoveKeyboard,
	[Enum.ComputerMovementMode.KeyboardMouse] = MoveKeyboard,
	[Enum.DevComputerMovementMode.KeyboardMouse] = MoveKeyboard,
	[Enum.DevComputerMovementMode.Scriptable] = nil
}
local PC_INPUT_TYPE_MAP = {
	[Enum.UserInputType.Keyboard] = MoveKeyboard,
	[Enum.UserInputType.MouseButton1] = MoveKeyboard,
	[Enum.UserInputType.MouseButton2] = MoveKeyboard,
	[Enum.UserInputType.MouseButton3] = MoveKeyboard,
	[Enum.UserInputType.MouseWheel] = MoveKeyboard,
	[Enum.UserInputType.MouseMovement] = MoveKeyboard,
}
local TOUCH_INPUT_TYPE_MAP = {
    [Enum.UserInputType.Touch] = MoveTouch
}

local InputManager = {}
InputManager.__index = InputManager

function InputManager.new()
    local self = setmetatable({}, InputManager)

    self.controlsEnabled = true

    self.inputControllers = {}
    self.activeInputController = nil

    self.touchControlArea = nil
    self.playerGui = nil
	self.touchGui = nil
	self.playerGuiAddedConn = nil

	UserInputService.LastInputTypeChanged:Connect(function(newLastInputType)
		self:onLastInputTypeChanged(newLastInputType)
	end)

	GuiService:GetPropertyChangedSignal("TouchControlsEnabled"):Connect(function()
		self:updateTouchGuiVisibility()
        self:updateActiveControlModuleEnabled()
	end)

	if UserInputService.TouchEnabled then
        -- TODO
		self.playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if self.playerGui then
            print("plrGui exists")
			self:createTouchGuiContainer()
			self:onLastInputTypeChanged(UserInputService:GetLastInputType())
		else
            print("plrGui NONONONON exists")
			self.playerGuiAddedConn = Players.LocalPlayer.ChildAdded:Connect(function(child)
				if child:IsA("PlayerGui") then
					self.playerGui = child
					self:createTouchGuiContainer()
					self.playerGuiAddedConn:Disconnect()
					self.playerGuiAddedConn = nil
					self:onLastInputTypeChanged(UserInputService:GetLastInputType())
				end
			end)
		end
	end

    return self
end

------------------------------------------------------------------------------------------------------------------------------

function InputManager:getMoveVec(): Vector3
    if (not self.activeInputController) then
        return VEC3_ZERO
    end
    if (NORMALIZE_INPUT) then
        local vec: Vector3 = self.activeInputController:getMoveVec()
        if (vec.Magnitude > 1) then
            return vec.Unit
        else
            return vec
        end
    else
        return self.activeInputController:getMoveVec()
    end
end

function InputManager:getIsJumping(): boolean
    if (not self.activeInputController) then
        return false
    end
    return self.activeInputController:getIsJumping()
end

function InputManager:getIsRunning(): boolean
    if (not self.activeInputController) then
        return false
    end
    return self.activeInputController:getIsRunning()
end

function InputManager:getActiveInputController(): ({}?)
    return self.activeInputController
end

-- create container for all touch device guis
function InputManager:createTouchGuiContainer()
    if self.touchGui then self.touchGui:Destroy() end

	self.touchGui = Instance.new("ScreenGui")
	self.touchGui.Name = "TouchGui"
	self.touchGui.ResetOnSpawn = false
	self.touchGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	self:updateTouchGuiVisibility()
	self.touchGui.ClipToDeviceSafeArea = false;

	self.touchControlFrame = Instance.new("Frame")
	self.touchControlFrame.Name = "TouchControlFrame"
	self.touchControlFrame.Size = UDim2.new(1, 0, 1, 0)
	self.touchControlFrame.BackgroundTransparency = 1
	self.touchControlFrame.Parent = self.touchGui

	self.touchGui.Parent = self.playerGui
end

-- diables the current input controller, if inpModule is nil
function InputManager:switchInputController(inpModule: {}?)
    if (not inpModule) then
        if (self.activeInputController) then
            self.activeInputController:enable(false)
        end
        self.activeInputController = nil
        return
    end

    if (not self.inputControllers[inpModule]) then
        self.inputControllers[inpModule] = inpModule.new(ACTION_PRIO)
    end

    if (self.activeInputController ~= self.inputControllers[inpModule]) then
        if (self.activeInputController) then
            self.activeInputController:enable(false)
        end
        self.activeInputController = self.inputControllers[inpModule]
    end

    self:updateActiveControlModuleEnabled()
end

function InputManager:updateActiveControlModuleEnabled()
	-- helpers for disable/enable
	local disable = function()
		self.activeInputController:enable(false)
	end

	local enable = function()
        if self.touchControlFrame then
			self.activeInputController:enable(true, self.touchControlFrame)
		else
			self.activeInputController:enable(true)
		end
	end

	-- there is no active controller
	if not self.activeInputController then
		return
	end

	if not self.controlsEnabled then
		disable(); return
	end

	-- GuiService.TouchControlsEnabled == false and the active controller is a touch controller,
	-- disable controls
	if (not GuiService.TouchControlsEnabled
        and UserInputService.TouchEnabled
        and self.activeInputController == self.inputControllers[MoveTouch]
    ) then
		disable(); return
	end

	-- no settings prevent enabling controls
	enable()
end

-- TODO: implement touch control switch
function InputManager:onLastInputTypeChanged(newlastInpType: Enum.UserInputType)
    if (lastInpType == newlastInpType) then
        warn("LastInputTypeChanged listener called with current input type")
    end

    lastInpType = newlastInpType

    if (TOUCH_INPUT_TYPE_MAP[lastInpType] ~= nil) then
        if (self.activeInputController and self.activeInputController == self.inputControllers[MoveTouch]) then
            return
        end

        while not self.touchControlFrame do
            task.wait()
        end
        self:switchInputController(MoveTouch)
        print("switching to touch controller")

    elseif (PC_INPUT_TYPE_MAP[lastInpType] ~= nil) then
        if (self.activeInputController and self.activeInputController == self.inputControllers[MoveKeyboard]) then
            return
        end

        self:switchInputController(MoveKeyboard)
        print("switching to keyboard controller")
    end
end

function InputManager:updateTouchGuiVisibility()
    if (self.touchGui) then
        self.touchGui.Enabled = GuiService.TouchControlsEnabled
    end
end

return InputManager.new()