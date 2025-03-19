--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
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
local GND_CLEAR = 0.5
local MAX_INCLINE = 60 -- deg
local JUMP_HEIGHT = 6 -- studs
local JUMP_TIME = 0.15
local MIN_STEP_HEIGHT = 0.1
local PHYS_DT = 0.05
local MOVE_DAMP = 5
local LERP_DELTA = 0.9

local PHYS_RADIUS = CharacterDef.PARAMS.LEGCOLL_SIZE.X * 0.5
local HIP_HEIGHT = CharacterDef.PARAMS.LEGCOLL_SIZE.X -- due to rotation X instead of Y
local COLL_HEIGHT = CharacterDef.PARAMS.MAINCOLL_SIZE.X -- due to rotation X instead of Y
local COLL_CF = CharacterDef.PARAMS.MAINCOLL_CF

local VEC3_ZERO = Vector3.zero
local PI2 = math.pi*2

local ray_params = RaycastParams.new()
ray_params.CollisionGroup = CollisionGroups.PLAYER
ray_params.FilterType = Enum.RaycastFilterType.Exclude
ray_params.IgnoreWater = true
ray_params.RespectCanCollide = true

local collCheckPart: Part = Instance.new("Part")
collCheckPart.Shape = CharacterDef.PARAMS.MAINCOLL_SHAPE
collCheckPart.Size = CharacterDef.PARAMS.MAINCOLL_SIZE
collCheckPart.CanCollide = false; collCheckPart.Anchored = true
collCheckPart.Transparency = 0.1
collCheckPart.Parent = Workspace

local collCheckParams = OverlapParams.new()
collCheckParams.RespectCanCollide = true
collCheckParams.FilterType = Enum.RaycastFilterType.Exclude
collCheckParams.FilterDescendantsInstances = {}

local jTime = 0
local jSignal = false
local inJump = false

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

function accelFromDispl(posDiff: number, vel: number, downForce: number, dt: number)
    --print(posDiff)
    local fac = 1
    if (posDiff <= 0.5) then
        fac = posDiff
    end
    return downForce + (2*(posDiff - vel*dt))/(dt*dt)
end

function substepAccel(vel: number, pos: number, targetPos: number, downForce: number, numSteps: number, dt: number)
    local accel = accelFromDispl((targetPos-pos), vel, downForce, dt)

    local stepAccel = accel
    local stepVel = vel
    local stepPos = pos
    local t = dt / numSteps

    for i=1, numSteps-1, 1 do
        local stepNetAccel = stepAccel - downForce
        local predVel = stepNetAccel*t
        local predPosDisp = (vel*t) + (0.5*predVel*t)
        local predAccel = downForce + 2*((targetPos - (stepPos + predPosDisp) - stepVel*t) / t*t)

        stepAccel = (accel + predAccel) * 0.5
        stepVel = (predVel + vel) * 0.5
        stepPos = (predPosDisp + pos) * 0.5
    end

    return stepAccel, stepVel, stepPos
end

local function createForces(mdl: Model): {[string]: Instance}
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
    posForce.MaxAxesForce = Vector3.zero
    posForce.MaxVelocity = 200
    posForce.Responsiveness = 180--120
    posForce.Position = mdl.PrimaryPart.CFrame.Position
    posForce.Parent = mdl.PrimaryPart

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

local function jumpSignal()
	if (InputManager:getIsJumping()) then
		if (not jSignal) then
			jSignal = true
			return true
		end
	else
		jSignal = false
	end
	return false
end

local function decrementCounter(count: number, dt: number): number
    count -= dt
    if (count < 0) then count = 0 end
    return count
end

local function preMoveStep(pos: Vector3, stepDiff: number, collParams: OverlapParams)
    collCheckPart.CFrame = CFrame.new(pos + Vector3.new(0, COLL_HEIGHT*0.5, 0)) * CFrame.Angles(math.rad(90), math.rad(90), 0)
    --print(collCheckPart.CFrame.Position)

    if (stepDiff >= MIN_STEP_HEIGHT) then
        local partArr: {[number]: Instance} = Workspace:GetPartsInPart(collCheckPart, collParams)
        print(partArr)
        if (#partArr > 0) then
            return false
        end
    end

    return true
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
        warn("forces already exist")
    end
    -- self.forces = {
    --     moveForce = createVecForce(self.character),
    --     rotForce = createAliOri(self.character),
    --     posForce = createAliPos(self.character)
    -- }
    local tbl = {}
    for _, v: Instance in pairs(self.character:GetChildren()) do
        if v:IsA("BasePart") then
            table.insert(tbl, v)
        end
    end
    collCheckParams.FilterDescendantsInstances = tbl
end

function Ground:stateLeave()
    if (not self.forces) then
        return
    end

    for _, force: Instance in self.forces do
        force.Enabled = false
    end

    -- for _, v: Instance in pairs(self.forces) do
    --     v:Destroy()
    -- end
end

function Ground:update(dt: number)
    local primaryPart: BasePart = self.character.PrimaryPart
    local camCFrame: CFrame = Workspace.CurrentCamera.CFrame
    local currVel: Vector3 = primaryPart.AssemblyLinearVelocity
    local currPos: Vector3 = primaryPart.CFrame.Position
    local mass: number = primaryPart.AssemblyMass

    local physData: PhysCheck.physData = PhysCheck(
        currPos, PHYS_RADIUS, HIP_HEIGHT, MAX_INCLINE, GND_CLEAR, ray_params
    )
    -- TODO: move air logic to air state
    -- if (not physData.grounded) then
    --     self._simulation:transitionState(self._simulation.states.Air)
    -- end
    if (physData.inWater) then
        self._simulation:transitionState(self._simulation.states.Water)
    end

    if (currVel.Y < 0) then
        inJump = false
    end

    local moveDirVec = getCFrameRelMoveVec(camCFrame)
    local accelVec = calcWalkAccel(
        moveDirVec, currPos, Vector3.new(currVel.X, 0, currVel.Z), PHYS_DT
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

        local targetPosY = physData.gndHeight + HIP_HEIGHT

        if (jTime <= 0 or not inJump) then
            self.forces.posForce.Enabled = true
        end

        if (jumpSignal() and jTime <= 0) then
            -- temp sound for fun
            do
                local s = Instance.new("Sound")
                s.SoundId = "rbxassetid://5466166437"
                SoundService:PlayLocalSound(s)
                s:Destroy()
            end
            local jumpInitVel: number = math.sqrt(Workspace.Gravity * 2 * JUMP_HEIGHT)
            --primaryPart.AssemblyLinearVelocity = Vector3.new(currVel.X, jumpInitVel, currVel.Z)
            primaryPart.AssemblyLinearVelocity = Vector3.new(currVel.X, 0, currVel.Z)
            primaryPart:ApplyImpulse(Vector3.new(0, jumpInitVel, 0)*mass)
            inJump = true; jTime = JUMP_TIME
            self.forces.posForce.Enabled = false
        end

        if (jTime <= 0 or not inJump) then
            self.forces.posForce.Enabled = true
        end

        local accelUp = substepAccel(currVel.Y, currPos.Y, physData.gndHeight + HIP_HEIGHT, workspace.Gravity, 3, PHYS_DT)

        self.forces.posForce.Position = Vector3.new(0, targetPosY, 0)
        self.forces.posForce.MaxAxesForce = Vector3.new(0, (Workspace.Gravity + math.abs(accelUp)*2)*mass, 0)
        self.forces.moveForce.Force = accelVec*mass*1.8 --(Vector3.new(0, accelUp, 0) + accelVec)*mass*1.8
    else
        self.forces.moveForce.Force = accelVec*mass*0.1
        self.forces.posForce.Enabled = false
    end

    jTime = decrementCounter(jTime, dt)
end

function Ground:destroy()
    if (self.forces) then
        for i, force in pairs(self.forces) do
            (self.forces[i] :: Instance):Destroy()
        end
    end
    setmetatable(self, nil)
end

return Ground