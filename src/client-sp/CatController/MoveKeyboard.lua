local Players = game:GetService("Players")
-- Keyboard controls

local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local BaseInput = require(script.Parent.BaseInput)
local ContextActions = require(script.Parent.ContextActions)

local VEC3_ZERO = Vector3.zero
local KEY_W = Enum.KeyCode.W
local KEY_S = Enum.KeyCode.S
local KEY_A = Enum.KeyCode.A
local KEY_D = Enum.KeyCode.D
local KEY_UP = Enum.KeyCode.Up
local KEY_DOWN = Enum.KeyCode.Down
local KEY_RUN = Enum.KeyCode.LeftShift
local KEY_JUMP = Enum.KeyCode.Space

local MoveKeyboard = setmetatable({}, BaseInput)
MoveKeyboard.__index = MoveKeyboard

function MoveKeyboard.new(CONTROL_PRIORITY: number)
    local self = setmetatable(BaseInput.new() :: any, MoveKeyboard)

    self.CONTROL_PRIORITY = CONTROL_PRIORITY

    return self
end

function MoveKeyboard:enable(enable: boolean)
    if (enable == self.enabled) then
        return true
    end

    self.f_val, self.b_val, self.l_val, self.r_val = 0, 0, 0, 0
	self.jumpInp, self.runInp = false, false
    self.moveVec = VEC3_ZERO
	self.isJumping = false
	self.isRunning = false

	if (enable) then
		self:bindActions()
		self:connectFocusEventListeners()
	else
		self._connectionUtil:disconnectAll()
	end

	self.enabled = enable
    return true
end

function MoveKeyboard:updateRun()
	self.isRunning = self.runInp
end

function MoveKeyboard:updateJump()
	self.isJumping = self.jumpInp
end

function MoveKeyboard:updateInputVec(inputState: Enum.UserInputState)
    if (inputState == Enum.UserInputState.Cancel) then
        self.moveVec = VEC3_ZERO
    else
        self.moveVec = Vector3.new(self.l_val + self.r_val, 0, self.f_val + self.b_val)
    end
end

function MoveKeyboard:bindActions()
	local handleMoveForward = function(actionName, inputState, inputObject)
		self.f_val = (inputState == Enum.UserInputState.Begin) and 1 or 0
		self:updateInputVec(inputState)
		return Enum.ContextActionResult.Pass
	end
	local handleMoveBackward = function(actionName, inputState, inputObject)
		self.b_val = (inputState == Enum.UserInputState.Begin) and -1 or 0
		self:updateInputVec(inputState)
		return Enum.ContextActionResult.Pass
	end
	local handleMoveLeft = function(actionName, inputState, inputObject)
		self.l_val = (inputState == Enum.UserInputState.Begin) and 1 or 0
		self:updateInputVec(inputState)
		return Enum.ContextActionResult.Pass
	end
	local handleMoveRight = function(actionName, inputState, inputObject)
		self.r_val = (inputState == Enum.UserInputState.Begin) and -1 or 0
		self:updateInputVec(inputState)
		return Enum.ContextActionResult.Pass
	end
	local handleJumpAction = function(actionName, inputState, inputObject)
		self.jumpInp = (inputState == Enum.UserInputState.Begin)
		self:updateJump()
		return Enum.ContextActionResult.Pass
	end
	local handleRunAction = function(inputObject)
		self.runInp = UserInputService:IsKeyDown(inputObject)
		self:updateRun()
	end

	ContextActionService:BindActionAtPriority(ContextActions.MOVE_F, handleMoveForward, false, self.CONTROL_PRIORITY, KEY_W, KEY_UP)
	ContextActionService:BindActionAtPriority(ContextActions.MOVE_B, handleMoveBackward, false, self.CONTROL_PRIORITY, KEY_S, KEY_DOWN)
	ContextActionService:BindActionAtPriority(ContextActions.MOVE_L, handleMoveLeft, false, self.CONTROL_PRIORITY, KEY_A)
	ContextActionService:BindActionAtPriority(ContextActions.MOVE_R, handleMoveRight, false, self.CONTROL_PRIORITY, KEY_D)
	ContextActionService:BindActionAtPriority(ContextActions.JUMP, handleJumpAction, false, self.CONTROL_PRIORITY, KEY_JUMP)
	--ContextActionService:BindActionAtPriority(ContextActions.RUN, handleRunAction, false, self.CONTROL_PRIORITY, KEY_RUN)
	RunService:BindToRenderStep(ContextActions.RUN, self.CONTROL_PRIORITY, function() handleRunAction(KEY_RUN) end)

	self._connectionUtil:trackBoundFunction(ContextActions.MOVE_F, function() ContextActionService:UnbindAction(ContextActions.MOVE_F) end)
	self._connectionUtil:trackBoundFunction(ContextActions.MOVE_B, function() ContextActionService:UnbindAction(ContextActions.MOVE_B) end)
	self._connectionUtil:trackBoundFunction(ContextActions.MOVE_L, function() ContextActionService:UnbindAction(ContextActions.MOVE_L) end)
	self._connectionUtil:trackBoundFunction(ContextActions.MOVE_R, function() ContextActionService:UnbindAction(ContextActions.MOVE_R) end)
	self._connectionUtil:trackBoundFunction(ContextActions.JUMP, function() ContextActionService:UnbindAction(ContextActions.JUMP) end)
	--self._connectionUtil:trackBoundFunction(ContextActions.RUN, function() ContextActionService:UnbindAction(ContextActions.RUN) end)
	self._connectionUtil:trackBoundFunction(ContextActions.RUN, function() RunService:UnbindFromRenderStep(ContextActions.RUN) end)
end

function MoveKeyboard:connectFocusEventListeners()
	local function onFocusReleased()
		self.moveVector = VEC3_ZERO
		self.f_val, self.b_val, self.l_val, self.r_val = 0, 0, 0, 0
		self.jumpInp, self.runInp = false, false

		self:updateJump()
		self:updateRun()
	end

	local function onTextFocusGained(textboxFocused)
		self.moveVector = VEC3_ZERO
		self.f_val, self.b_val, self.l_val, self.r_val = 0, 0, 0, 0
		self.jumpInp, self.runInp = false, false

		self:updateJump()
		self:updateRun()
	end

	self._connectionUtil:trackConnection("textBoxFocusReleased", UserInputService.TextBoxFocusReleased:Connect(onFocusReleased))
	self._connectionUtil:trackConnection("textBoxFocused", UserInputService.TextBoxFocused:Connect(onTextFocusGained))
	self._connectionUtil:trackConnection("windowFocusReleased", UserInputService.WindowFocused:Connect(onFocusReleased))
end

return MoveKeyboard