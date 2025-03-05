local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Controller = script.Parent.Parent
local BaseState = require(Controller.SimStates.BaseState)
local PhysCheck = require(Controller.Common.PhysCheck)
local InputManager = require(Controller.InputManager)

local NORMALIZE_INPUT = false
local GND_WALK_SPEED = 2.6
local GND_RUN_SPEED = 7.2
local CONST_MASS = 1
local VEC3_CAST_OFFSET = Vector3.new(0,-0.5,0)
local VEC3_ZERO = Vector3.zero
local RAY_PARAMS = RaycastParams.new()
RAY_PARAMS.CollisionGroup = "Player"
RAY_PARAMS.IgnoreWater = true
RAY_PARAMS.RespectCanCollide = true

local function getModelMass(mdl: Model)
	local mass = 0
	for _, v in ipairs(mdl:GetChildren()) do
		if v:IsA("BasePart") then
			mass += v:GetMass()
		else
			mass += getModelMass(v)
		end
	end
	return mass
end

local function getMoveVec()
    if (NORMALIZE_INPUT) then
        return InputManager:getMoveVec().Unit
    end
    return InputManager:getMoveVec()
end

local function calcWalkAccel(rootPos: Vector3, currentVel: number, dt: number): Vector3
    local target
    if (InputManager:getIsRunning()) then
        target = rootPos + getMoveVec() * GND_RUN_SPEED
    else
        target = rootPos + getMoveVec() * GND_WALK_SPEED
    end
    return 2 * ((target - rootPos) - currentVel * dt) / (dt * 0.4)
end

local function createVecForce(mdl: Model)
    local forceAtt = Instance.new("Attachment")
    forceAtt.Name = "ForceAttachment"
    forceAtt.Parent = mdl.PrimaryPart
    local vecForce = Instance.new("VectorForce") :: VectorForce
    vecForce.Attachment0 = forceAtt
    vecForce.RelativeTo = Enum.ActuatorRelativeTo.World
    vecForce.Parent = mdl.PrimaryPart
    vecForce.Force = VEC3_ZERO

    return vecForce
end

---------------------------------------------------------------------------------------

local Ground = setmetatable({}, BaseState)
Ground.__index = Ground

function Ground.new(stateMachine)
    local self = setmetatable(BaseState.new(stateMachine), Ground)

    self._stateMachine = stateMachine
    self.character = Players.LocalPlayer.Character
    self.vecForce = nil
    self.alignOri = nil

    return self
end

function Ground:stateEnter()
    if (self.forces) then
        warn("forces already exist") return
    end
    self.vecForce = createVecForce(self.character)
    --character = self._stateMachine.character
end

function Ground:stateLeave()
    if (not self.forces) then
        return
    end

    -- for _, v in pairs(self.forces) do
    --     if (v:IsA("VectorForce")) then
    --         v.diable
    --     end
    -- end
    --character = nil
end

function Ground:update(dt: number)
    --print(InputManager:getMoveVec())
    local primaryPart = self.character.PrimaryPart
    local currentVel = primaryPart.AssemblyLinearVelocity
    local moveAccel = calcWalkAccel(primaryPart.CFrame.Position, currentVel, dt)
    local accelX = moveAccel.X * CONST_MASS
    local accelZ = moveAccel.Z * CONST_MASS

    local physData: PhysCheck.physData = PhysCheck(
        primaryPart.CFrame.Position + VEC3_CAST_OFFSET,
        2,
        2,
        RAY_PARAMS
    )

    -- if (not physData.grounded) then
    --     self._stateMachine:transitionState(self._stateMachine.states.Air)
    -- end

    
end

return Ground