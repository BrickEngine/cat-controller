--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local controller = script.Parent.Parent
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local InputManager = require(controller.InputManager)
local BaseState = require(controller.SimStates.BaseState)
local PhysCheck = require(controller.Common.PhysCheck)
local PhysUtil = require(controller.Common.PhysUtil)

local DV = require(script.Parent.Parent.Common.DebugVisualize)

local GND_WALK_SPEED = 1
local GND_RUN_SPEED = 5
local PHYS_SUBSTEP_NUM = 3
local PHYS_DT = 0.05
local MOVE_DAMP = 5
local JUMP_HEIGHT = 6
local PHYS_DELTA = 2
local LERP_DELTA = 0.9
local COLL_RADIUS = CharacterDef.PARAMS.MAINCOLL_SIZE.X
local HIP_HEIGHT = CharacterDef.PARAMS.LEGCOLL_SIZE.Y

local VEC3_ZERO = Vector3.zero
local PI2 = math.pi * 2

local ray_params = RaycastParams.new()
ray_params.CollisionGroup = CollisionGroups.PLAYER
ray_params.FilterType = Enum.RaycastFilterType.Exclude
ray_params.IgnoreWater = true
ray_params.RespectCanCollide = true

local function angleAbs(angle: number): number
	while angle < 0 do
		angle += PI2
	end
	while angle > PI2 do
		angle  -= PI2
	end
	return angle
end

local function angleShortest(a0: number, a1: number): number
	local d1 = angleAbs(a1 - a0)
	local d2 = -angleAbs(a0 - a1)
	return math.abs(d1) > math.abs(d2) and d2 or d1
end

local function lerpAngle(a0: number, a1: number, alpha: number): number
	return a0 + angleShortest(a0, a1)*alpha
end

local function getCFrameRelMoveVec(camCFrame: CFrame): Vector3
    return CFrame.new(
        VEC3_ZERO,
        Vector3.new(
            camCFrame.LookVector.X, 0, camCFrame.LookVector.Z
        ).Unit
    ):VectorToWorldSpace(InputManager:getMoveVec())
end

local function makeCFrame(up, look)
	local upu = up.Unit
	local looku = (Vector3.new() - look).Unit
	local rightu = upu:Cross(looku).Unit
	-- orthonormalize, keeping up vector
	looku = -upu:Cross(rightu).Unit
	return CFrame.new(0, 0, 0, rightu.x, upu.x, looku.x, rightu.y, upu.y, looku.y, rightu.z, upu.z, looku.z)
end

local function calcWalkAccel(moveVec: Vector3, rootPos: Vector3, currVel: Vector3, dt: number): Vector3
    local target
    if (InputManager:getIsRunning()) then
        target = rootPos - moveVec*GND_RUN_SPEED
    else
        target = rootPos - moveVec*GND_WALK_SPEED
    end
    return 2*((target - rootPos) - currVel*dt)/(dt*dt*MOVE_DAMP)
end

local function createRotForce(mdl: Model)
    local forceAtt = Instance.new("Attachment")
    forceAtt.Name = "RotForceAttachment"
    forceAtt.Parent = mdl.PrimaryPart
    -- forceAtt.CFrame = CFrame.new(
    --     0, 0, 0,
    --     0, 0, 1,
    --     0, 1, 0,
    --     -1, 0, 0
    -- )
    local aliOri = Instance.new("AlignOrientation")
    --aliOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    --aliOri.AlignType = Enum.AlignType.PrimaryAxisPerpendicular
    aliOri.RigidityEnabled = true
    aliOri.ReactionTorqueEnabled = true
    aliOri.Attachment0 = forceAtt
    aliOri.Parent = mdl.PrimaryPart
    --aliOri.CFrame = mdl.PrimaryPart.CFrame

    return aliOri
end

local function createVecForce(mdl: Model)
    local forceAtt = Instance.new("Attachment")
    forceAtt.Name = "VecForceAttachment"
    forceAtt.Parent = mdl.PrimaryPart
    local vecForce = Instance.new("VectorForce")
    vecForce.Attachment0 = forceAtt
    vecForce.RelativeTo = Enum.ActuatorRelativeTo.World
    vecForce.ApplyAtCenterOfMass = true
    vecForce.Parent = mdl.PrimaryPart
    vecForce.Force = VEC3_ZERO

    return vecForce
end

-- dt = elapsed time
-- s = start
-- e = end
-- t = duration (total time)
local function easeOutQuart(dt, t, s, e)
    dt = dt/t - 1
    return -(e-s) * (dt^4 - 1) + s
end

---------------------------------------------------------------------------------------

local Ground = setmetatable({}, BaseState)
Ground.__index = Ground

function Ground.new(...)
    local self = setmetatable(BaseState.new(...) :: BaseState.BaseStateType, Ground) :: any

    self.character = self._simulation.character :: Model
    self.forces = nil

    return self
end

function Ground:stateEnter()
    if (self.forces) then
        warn("forces already exist") return
    end
    self.forces = {
        moveForce = createVecForce(self.character),
        rotForce = createRotForce(self.character)
    }
end

function Ground:stateLeave()
    if (not self.forces) then
        return
    end

    for _, v: Instance in pairs(self.forces) do
        v:Destroy()
    end
end

local lastAccelY = 0
function Ground:update(dt: number)
    local primaryPart: BasePart = self.character.PrimaryPart
    local camCFrame: CFrame = Workspace.CurrentCamera.CFrame
    local currVel: Vector3 = primaryPart.AssemblyLinearVelocity
    local currPos: Vector3 = primaryPart.CFrame.Position
    local mass: number = primaryPart.AssemblyMass
    local phys_dt: number = math.max(PHYS_DT, dt)

    local jumpInitVel: number = math.sqrt(Workspace.Gravity * 2 * JUMP_HEIGHT)

    local physData: PhysCheck.physData = PhysCheck(
        primaryPart.CFrame.Position,
        COLL_RADIUS,
        HIP_HEIGHT,
        ray_params
    )

    -- if (not physData.grounded) then
    --     self._stateMachine:transitionState(self._stateMachine.states.Air)
    -- end
    -- if (physData.inWater) then
    --     self._stateMachine:transitionState(self._stateMachine.states.Water)
    -- end
    local camRelMoveVec = getCFrameRelMoveVec(camCFrame)
    local horiAccelVec = calcWalkAccel(
        camRelMoveVec, primaryPart.CFrame.Position, Vector3.new(currVel.X, 0, currVel.Z), phys_dt
    )
    -- primaryPart rotation based on vecForce direction
    if (currVel.Magnitude > 0.05) then
        local currAng = math.atan2(primaryPart.CFrame.LookVector.Z, primaryPart.CFrame.LookVector.X)
        local targetAng = math.atan2(currVel.Z, currVel.X)
        if (math.abs(angleShortest(currAng, targetAng)) > math.pi*0.95) then
            targetAng = lerpAngle(currAng, targetAng, LERP_DELTA)
        end
        -- primaryPart.CFrame = CFrame.lookAlong(
        --     primaryPart.CFrame.Position, Vector3.new(math.cos(targetAng), 0, math.sin(targetAng))
        -- )
        --self.forces.rotForce.CFrame = makeCFrame(Vector3.new(0, 1, 0), Vector3.new(math.cos(targetAng), 0, math.sin(targetAng)))
    end

    if (physData.grounded) then
        local currPosY = currPos.Y
        local targetPosY = physData.gndHeight + HIP_HEIGHT
        local gravity = Workspace.Gravity
        local accelY = 0

        accelY = PhysUtil.substepAccel(currVel.Y, currPosY, targetPosY, gravity, PHYS_SUBSTEP_NUM, phys_dt)
        --accelY = PhysUtil.accelFromDispl((targetPosY-currPosY), currVel.Y, gravity, phys_dt)
        --accelY = math.max(-1, accelY)
        self.forces.moveForce.Force = (Vector3.new(0, accelY, 0) + horiAccelVec)*mass
    else
        self.forces.moveForce.Force = Vector3.new(horiAccelVec.X, 0, horiAccelVec.Z)
    end

    DV.step()
end

return Ground