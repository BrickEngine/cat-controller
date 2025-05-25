local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local controller = script.Parent.Parent
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local InputManager = require(controller.InputManager)
local BaseState = require(controller.SimStates.BaseState)
--local self.animation = require(controller.Animation)
local PhysCheck = require(controller.Common.PhysCheck)

local GND_WALK_SPEED = 1
local GND_RUN_SPEED = 2.5
local GND_CLEAR = 0.4
local MAX_INCLINE = 60 -- deg
local JUMP_HEIGHT = 6 -- studs
local JUMP_TIME = 0.4
local PHYS_DT = 0.05
local MOVE_DAMP = 5
local HUGE_TORQUE = 2000000000
local ROT_LERP_DT = 0.25

local PHYS_RADIUS = CharacterDef.PARAMS.LEGCOLL_SIZE.Z * 0.5
local HIP_HEIGHT = CharacterDef.PARAMS.LEGCOLL_SIZE.X -- due to rotation X instead of Y
local COLL_HEIGHT = CharacterDef.PARAMS.MAINCOLL_SIZE.X -- due to rotation X instead of Y

local VEC3_ZERO = Vector3.zero
local VEC3_UP = Vector3.new(0, 1, 0)
local PI2 = math.pi*2

local ray_params = RaycastParams.new()
ray_params.CollisionGroup = CollisionGroups.PLAYER
ray_params.FilterType = Enum.RaycastFilterType.Exclude
ray_params.IgnoreWater = true
ray_params.RespectCanCollide = true

local jTime = 0
local jSignal = false

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
    rotForce.Attachment0 = att
    rotForce.AlignType = Enum.AlignType.AllAxes
    rotForce.Responsiveness = 200
    rotForce.MaxTorque = HUGE_TORQUE
    rotForce.MaxAngularVelocity = math.huge
    rotForce.Parent = mdl.PrimaryPart

    local posForce = Instance.new("AlignPosition")
    posForce.Attachment0 = att
    posForce.Mode = Enum.PositionAlignmentMode.OneAttachment
    posForce.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    posForce.MaxAxesForce = Vector3.zero
    posForce.MaxVelocity = 50000
    posForce.Responsiveness = 200
    posForce.Position = mdl.PrimaryPart.CFrame.Position
    posForce.Parent = mdl.PrimaryPart

    return {
        moveForce = moveForce,
        rotForce = rotForce,
        posForce = posForce
    }
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
	local ru = upu:Cross((-look).Unit).Unit
	-- orthonormalize, keeping up vector
	local looku = -upu:Cross(ru).Unit
	return CFrame.new(0, 0, 0, ru.x, upu.x, looku.x, ru.y, upu.y, looku.y, ru.z, upu.z, looku.z)
end

local function calcWalkAccel(moveVec: Vector3, rootPos: Vector3, currVel: Vector3, dt: number): Vector3
    local isRunning = InputManager:getIsRunning()
    local target
    if (isRunning) then
        target = rootPos - moveVec*GND_RUN_SPEED
    else
        target = rootPos - moveVec*GND_WALK_SPEED
    end
    return 2*((target - rootPos) - currVel*dt)/(dt*dt*MOVE_DAMP), isRunning
end

function accelFromDispl(posDiff: number, vel: number, downForce: number, dt: number): number
    --print(posDiff)
    local fac = 1
    if (posDiff <= 0.5) then
        fac = posDiff
    end
    return downForce + (2*(posDiff - vel*dt))/(dt*dt)
end

function substepAccel(vel: number, pos: number, targetPos: number, downForce: number, numSteps: number, dt: number): number
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

local function lerpAngle(a0: number, a1: number, t: number): number
	return a0 + angleShortest(a0, a1)*t
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

---------------------------------------------------------------------------------------

local Ground = setmetatable({}, BaseState)
Ground.__index = Ground

function Ground.new(...)
    local self = setmetatable(BaseState.new(...) :: BaseState.BaseStateType, Ground) :: any

    self.character = self._simulation.character :: Model
    self.forces = createForces(self.character)

    self.animation = self._simulation.animation

    return self
end

function Ground:stateEnter()
    if (not self.animation) then
        error("animations not initialized")
    end

    self.animation:setState("Idle")
end

function Ground:stateLeave()
    if (not self.forces) then
        return
    end

    for _, f: Instance in self.forces do
        f.Enabled = false
    end
end

local lastTargetAng = 0
local lastTargetPosY = 0
local gndLeft = false

function Ground:update(dt: number)
    local primaryPart: BasePart = self.character.PrimaryPart
    local camCFrame: CFrame = Workspace.CurrentCamera.CFrame
    local currVel: Vector3 = primaryPart.AssemblyLinearVelocity
    local currPos: Vector3 = primaryPart.CFrame.Position
    local mass: number = primaryPart.AssemblyMass

    -- do phys checks
    local physData: PhysCheck.physData = PhysCheck(
        currPos,
        PHYS_RADIUS,
        HIP_HEIGHT,
        COLL_HEIGHT,
        MAX_INCLINE,
        GND_CLEAR,
        ray_params
    )
    -- TODO: move air logic to air state
    if (physData.inWater) then
        self._simulation:transitionState(self._simulation.states.Water)
    end

    local moveDirVec = getCFrameRelMoveVec(camCFrame)
    local currHoriVel = Vector3.new(currVel.X, 0, currVel.Z)
    local accelVec, isRunning = calcWalkAccel(
        moveDirVec, currPos, currHoriVel, PHYS_DT
    )

    -- primaryPart rotation based on vecForce direction
    local lookVec = primaryPart.CFrame.LookVector
    if (currHoriVel.Magnitude > 0.1) then
        local currAng = math.atan2(lookVec.Z, lookVec.X)
        local targetAng
        if (moveDirVec.Magnitude > 0.05) then
            targetAng = math.atan2(-moveDirVec.Z, -moveDirVec.X)
        else
            targetAng = lastTargetAng
        end
        --local targetAng = math.atan2(-moveDirVec.Z, -moveDirVec.X)
        --targetAng = lerpAngle(currAng, targetAng, LERP_DELTA * currVel.Magnitude)

        if (math.abs(angleShortest(currAng, targetAng)) > 0) then
            targetAng = lerpAngle(currAng, targetAng, ROT_LERP_DT)
        end

        self.forces.rotForce.CFrame = makeCFrame(
            VEC3_UP, Vector3.new(math.cos(targetAng), 0, math.sin(targetAng))
        )

        lastTargetAng = targetAng
    end

    if (physData.grounded) then
        gndLeft = false

        if (currHoriVel.Magnitude > 0.5) then
            if (isRunning) then
                self.animation:setState("Run")
                self.animation:adjustSpeed(currHoriVel.Magnitude*0.05)
            else
                self.animation:setState("Walk")
                self.animation:adjustSpeed(currHoriVel.Magnitude*0.1)
            end
        else
            self.animation:setState("Idle")
            self.animation:adjustSpeed(1)
        end

        local targetPosY = physData.gndHeight + HIP_HEIGHT
        if (physData.atCeiling) then
            targetPosY = primaryPart.CFrame.Position.Y
        end

        -- handle jumping
        if (jTime <= 0 or currVel.Y < 0) then
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
            primaryPart:ApplyImpulse(Vector3.new(0, jumpInitVel-currVel.Y, 0)*mass)

            jTime = JUMP_TIME
            self.forces.posForce.Enabled = false
        end

        local accelUp = substepAccel(currVel.Y, currPos.Y, physData.gndHeight + HIP_HEIGHT, workspace.Gravity, 3, PHYS_DT)

        self.forces.posForce.Position = Vector3.new(0, targetPosY, 0)
        self.forces.posForce.MaxAxesForce = Vector3.new(0, (Workspace.Gravity + math.abs(accelUp)*5)*mass, 0)
        self.forces.moveForce.Force = accelVec*mass --(Vector3.new(0, accelUp, 0) + accelVec)*mass*3

        lastTargetPosY = targetPosY
    else
        --self.animation:setState()
        if (not gndLeft and jTime <= 0 and currVel.Y > 0) then
            gndLeft = true
            primaryPart.AssemblyLinearVelocity = Vector3.new(currVel.X, 0, currVel.Z)
        end
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