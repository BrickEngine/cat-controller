local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local controller = script.Parent.Parent
local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local PlayerStateId = require(ReplicatedStorage.Shared.Enums.PlayerStateId)
local AnimationStateId = require(ReplicatedStorage.Shared.Enums.AnimationStateId)
local SoundManager = require(ReplicatedStorage.Shared.SoundManager)
local InputManager = require(controller.InputManager)
local BaseState = require(controller.SimStates.BaseState)
local PhysCheck = require(controller.Common.PhysCheck)

-- physics
local GND_WALK_SPEED = 1
local GND_RUN_SPEED = 2.5
local GND_CLEAR = 0.5
local JUMP_HEIGHT = 6 -- studs
local JUMP_DELAY = 0.18
local MOVE_DAMP = 5
local MOVE_DT = 0.05
local ROT_DT = 0.25 -- lower value ~ slower rotation

-- animation speeds / threshold
local ANIM_TH_WALK = 0.1 -- studs/s
local ANIM_TH_TROT = 15 -- studs/s
local ANIM_TH_RUN = 50 -- studs/s
local ANIM_SPEED_FAC_WALK = 0.07
local ANIM_SPEED_FAC_RUN = 0.12

-- misc
local DO_JUMP_SOUND = true

-- constants
local PHYS_RADIUS = CharacterDef.PARAMS.LEGCOLL_SIZE.Z * 0.5
local HIP_HEIGHT = CharacterDef.PARAMS.LEGCOLL_SIZE.X
local VEC3_ZERO = Vector3.zero
local VEC3_UP = Vector3.new(0, 1, 0)
local PI2 = math.pi*2

local lastTargetAng = 0
local j_lastDown = false
local j_Delay = 0
local lastYPos = 0
local hasJumped = false
local jumpSignal = false
local offGroundTime = 0

-- Create required physics constraints
local function createForces(mdl: Model): {[string]: Instance}
    assert(mdl.PrimaryPart)

    local att = Instance.new("Attachment", mdl.PrimaryPart)
    att.Name = "Ground"

    local moveForce = Instance.new("VectorForce", mdl.PrimaryPart)
    moveForce.Enabled = false
    moveForce.Attachment0 = att
    moveForce.ApplyAtCenterOfMass = true
    moveForce.RelativeTo = Enum.ActuatorRelativeTo.World
    moveForce.Force = VEC3_ZERO

    local rotForce = Instance.new("AlignOrientation", mdl.PrimaryPart)
    rotForce.Enabled = false
    rotForce.Mode = Enum.OrientationAlignmentMode.OneAttachment
    rotForce.Attachment0 = att
    rotForce.AlignType = Enum.AlignType.AllAxes
    rotForce.Responsiveness = 200
    rotForce.MaxTorque = 200000000
    rotForce.MaxAngularVelocity = math.huge

    local posForce = Instance.new("AlignPosition", mdl.PrimaryPart)
    posForce.Enabled = false
    posForce.Attachment0 = att
    posForce.Mode = Enum.PositionAlignmentMode.OneAttachment
    posForce.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    posForce.MaxAxesForce = VEC3_ZERO
    posForce.MaxVelocity = 150
    posForce.Responsiveness = 195
    posForce.ForceRelativeTo = Enum.ActuatorRelativeTo.World
    posForce.Position = mdl.PrimaryPart.CFrame.Position

    return {
        moveForce = moveForce,
        rotForce = rotForce,
        posForce = posForce,
    } :: {[string]: Instance}
end

local function getCFrameRelMoveVec(camCFrame: CFrame): Vector3
    return CFrame.new(
        VEC3_ZERO,
        Vector3.new(
            camCFrame.LookVector.X, 0, camCFrame.LookVector.Z
        ).Unit
    ):VectorToWorldSpace(InputManager:getMoveVec())
end

local function calcWalkAccel(moveVec: Vector3, rootPos: Vector3, currVel: Vector3, normal: Vector3, dt: number): Vector3
    local isRunning = InputManager:getRunKeyDown()
    --local adjMoveVec = projectOnPlaneVec3(moveVec, normal)
    local target
    if (isRunning) then
        target = rootPos - moveVec * GND_RUN_SPEED
    else
        target = rootPos - moveVec * GND_WALK_SPEED
    end
    return 2*((target - rootPos) - currVel*dt)/(dt*dt*MOVE_DAMP), isRunning
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

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------

local Ground = setmetatable({}, BaseState)
Ground.__index = Ground

function Ground.new(...)
    local self = BaseState.new(...) :: BaseState.BaseState

    self.id = PlayerStateId.GROUNDED

    self.character = self._simulation.character :: Model
    self.forces = createForces(self.character)

    self.animation = self._simulation.animation

    return setmetatable(self, Ground)
end

function Ground:stateEnter()
    if (not self.forces) then
        warn("No forces to enable in state: 'Ground'"); return
    end
    self.forces.moveForce.Enabled = true
    self.forces.rotForce.Enabled = true

    self.animation:setState(AnimationStateId.IDLE, true)
end

function Ground:stateLeave()
    if (not self.forces) then
        return
    end
    for _, f: Constraint in self.forces do
        f.Enabled = false
    end

    self.grounded = false
end

-- Handles jump input and configures posForce
function Ground:updateJump(dt: number, override: boolean?)
    -- manage input cooldown for the jump action
    local function updateJumpTime()
        if (InputManager:getJumpKeyDown()) then
            if (not j_lastDown and j_Delay <= 0) then
                j_lastDown = true
                j_Delay = JUMP_DELAY
                jumpSignal = true
                return
            end
        else
            j_lastDown = false
        end

        j_Delay = math.max(j_Delay - dt, 0)
        jumpSignal = false
    end

    updateJumpTime()

    local primaryPart: BasePart = self.character.PrimaryPart
    local currRootPos = primaryPart.CFrame.Position

    if (self.grounded) then
        if ((j_Delay <= 0) or
            (hasJumped and currRootPos.Y < lastYPos)
        ) then
            self.forces.posForce.Enabled = true
            hasJumped = false
        end

        -- execute jump
        if (jumpSignal or override) then
            if (DO_JUMP_SOUND and not override) then
                SoundManager.updateGlobalSound(SoundManager.soundItem.JUMP, true)
            end

            self.forces.posForce.Enabled = false

            local jumpInitVel: number = math.sqrt(Workspace.Gravity * 2 * JUMP_HEIGHT)
            primaryPart:ApplyImpulse(
                VEC3_UP * (jumpInitVel - primaryPart.AssemblyLinearVelocity.Y) * primaryPart.AssemblyMass)
            hasJumped = true
        end
    end

    lastYPos = currRootPos.Y
end

-- Updates horizontal movement force
function Ground:updateMove(dt: number, moveDirVec: Vector3, normal: Vector3, normalAngle: number)
    local primaryPart: BasePart = self.character.PrimaryPart
    local currVel = primaryPart.AssemblyLinearVelocity
    local currPos = primaryPart.CFrame.Position
    local mass = primaryPart.AssemblyMass
    local currHoriVel = Vector3.new(currVel.X, 0, currVel.Z)

    local accelVec = calcWalkAccel(
        moveDirVec, currPos, currHoriVel, normal, MOVE_DT
    )

    self.forces.moveForce.Force = accelVec * mass

    if (not self.grounded) then
        self.forces.moveForce.Force *= 0.1
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Ground update
------------------------------------------------------------------------------------------------------------------------

function Ground:update(dt: number)
    local primaryPart: BasePart = self.character.PrimaryPart
    local camCFrame: CFrame = Workspace.CurrentCamera.CFrame
    local currVel: Vector3 = primaryPart.AssemblyLinearVelocity
    local currPos: Vector3 = primaryPart.CFrame.Position
    local grav = Workspace.Gravity
    local mass: number = primaryPart.AssemblyMass

    -- do phys checks
    local groundData: PhysCheck.groundData = PhysCheck.checkFloor(
        currPos, PHYS_RADIUS, HIP_HEIGHT, GND_CLEAR
    )
    self.normal = groundData.normal
    self.grounded = groundData.grounded

    -- TODO: handle water state switching
    -- if (physData.inWater) then
    --     self._simulation:transitionState(self._simulation.states.Water)
    -- end

    local moveDirVec = getCFrameRelMoveVec(camCFrame)
    local currHoriVel = Vector3.new(currVel.X, 0, currVel.Z)

    -- PrimaryPart rotation based on vecForce direction and ground normal
    local lookVec = primaryPart.CFrame.LookVector
    if (currHoriVel.Magnitude > 0.1) then
        local currAng = math.atan2(lookVec.Z, lookVec.X)
        local targetAng
        if (moveDirVec.Magnitude > 0.05) then
            targetAng = math.atan2(-moveDirVec.Z, -moveDirVec.X)
        else
            targetAng = lastTargetAng
        end

        if (math.abs(angleShortest(currAng, targetAng)) > 0) then
            targetAng = lerpAngle(currAng, targetAng, ROT_DT)
        end

        self.forces.rotForce.CFrame = CFrame.lookAlong(
            VEC3_ZERO, Vector3.new(math.cos(targetAng), 0, math.sin(targetAng))
        )

        lastTargetAng = targetAng
    end

    -- update horizonal movement
    self:updateMove(dt, moveDirVec, groundData.normal, groundData.normalAngle)

    -- update jump and manage posForce
    self:updateJump(dt)

    -- manage posForce
    if (self.grounded) then
        local targetPosY = groundData.gndHeight + HIP_HEIGHT

        if (DO_JUMP_SOUND and offGroundTime >= 0.2) then
            SoundManager.updateGlobalSound(SoundManager.soundItem.FLOOR_HIT, true)
        end

        -- scale force with cubed vertical velocity to compensate for high falls
        self.forces.posForce.MaxAxesForce = mass * (grav * 20 + currVel.Y * currVel.Y) * VEC3_UP
        self.forces.posForce.Position = Vector3.new(0, targetPosY, 0)
    else
        self.forces.posForce.Enabled = false
    end

    -- update animation
    
    if (not self.grounded and (offGroundTime >= 0.2 and currVel.Y < 0)) then
        self.animation:setState(AnimationStateId.FALL, false, 0.2)
    elseif (not self.grounded and currVel.Y > 0) then
        self.animation:setState(AnimationStateId.JUMP, false)
    elseif (currHoriVel.Magnitude >= ANIM_TH_RUN) then
        self.animation:setState(AnimationStateId.RUN, true)
        self.animation:adjustSpeed(currHoriVel.Magnitude * ANIM_SPEED_FAC_RUN)
    elseif (currHoriVel.Magnitude >= ANIM_TH_TROT) then
        self.animation:setState(AnimationStateId.TROT, true)
        self.animation:adjustSpeed(currHoriVel.Magnitude * ANIM_SPEED_FAC_WALK)
    elseif (currHoriVel.Magnitude >= ANIM_TH_WALK) then
        self.animation:setState(AnimationStateId.WALK, true)
        self.animation:adjustSpeed(currHoriVel.Magnitude * ANIM_SPEED_FAC_WALK)
    else
        self.animation:setState(AnimationStateId.IDLE, true)
        self.animation:adjustSpeed(1)
    end

    if (not self.grounded) then
        offGroundTime += dt
    else
        offGroundTime = 0
    end
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