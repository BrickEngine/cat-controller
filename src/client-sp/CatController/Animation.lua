local Animation = {}
Animation.__index = Animation

local DEFAULT_ANIM_SPEED = 1
local ANIMS = {
	-- ground | idle
    IDLE = "rbxassetid://76728544462648",
    CROUCH = "rbxassetid://91356839033018",
	-- ground | movement
    SNEAK = "rbxassetid://82906371497519",
    WALK = "rbxassetid://79536250580622",
    TROT = "rbxassetid://81560499422968",
    RUN = "rbxassetid://90228280985497",
	-- ground | idle action
    SIT = "rbxassetid://86378703965993",
	-- water
	SWIM = "",
	-- air
	FALL = ""
}

local function animStateEnter(self, speed, prio)
    
end

local function animStateLeave(self)
    
end

Animation.State = {
	None = {
		enter = function() end,
		leave = function() end
	},
	Idle = {
		enter = function(self, speed)
			self.animations.IDLE:Play()
		end,
		leave = function(self)
			self.animations.IDLE:Stop()
		end,
        setSpeed = function(self, speed)
            self.animations.IDLE:AdjustSpeed(speed)
        end
	},
	Crouch = {
		enter = function(self, speed)
			self.animations.CROUCH:Play()
		end,
		leave = function(self)
			self.animations.CROUCH:Stop()
		end,
        setSpeed = function(self, speed)
            self.animations.CROUCH:AdjustSpeed(speed)
        end
	},
	Walk = {
		enter = function(self)
			self.animations.WALK:Play()
		end,
		leave = function(self)
			self.animations.WALK:Stop()
		end,
        setSpeed = function(self, speed)
            self.animations.CROUCH:AdjustSpeed(speed)
        end
	},
	-- Trot = {
	-- 	enter = function(self)
	-- 		self.animations.TROT:Play()
	-- 	end,
	-- 	leave = function(self)
	-- 		self.animations.TROT:Stop()
	-- 	end,
    --     setSpeed = function(self, speed)
    --         self.animations.CROUCH:AdjustSpeed(speed)
    --     end
	-- },
	Run = {
		enter = function(self)
			self.animations.RUN:Play()
		end,
		leave = function(self)
			self.animations.RUN:Stop()
		end,
        setSpeed = function(self, speed)
            self.animations.CROUCH:AdjustSpeed(speed)
        end
	},
    Sit = {
		enter = function(self)
			self.animations.SIT:Play()
		end,
		leave = function(self)
			self.animations.SIT:Stop()
		end
	},
    -- Swim = {
	-- 	enter = function(self)
	-- 		self.animations.SWIM:Play()
	-- 	end,
	-- 	leave = function(self)
	-- 		self.animations.SWIM:Stop()
	-- 	end
	-- },
    -- Fall = {
	-- 	enter = function(self)
	-- 		self.animations.FALL:Play()
	-- 	end,
	-- 	leave = function(self)
	-- 		self.animations.FALL:Stop()
	-- 	end
	-- },
}

export type AnimationState = {
    typeof(Animation.State)
}

function Animation.new(simulation)
    local self = setmetatable({}, Animation)

    self.simulation = simulation
    self.character = simulation.character
    self.animations = {} :: AnimationTrack
    self.animationState = Animation.State.None

    local animController = Instance.new("AnimationController")
    local animator = Instance.new("Animator")
    animController.Parent = simulation.character
    animator.Parent = animController

	self.animController = animController
    self.animator = animator

	for anim, id in pairs(ANIMS) do
		self.animations[anim] = self.animator:LoadAnimation(id)
	end

	return self
end

function Animation:setState(newState: AnimationState, speed: number, looped: boolean)
	assert(newState, "specify newState")

	if (newState == self.animationState) then
		return
	end
	self.animationState:leave()
	self.animationState = newState
	self.animationState:enter()
end

function Animation:setSpeed(speed: number)
    assert(speed >= 0, "speed must be a positive number")

    self.animationState:AdjustSpeed(speed)
end

return Animation