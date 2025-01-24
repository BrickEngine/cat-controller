-- Keyboard controls

-- self.enabled = false
-- self.jumpDown = false
-- self.moveVec = VEC3_ZERO
-- self.__connectionUtil = ConnectionUtil.new()

ContextActionService = game:GetService("ContextActionService")

local BaseMoveInput = require(script.Parent.BaseMoveInput)
local ContextActions = require(script.Parent.ContextActions)

local VEC3_ZERO = Vector3.zero
local KEY_W = Enum.KeyCode.W
local KEY_S = Enum.KeyCode.S
local KEY_A = Enum.KeyCode.A
local KEY_D = Enum.KeyCode.D
local KEY_UP = Enum.KeyCode.Up
local KEY_DOWN = Enum.KeyCode.Down
local KEY_JUMP = Enum.KeyCode.Space

local MoveKeyboard = {}
MoveKeyboard.__index = MoveKeyboard

function MoveKeyboard.new(CONTROL_PRIORITY)
    local self = setmetatable(BaseMoveInput.new() :: any, MoveKeyboard)

    self.CONTROL_PRIORITY = CONTROL_PRIORITY

    self.f_val = 0
    self.b_val = 0
    self.l_val = 0
    self.r_val = 0

    return self
end

function MoveKeyboard:enable()
    if (self.enable) then
        return true
    end

    self.f_val, self.b_val, self.l_val, self.r_val, self.jumpInp = 0, 0, 0, 0, 0
    self.moveVec = VEC3_ZERO

    return true
end

function MoveKeyboard:updateInputVec(inputState: Enum.UserInputState)
    if (inputState == Enum.UserInputState.Cancel) then
        self.moveVec = VEC3_ZERO
    else
        self.moveVec = Vector3.new(self.l_val - self.r_val, 0, self.f_val - self.b_val)
    end
end

function MoveKeyboard:bindActions()
	local handleMoveForward = function(actionName, inputState, inputObject)
		self.f_val = (inputState == Enum.UserInputState.Begin) and -1 or 0
		self:updateInputVec(inputState)
		return Enum.ContextActionResult.Pass
	end
	local handleMoveBackward = function(actionName, inputState, inputObject)
		self.b_val = (inputState == Enum.UserInputState.Begin) and 1 or 0
		self:updateInputVec(inputState)
		return Enum.ContextActionResult.Pass
	end
	local handleMoveLeft = function(actionName, inputState, inputObject)
		self.l_val = (inputState == Enum.UserInputState.Begin) and -1 or 0
		self:updateInputVec(inputState)
		return Enum.ContextActionResult.Pass
	end
	local handleMoveRight = function(actionName, inputState, inputObject)
		self.r_val = (inputState == Enum.UserInputState.Begin) and 1 or 0
		self:updateInputVec(inputState)
		return Enum.ContextActionResult.Pass
	end
	local handleJumpAction = function(actionName, inputState, inputObject)
		self.jumpInp = (inputState == Enum.UserInputState.Begin) and 1 or 0
		return Enum.ContextActionResult.Pass
	end

	ContextActionService:BindActionAtPriority(ContextActions.MOVE_F, handleMoveForward, false, self.CONTROL_PRIORITY, KEY_W)
    ContextActionService:BindActionAtPriority(ContextActions.MOVE_F, handleMoveForward, false, self.CONTROL_PRIORITY, KEY_UP)
	ContextActionService:BindActionAtPriority(ContextActions.MOVE_B, handleMoveBackward, false, self.CONTROL_PRIORITY, KEY_S)
    ContextActionService:BindActionAtPriority(ContextActions.MOVE_F, handleMoveForward, false, self.CONTROL_PRIORITY, KEY_DOWN)
	ContextActionService:BindActionAtPriority(ContextActions.MOVE_L, handleMoveLeft, false, self.CONTROL_PRIORITY, KEY_A)
	ContextActionService:BindActionAtPriority(ContextActions.MOVE_R, handleMoveRight, false, self.CONTROL_PRIORITY, KEY_D)
	ContextActionService:BindActionAtPriority(ContextActions.JUMP, handleJumpAction, false, self.CONTROL_PRIORITY, KEY_JUMP)
	
	self._connectionUtil:trackBoundFunction(ContextActions.MOVE_F, function() ContextActionService:UnbindAction(ContextActions.MOVE_F) end)
	self._connectionUtil:trackBoundFunction(ContextActions.MOVE_B, function() ContextActionService:UnbindAction(ContextActions.MOVE_B) end)
	self._connectionUtil:trackBoundFunction(ContextActions.MOVE_L, function() ContextActionService:UnbindAction(ContextActions.MOVE_L) end)
	self._connectionUtil:trackBoundFunction(ContextActions.MOVE_R, function() ContextActionService:UnbindAction(ContextActions.MOVE_R) end)
	self._connectionUtil:trackBoundFunction(ContextActions.JUMP, function() ContextActionService:UnbindAction(ContextActions.JUMP) end)
end

return MoveKeyboard