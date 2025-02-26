local VEC3_ALIGN_AXIS = Vector3.new(0, 1, 0)
local COLL_GROUP_NAME = "Player"

local function setCollGroup(mdl: Model)
    for _, v: BasePart in pairs(mdl:GetChildren()) do
        if (v:IsA("BasePart")) then
            v.CollisionGroup = COLL_GROUP_NAME
        end
    end
end

local function unanchorMdl(mdl: Model)
    for _, v in pairs(mdl:GetChildren()) do
        if (v:IsA("BasePart")) then
            v.Anchored = false
        end
    end
end

local function createForces(mdl: Model)
    local attachment = Instance.new("Attachment")
    attachment.Name = "Root"
    attachment.Parent = mdl.PrimaryPart
    attachment.WorldAxis = Vector3.new(0, 1, 0)

    local aliOri = Instance.new("AlignOrientation")
    aliOri.Parent = mdl.PrimaryPart
    aliOri.Mode = Enum.OrientationAlignmentMode.OneAttachment
    aliOri.AlignType = Enum.AlignType.PrimaryAxisParallel
    aliOri.ReactionTorqueEnabled, aliOri.RigidityEnabled = true, true
    aliOri.Attachment0 = attachment
    aliOri.PrimaryAxis = VEC3_ALIGN_AXIS
end

return function (char: Model)
    createForces(char)
    setCollGroup(char)
    unanchorMdl(char)
end