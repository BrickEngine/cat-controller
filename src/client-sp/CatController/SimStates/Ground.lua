--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local controller = script.Parent.Parent
local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local InputManager = require(controller.InputManager)
local BaseState = require(controller.SimStates.BaseState)
local PhysCheck = require(controller.Common.PhysCheck)
local PhysUtil = require(controller.Common.PhysUtil)

local GND_WALK_SPEED = 2.6
local GND_RUN_SPEED = 7.2
local CONST_MASS = 1
local VEC3_ZERO = Vector3.zero
local RAY_PARAMS = RaycastParams.new()
RAY_PARAMS.CollisionGroup = "Player"
RAY_PARAMS.IgnoreWater = true
RAY_PARAMS.RespectCanCollide = true

local COLL_RADIUS = (CharacterDef.PARAMS.MAINCOLL_SIZE.X / 2) - 0.05
local HIP_HEIGHT = CharacterDef.PARAMS.LEGCOLL_SIZE.Y

local function calcWalkAccel(rootPos: Vector3, currentVel: number, dt: number): Vector3
    local target
    if (InputManager:getIsRunning()) then
        target = rootPos + InputManager:getMoveVec() * GND_RUN_SPEED
    else
        target = rootPos + InputManager:getMoveVec() * GND_WALK_SPEED
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

function Ground.new(...)
    local self = setmetatable(BaseState.new(...) :: BaseState.BaseStateType, Ground) :: any

    self.character = self._simulation.character
    self.vecForces = nil

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
    local physMdlMass = PhysUtil.getModelMassByTag(self.character, CharacterDef.PARAMS.PHYS_TAG_NAME)
    local weight = physMdlMass * Workspace.Gravity
    local accelX = moveAccel.X * physMdlMass
    local accelZ = moveAccel.Z * physMdlMass

    local physData: PhysCheck.physData = PhysCheck(primaryPart.CFrame.Position, COLL_RADIUS, HIP_HEIGHT, RAY_PARAMS)

    -- if (not physData.grounded) then
    --     self._stateMachine:transitionState(self._stateMachine.states.Air)
    -- end
    -- if (physData.inWater) then
    --     self._stateMachine:transitionState(self._stateMachine.states.Water)
    -- end
    
end

return Ground