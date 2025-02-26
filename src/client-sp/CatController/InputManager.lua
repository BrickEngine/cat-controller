local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")

local Controller = script.Parent
local MoveKeyboard = require(Controller.MoveKeyboard)
local MoveTouch = nil -- TODO

local lastInpType

local ACTION_PRIO = 100
local VEC3_ZERO = Vector3.zero

local InputManager = {}
InputManager.__index = InputManager

function InputManager.new()
    local self = setmetatable({}, InputManager)

    self.inputControllers = {}
    self.activeInputController = nil

    self.touchControlArea = nil
    self.playerGui = nil
	self.touchGui = nil
	self.playerGuiAddedConn = nil

	UserInputService.LastInputTypeChanged:Connect(function(newLastInputType)
        print(":::: INPUT SWITCH ::::")
		self:onLastInputTypeChanged(newLastInputType)
	end)

	GuiService:GetPropertyChangedSignal("TouchControlsEnabled"):Connect(function()
		self:updateTouchGuiVisibility()
	end)

	if UserInputService.TouchEnabled then
        -- TODO
		self.playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
		if self.playerGui then
			self:createTouchGuiContainer()
			self:onLastInputTypeChanged(UserInputService:GetLastInputType())
		else
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
	else
		self:onLastInputTypeChanged(UserInputService:GetLastInputType())
	end

    return self
end

------------------------------------------------------------------------------------------------------------------------------

function InputManager:getMoveVec()
    if (not self.activeInputController) then
        warn("no active input controller set")
        return VEC3_ZERO
    end
    return self.activeInputController:getMoveVec()
end

function InputManager:update(dt: number)
    self.stateMachine:update(dt, self.activeInputController)
end

function InputManager:getActiveInputController(): ({}?)
    return self.activeInputController
end

function InputManager:createTouchGuiContainer()
    -- TODO
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

    self.activeInputController:enable(true)
end

-- TODO: implement touch control switch
function InputManager:onLastInputTypeChanged(newlastInpType: Enum.UserInputType)
    if (lastInpType == newlastInpType) then
        warn("LastInputType Change listener called with current type")
    end

    lastInpType = newlastInpType
    if (lastInpType == Enum.UserInputType.Touch) then
        -- TODO
        -- local touchModule 
        -- self:switchInputController()
        print("switching to nonexistent touch controller")
        self:switchInputController(MoveKeyboard)
    else
        self:switchInputController(MoveKeyboard)
    end
end

return InputManager.new()