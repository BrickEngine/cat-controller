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

-- function PhysUtil.oldColliderCast(
-- 	rootPos: Vector3,
-- 	radius: number,
-- 	hipHeight: number,
-- 	maxIncline: number,
-- 	gndClearDist: number,
-- 	rayParams: RaycastParams,
-- 	buoySensor: BuoyancySensor?,
-- 	calcWaterParts: boolean?
-- )
-- 	local _grounded = false
-- 	local _inWater = false
-- 	local _gndHeight = -math.huge
-- 	local _ceilHeight = math.huge
--     local _normal = VEC3_UP
--     local _normalAngle = 0

-- 	local gndRayArr = {}
-- 	local adjHipHeight = hipHeight + RAY_Y_OFFSET

-- 	-- terrain water check, use BuoyancySensor if availible
-- 	if (buoySensor) then
-- 		_inWater = buoySensor.FullySubmerged or buoySensor.TouchingSurface
-- 	else
-- 		local waterDetRegion = Region3.new(
-- 			rootPos + VEC3_REGION_OFFSET - VEC3_REGION_SIZE,
-- 			rootPos + VEC3_REGION_OFFSET + VEC3_REGION_SIZE
-- 		)
-- 		local regionData = Workspace.Terrain:ReadVoxels(waterDetRegion, 4)
-- 		for i, d1 in ipairs(regionData) do
-- 			for _, d2 in pairs(d1) do
-- 				for _, d3 in pairs(d2) do
-- 					if (d3 == Enum.Material.Water) then
-- 						_inWater = true; break
-- 					end
-- 				end
-- 			end
-- 		end
-- 	end

-- 	-- parts with assigned Water coll group, aka. "custom water"
-- 	if (calcWaterParts) then
-- 		local partsArr = Workspace:GetPartBoundsInRadius(
-- 			rootPos + VEC3_REGION_OFFSET, 2, WATER_OVERLAPPARAMS
-- 		)
-- 		if (#partsArr > 0) then
-- 			_inWater = true
-- 		end
-- 	end

-- 	-- cylinder cast checks
-- 	for i=1, NUM_RAYS, 1 do
-- 		local r = radiusDist(i, NUM_RAYS, BOUND_POINTS) * (radius - RADIUS_OFFSET)
-- 		local theta = i * 360 * PHI
-- 		local offsetX = r * math.cos(theta)
-- 		local offsetZ = r * math.sin(theta)
-- 		local ray = Workspace:Raycast(
-- 			Vector3.new(
-- 				rootPos.X + offsetX,
-- 				rootPos.Y + RAY_Y_OFFSET,
-- 				rootPos.Z + offsetZ
-- 			),
-- 			-VEC3_UP * 100,
-- 			rayParams
-- 		)
-- 		if (ray) then
-- 			local onSlope = ray.Normal:Cross(Vector3.yAxis) ~= VEC3_ZERO
-- 			local rayGndPos = ray.Position.Y
-- 			table.insert(gndRayArr, ray)

--             _normalAngle = math.deg(math.acos(ray.Normal:Dot(Vector3.yAxis)))

-- 			if (rayGndPos >= _gndHeight and ray.Distance <= adjHipHeight + gndClearDist) then
-- 				if (onSlope) then
-- 					if (_normalAngle <= maxIncline) then
--                         _normal = ray.Normal
-- 						_gndHeight = rayGndPos
-- 						_grounded = true
-- 					end
-- 				else
-- 					_gndHeight = rayGndPos
-- 					_grounded = true
-- 				end
-- 			end

-- 			-- check for ceiling hits
-- 			local ceilRay = Workspace:Raycast(
-- 				ray.Position + VEC3_UP*(hipHeight - RAY_Y_OFFSET),
-- 				VEC3_UP * 100,
-- 				rayParams
-- 			)
-- 			if (ceilRay) then
-- 				if (ceilRay.Position.Y < _ceilHeight) then
-- 					_ceilHeight = ceilRay.Position.Y
-- 				end
-- 			end

-- 			-- DEBUG
-- 			if (DebugVisualize.enabled) then
-- 				local gndRayColor
-- 				local ceilRayColor
-- 				if (
-- 					rayGndPos >= _gndHeight
-- 					and ray.Distance <= adjHipHeight + gndClearDist
-- 					and _normalAngle <= maxIncline
-- 				) then
-- 					gndRayColor = Color3.new(0, 255, 0)
-- 				else
-- 					gndRayColor = Color3.new(255, 0, 0)
-- 				end
-- 				if ((_ceilHeight - _gndHeight) < 3) then
-- 					ceilRayColor = Color3.new(255, 0, 0)
-- 				else
-- 					ceilRayColor = Color3.new(0, 255, 0)
-- 				end
-- 				DebugVisualize.point(ray.Position, gndRayColor)
-- 				if (ceilRay) then
-- 					DebugVisualize.point(ceilRay.Position, ceilRayColor)
-- 				end
-- 			end
-- 		end
-- 	end

-- 	return {
--         grounded = _grounded,
--         inWater = _inWater,
--         gndHeight = _gndHeight,
-- 		ceilHeight = _ceilHeight,
--         normal = _normal,
--         normalAngle = _normalAngle,
--     } :: physData
-- end

return PhysUtil