local PhysUtil = {}

function PhysUtil.getModelMass(mdl: Model, recurse: boolean?): number
    local totalMass = 0

    for _, inst: Instance in pairs(mdl:GetChildren()) do
        if (inst:IsA("BasePart")) then
            totalMass += inst.Mass
        elseif (recurse and inst:IsA("Model")) then
            totalMass += PhysUtil.getModelMass(inst)
        end
    end
    return totalMass
end

function PhysUtil.getModelMassByTag(mdl: Model, tag: string, recurse: boolean?): number
    local totalMass = 0

    for _, inst: Instance in pairs(mdl:GetChildren()) do
        if (inst:IsA("BasePart") and inst:HasTag(tag)) then
            totalMass += inst.Mass
        elseif (recurse and inst:IsA("Model")) then
            totalMass += PhysUtil.getModelMass(inst)
        end
    end
    return totalMass
end

function PhysUtil.unanchorModel(mdl: Model)
    for _, inst in pairs(mdl:GetDescendants()) do
        if (inst:IsA("BasePart")) then
            inst.Anchored = false
        elseif (inst:IsA("Model")) then
            PhysUtil.unanchorModel(inst)
        end
    end
end

return PhysUtil