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

local GND_WALK_SPEED = 1
local GND_RUN_SPEED = 2
local MAX_INCLINE = 60 -- deg
local JUMP_HEIGHT = 6 -- studs
local PHYS_SUBSTEP_NUM = 3
local MOVE_DT = 0.05
local MOVE_DAMP = 5
local LERP_DELTA = 0.9

local COLL_RADIUS = CharacterDef.PARAMS.MAINCOLL_SIZE.X
local HIP_HEIGHT = CharacterDef.PARAMS.LEGCOLL_SIZE.Y

local VEC3_ZERO = Vector3.zero
local PI2 = math.pi*2

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

local function createAliOri(mdl: Model): AlignOrientation
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

local function createVecForce(mdl: Model): VectorForce
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

local function createAliPos(mdl: Model): AlignPosition
    local aliPosAtt = Instance.new("Attachment")
    aliPosAtt.Name = "AliPosAttachment"
    aliPosAtt.Parent = mdl.PrimaryPart
    local aliPos = Instance.new("AlignPosition")
    aliPos.Attachment0 = aliPosAtt
    aliPos.Mode = Enum.PositionAlignmentMode.OneAttachment
    aliPos.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    aliPos.MaxAxesForce = Vector3.new(0, 8000000, 0)
    aliPos.MaxVelocity = 100
    aliPos.Responsiveness = 120
    aliPos.Position = mdl.PrimaryPart.CFrame.Position
    aliPos.Parent = mdl

    return aliPos
end

local function createForces(mdl: Model)
    local att = Instance.new("Attachment")
    att.Name = "Ground"
    att.Parent = mdl.PrimaryPart

    local moveForce = Instance.new("VectorForce")
    moveForce.Attachment0 = att
    moveForce.RelativeTo = Enum.ActuatorRelativeTo.World
    moveForce.Parent = mdl.PrimaryPart

    local rotForce = Instance.new("AlignOrientation")
    rotForce.Mode = Enum.OrientationAlignmentMode.OneAttachment
    --rotForce.AlignType = Enum.AlignType.PrimaryAxisPerpendicular
    rotForce.RigidityEnabled = true
    rotForce.ReactionTorqueEnabled, rotForce.RigidityEnabled = true, true
    rotForce.Parent = mdl.PrimaryPart

    local posForce = Instance.new("AlignPosition")
    posForce.Attachment0 = att
    posForce.Mode = Enum.PositionAlignmentMode.OneAttachment
    posForce.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    posForce.MaxAxesForce = Vector3.new(0, 8000000, 0)
    posForce.MaxVelocity = 200
    posForce.Responsiveness = 120
    posForce.Position = mdl.PrimaryPart.CFrame.Position
    posForce.Parent = mdl

    return {
        moveForce = moveForce,
        rotForce = rotForce,
        posForce = posForce
    }
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
    self.forces = createForces(self.character)

    return self
end

function Ground:stateEnter()
    if (self.forces) then
        warn("forces already exist") return
    end
    -- self.forces = {
    --     moveForce = createVecForce(self.character),
    --     rotForce = createAliOri(self.character),
    --     posForce = createAliPos(self.character)
    -- }
end

function Ground:stateLeave()
    if (not self.forces) then
        return
    end

    -- for _, v: Instance in pairs(self.forces) do
    --     v:Destroy()
    -- end
end

local lastAccelY = 0
function Ground:update(dt: number)
    local primaryPart: BasePart = self.character.PrimaryPart
    local camCFrame: CFrame = Workspace.CurrentCamera.CFrame
    local currVel: Vector3 = primaryPart.AssemblyLinearVelocity
    local currPos: Vector3 = primaryPart.CFrame.Position
    local mass: number = primaryPart.AssemblyMass

    local jumpInitVel: number = math.sqrt(Workspace.Gravity * 2 * JUMP_HEIGHT)

    local physData: PhysCheck.physData = PhysCheck(
        currPos, COLL_RADIUS, HIP_HEIGHT, MAX_INCLINE, ray_params
    )

    -- TODO: move air logic to air state
    -- if (not physData.grounded) then
    --     self._stateMachine:transitionState(self._stateMachine.states.Air)
    -- end
    -- if (physData.inWater) then
    --     self._stateMachine:transitionState(self._stateMachine.states.Water)
    -- end

    local moveDirVec = getCFrameRelMoveVec(camCFrame)
    local horiAccelVec = calcWalkAccel(
        moveDirVec, currPos, Vector3.new(currVel.X, 0, currVel.Z), MOVE_DT--phys_dt
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
        self.forces.posForce.Enabled = true
        self.forces.moveForce.Enabled = true
        local targetPosY = physData.gndHeight + HIP_HEIGHT
        --local gravity = Workspace.Gravity
        --local accelY = 0
        --local posDiff = targetPosY - currPosY
        --local phys_dt: number = math.max(PHYS_DT, dt)
        --accelY = PhysUtil.substepAccel(currVel.Y, currPosY, targetPosY, gravity, PHYS_SUBSTEP_NUM, phys_dt)
        --accelY = PhysUtil.accelFromDispl((targetPosY-currPosY), currVel.Y, gravity, phys_dt)
        --accelY = math.max(-1, accelY)

        --TEST POSFORCE
        self.forces.posForce.Position = Vector3.new(0, targetPosY, 0)
        self.forces.moveForce.Force = horiAccelVec*mass --(Vector3.new(0, accelY, 0) + horiAccelVec)*mass
    else
        self.forces.moveForce.Force = VEC3_ZERO
        self.forces.moveForce.Enabled, self.forces.posForce.Enabled = false, false
    end
end

function Ground:destroy()
    if (self.forces) then
        for i, force in pairs(self.forces) do
            (self.forces[i] :: Instance):Destroy()
        end
    end
    (self.character :: Model):Destroy()
    setmetatable(self, nil)
    print("I am being terminated")
end

return Ground