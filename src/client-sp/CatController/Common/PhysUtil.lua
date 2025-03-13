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

-- calculate Force based on displacement and current velocity of assembly
function PhysUtil.forceFromDisplacementVec3(posDiff: Vector3, vel: Vector3, downForce: Vector3, mass: number, dt: number)
    return downForce + 2*(posDiff - vel*dt)/(dt*dt) * mass
end

function PhysUtil.forceFromDisplacement(posDiff: number, vel: number, downForce: number, mass: number, dt: number)
    return downForce + 2*(posDiff - vel*dt)/(dt*dt) * mass
end


--[[
substep for stable force prediction at low framerates
- downForce should be: (0, mass * gravity, 0)
- force calculated with PhysUtil.forceFromDisplacementVec3
]]
function PhysUtil.subStepForceVec3(vel: Vector3, pos: Vector3, targetPos: Vector3, downForce: Vector3, mass: number, numSteps: number, dt: number)
    local force = PhysUtil.forceFromDisplacementVec3((targetPos-pos), vel, downForce, mass, dt)

    local stepForce = force
    local stepVel = vel
    local stepPos = pos
    local t = dt / numSteps

    for i=1, numSteps-1, 1 do
        local stepNetForce = stepForce - downForce

        local predVel: Vector3 = (stepNetForce / mass)*t
        local predPosDisp: Vector3 = (vel*t) + (0.5*predVel*t)
        local predForce: Vector3 = downForce + 2*((targetPos - (stepPos + predPosDisp) - stepVel*t) / t*t)*mass

        stepForce = (force + predForce) * 0.5
        stepVel = (predVel + vel) * 0.5
        stepPos = (predPosDisp + pos) * 0.5
    end

    return stepForce, stepVel, stepPos
end

function PhysUtil.subStepForce(vel: number, pos: number, targetPos: number, downForce: number, mass: number, numSteps: number, dt: number)
    local force = PhysUtil.forceFromDisplacement((targetPos-pos), vel, downForce, mass, dt)

    local stepForce = force
    local stepVel = vel
    local stepPos = pos
    local t = dt / numSteps

    for i=1, numSteps-1, 1 do
        local stepNetForce = stepForce - downForce

        local predVel: Vector3 = (stepNetForce / mass)*t
        local predPosDisp: Vector3 = (vel*t) + (0.5*predVel*t)
        local predForce: Vector3 = downForce + 2*((targetPos - (stepPos + predPosDisp) - stepVel*t) / t*t)*mass

        stepForce = (force + predForce) * 0.5
        stepVel = (predVel + vel) * 0.5
        stepPos = (predPosDisp + pos) * 0.5
    end

    return stepForce, stepVel, stepPos
end

return PhysUtil