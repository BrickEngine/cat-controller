-- Main animation module. Instantiates all character dependent animation tracks

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AnimationStateId = require(ReplicatedStorage.Shared.Enums.AnimationStateId)

local updateConn = nil

local ANIM_FREEZE_MAP = table.freeze({
	[AnimationStateId.IDLE] = false,
	[AnimationStateId.CROUCH] = false,
	[AnimationStateId.DIE] = true,
    [AnimationStateId.SNEAK] = false,
    [AnimationStateId.WALK] = false,
    [AnimationStateId.TROT] = false,
    [AnimationStateId.RUN] = false,
	[AnimationStateId.SWIM] = false,
	[AnimationStateId.FALL] = true,
	[AnimationStateId.JUMP] = true,
    [AnimationStateId.SIT] = true,
})

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------

local Animation = {}
Animation.__index = Animation

Animation.states = {
	-- idle (0)
	[AnimationStateId.IDLE] = {id = "rbxassetid://86097848386875", prio = 0},
	[AnimationStateId.CROUCH] = {id = "rbxassetid://91356839033018", prio = 0},
	[AnimationStateId.DIE] = {id = "rbxassetid://73372813061276", prio = 0},
	-- movement (1)
    [AnimationStateId.SNEAK] = {id = "rbxassetid://82906371497519", prio = 1},
    [AnimationStateId.WALK] = {id = "rbxassetid://77304555003020", prio = 1}, -- Walk = {id = "rbxassetid://103722766186620", prio = 1},
    [AnimationStateId.TROT] = {id = "rbxassetid://77304555003020", prio = 1}, -- Trot = {id = "rbxassetid://84407680772559", prio = 1}, 
    [AnimationStateId.RUN] = {id = "rbxassetid://77304555003020", prio = 1}, -- Run = {id = "rbxassetid://101495361702146", prio = 1},
	[AnimationStateId.SWIM] = {id = "rbxassetid://87927102844491", prio = 1},
	[AnimationStateId.FALL] = {id = "rbxassetid://90056268589390", prio = 1},
	[AnimationStateId.JUMP] = {id = "rbxassetid://119229944563710", prio = 1},
	-- actions (2-5)
    [AnimationStateId.SIT] = {id = "rbxassetid://86378703965993", prio = 2},
}

export type AnimationState = {
    id: string,
	prio: number
}

function Animation.new(simulation)
    local self = setmetatable({}, Animation)

	self.character = simulation.character :: Model
	self.animationController = self.character:FindFirstChildOfClass("AnimationController")
	self.animator = self.animationController:FindFirstChildOfClass("Animator")

	assert(self.animationController:IsA("AnimationController"), "No AnimationController found")
	assert(self.animator:IsA("Animator"), "No Animator found")

	self.currentState = AnimationStateId.IDLE
	self.animTracks = {} :: {[string]: AnimationTrack}

	for animName: string, animData: AnimationState in pairs(self.states) do
		local animInst = Instance.new("Animation", self.animator)
		animInst.AnimationId = animData.id
		animInst.Name = animName

		self.animTracks[animName] = self.animator:LoadAnimation(animInst) :: AnimationTrack
		self.animTracks[animName].Priority = animData.prio
		self.animTracks[animName].Stopped:Connect(function()
			self:onAnimationStopped()
		end)
		self.animTracks[animName].Ended:Connect(function()

		end)
	end

	if (updateConn :: RBXScriptConnection) then
		updateConn:Disconnect()
	end
	updateConn = RunService.PreAnimation:Connect(function(dt: number)
		self:update(dt)
	end)

	return self
end

function Animation:update(dt: number)
	-- unused
end

function Animation:onAnimationStopped()
	if (not ANIM_FREEZE_MAP[self.currentState]) then
		return
	end

	local endedTrack = self.animTracks[self.currentState] :: AnimationTrack
	endedTrack.TimePosition = endedTrack.Length - 0.01
	endedTrack:AdjustSpeed(0)
end

function Animation:setState(newState: string, looped: boolean, f_t: number?)
	if (not newState) then
		error("missing newState parameter")
	end
	if (newState == self.currentState) then
		return
	end

	local fade = f_t or 0.100000001
 
	if (self.animTracks[self.currentState]) then
		self.animTracks[self.currentState]:Stop()
	end
	self.currentState = newState
	self.animTracks[self.currentState].Looped = looped
	self.animTracks[self.currentState]:Play(fade)
end

function Animation:adjustSpeed(speed: number)
	if (speed == self.animTracks[self.currentState].Speed) then
		return
	end
	self.animTracks[self.currentState]:AdjustSpeed(speed)
end

function Animation:destroy()
	for i, animTrack: AnimationTrack in pairs(self.animTracks) do
		animTrack:Destroy()
		self.animTracks[i] = nil
	end

	setmetatable(self, nil)
end

return Animation