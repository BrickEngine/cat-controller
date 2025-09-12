local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")


local controller = script.Parent.Parent
local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)
local CharacterDef = require(ReplicatedStorage.Shared.CharacterDef)
local InputManager = require(controller.InputManager)
local BaseState = require(controller.SimStates.BaseState)
local FloorCheck = require(controller.Common.FloorCheck)

local STATE_ID = 1

-- physics
local WATER_SURFACE_OFFS = 0.025

-- animation speeds / threshold
local ANIM_SPEED_FAC_SWIM = 1

-- local vars
local ray_params_gnd = RaycastParams.new()
ray_params_gnd.CollisionGroup = CollisionGroups.PLAYER
ray_params_gnd.FilterType = Enum.RaycastFilterType.Exclude
ray_params_gnd.IgnoreWater = true
ray_params_gnd.RespectCanCollide = true

local ray_params_wtr = RaycastParams.new()
ray_params_wtr.CollisionGroup = CollisionGroups.WATER
ray_params_wtr.FilterType =Enum.RaycastFilterType.Include
ray_params_wtr.IgnoreWater = false

local function createForces(mdl: Model): {[string]: Instance}
    local att = Instance.new("Attachment")
    att.Name = "Ground"
    att.Parent = mdl.PrimaryPart

    local moveForce = Instance.new("VectorForce")
    moveForce.Enabled = false
    moveForce.Attachment0 = att
    moveForce.ApplyAtCenterOfMass = true
    moveForce.RelativeTo = Enum.ActuatorRelativeTo.World
    moveForce.Parent = mdl.PrimaryPart

    local rotForce = Instance.new("AlignOrientation")
    rotForce.Enabled = false
    rotForce.Mode = Enum.OrientationAlignmentMode.OneAttachment
    rotForce.Attachment0 = att
    rotForce.AlignType = Enum.AlignType.AllAxes
    rotForce.Responsiveness = 200
    rotForce.MaxTorque = 200000000
    rotForce.MaxAngularVelocity = math.huge
    rotForce.Parent = mdl.PrimaryPart

    local posForce = Instance.new("AlignPosition")
    posForce.Enabled = false
    posForce.Attachment0 = att
    posForce.Mode = Enum.PositionAlignmentMode.OneAttachment
    posForce.ForceLimitMode = Enum.ForceLimitMode.PerAxis
    posForce.MaxAxesForce = Vector3.zero
    posForce.MaxVelocity = 100000
    posForce.Responsiveness = 200
    posForce.ForceRelativeTo = Enum.ActuatorRelativeTo.World
    posForce.Position = mdl.PrimaryPart.CFrame.Position
    posForce.Parent = mdl.PrimaryPart

    return {
        moveForce = moveForce,
        rotForce = rotForce,
        posForce = posForce,
    }
end

---------------------------------------------------------------------------------------

local Water = setmetatable({}, BaseState)
Water.__index = Water

function Water.new(...)
    local self = setmetatable(BaseState.new(...) :: BaseState.BaseStateType, Water)

    self.id = STATE_ID

    return self :: BaseState.BaseStateType
end

function Water:stateEnter()

end

function Water:stateLeave()
    
end

function Water:update(dt: number)
    
end

function Water:destroy()

end

return Water