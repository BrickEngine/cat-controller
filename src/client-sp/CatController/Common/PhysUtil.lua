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

-- calculate accel based on displacement and current vel of assembly
function PhysUtil.accelFromDispl(posDiff: number, vel: number, downForce: number, dt: number)
    --print(posDiff)
    local fac = 1
    if (posDiff <= 0.5) then
        fac = posDiff
    end
    return downForce + (2*(posDiff - vel*dt))/(dt*dt)
end

--[[
substep for stable accel prediction at low framerates (high dt)
- initial accel calculated with PhysUtil.forceFromDisplacementVec3
- downForce should be positive
]]
function PhysUtil.substepAccel(vel: number, pos: number, targetPos: number, downForce: number, numSteps: number, dt: number)
    local accel = PhysUtil.accelFromDispl((targetPos-pos), vel, downForce, dt)

    local stepAccel = accel
    local stepVel = vel
    local stepPos = pos
    local t = dt / numSteps

    for i=1, numSteps-1, 1 do
        local stepNetAccel = stepAccel - downForce

        local predVel: Vector3 = stepNetAccel*t
        local predPosDisp: Vector3 = (vel*t) + (0.5*predVel*t)
        local predAccel: Vector3 = downForce + 2*((targetPos - (stepPos + predPosDisp) - stepVel*t) / t*t)

        stepAccel = (accel + predAccel) * 0.5
        stepVel = (predVel + vel) * 0.5
        stepPos = (predPosDisp + pos) * 0.5
    end

    return stepAccel, stepVel, stepPos
end

function PhysUtil.stepperVec3(pos: Vector3, vel: Vector3, targetPos: Vector3, stiffness: number, damping: number, precision: number, dt: number)
    local force = -stiffness*(pos - targetPos)
    local dampForce = damping*vel
    local accel = force - dampForce

    local stepVel = vel*accel*dt
    local stepPos = pos*vel*dt

    if ((stepVel.Magnitude < precision) and ((targetPos - stepPos).Magnitude < precision)) then
        return targetPos, 0
    end
    return stepPos, stepVel
end

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

return PhysUtil