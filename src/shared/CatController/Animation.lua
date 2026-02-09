-- Main animation module. Instantiates all character dependent animation tracks

local function resetTrackVals(track: AnimationTrack)
	track:AdjustSpeed(1)
	track:AdjustWeight(1)
end

local Animation = {}
Animation.__index = Animation

Animation.states = {
	-- idle (0)
	Idle = {id = "rbxassetid://86097848386875", prio = 0},
	Crouch = {id = "rbxassetid://91356839033018", prio = 0},
	-- movement (1)
    Sneak = {id = "rbxassetid://82906371497519", prio = 1},
    Walk = {id = "rbxassetid://103722766186620", prio = 1},
    Trot = {id = "rbxassetid://84407680772559", prio = 1},
    Run = {id = "rbxassetid://101495361702146", prio = 1},
	--SWIM = "",
	--FALL = "",
	-- actions (2-5)
    Sit = {id = "rbxassetid://86378703965993", prio = 2},
}

export type AnimationStateType = {
    id: string,
	prio: number
}

function Animation.new(simulation)
    local self = setmetatable({}, Animation)

	self.character = simulation.character :: Model
	self.animationController = self.character:FindFirstChildOfClass("AnimationController")
	self.animator = self.animationController:FindFirstChildOfClass("Animator")

	self.currentState = "None"
	self.animTracks = {} :: {[string]: AnimationTrack}

	for animName: string, animData: AnimationStateType in pairs(self.states) do
		local animInst = Instance.new("Animation", self.animator)
		animInst.AnimationId = animData.id
		animInst.Name = animName

		self.animTracks[animName] = self.animator:LoadAnimation(animInst) :: AnimationTrack
		self.animTracks[animName].Priority = animData.prio
		self.animTracks[animName].Stopped:Connect(function()
			--print(animName .. " WAS STOPPED")
		end)
		self.animTracks[animName].Ended:Connect(function()
			--print(animName .. " HAS ENDEDEDED")
		end)
	end

	return self
end

function Animation:setState(newState: string, f_t: number?)
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