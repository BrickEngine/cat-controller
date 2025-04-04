local AnimClipProviderService = game:GetService("AnimationClipProvider")

local ANIMS = {
	-- ground | idle
    Idle = "rbxassetid://76728544462648",
    Crouch = "rbxassetid://91356839033018",
	-- ground | movement
    Sneak = "rbxassetid://82906371497519",
    Walk = "rbxassetid://79536250580622",
    Trot = "rbxassetid://81560499422968",
    Run = "rbxassetid://90228280985497",
	-- ground | actions
    Sit = "rbxassetid://86378703965993",
	-- water
	--SWIM = "",
	-- air
	--FALL = ""
}

local function createDefaultState(animTrack: any)
	return {
		enter = function(self, ...)
			animTrack:Play(...)
		end,
		leave = function(self, fdt: number?)
			animTrack:Stop(fdt)
		end,
		adjustSpeed = function(self, speed: number)
			animTrack:AdjustSpeed(speed)
		end,
		adjustWeight = function(self, weight: number)
			animTrack:AdjustWeight(weight)
		end
	}
end

local Animation = {}
Animation.__index = Animation

export type AnimationStateType = {
    typeof(Animation.State)
}

function Animation.new(simulation)
    local self = setmetatable({}, Animation)

    self.animationState = self.states.None :: AnimationStateType
	self.animationController = Instance.new("AnimationController", simulation.character)
	self.animator = Instance.new("Animator", self.animationController)

	self.animTracks = {} :: {[string]: AnimationTrack}
	for animName: string, animId: string in pairs(ANIMS) do
		local animInst = Instance.new("Animation", self.animator)
		animInst.AnimationId = animId; animInst.Name = animName

		self.animTracks[animName] = self.animator:LoadAnimation(animInst) :: AnimationTrack
		self.states[animName] = createDefaultState(self.animTracks[animName])
	end

	return self
end

Animation.states = {
	None = {
		enter = function() end,
		leave = function() end,
		adjustSpeed = function() end,
		adjustWeight = function() end
	}
	-- specific states added after Animation object is constructed
}

function Animation:setState(newState: AnimationStateType)
	assert(newState, "specify newState")

	if (newState == self.animationState) then
		return
	end
	self.animationState:leave()
	self.animationState = newState
	self.animationState:enter()
end

function Animation:destroy()
	setmetatable(self, nil)
end

return Animation