local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local DebugVisualize = require(script.Parent.DebugVisualize)
local CollisionGroup = require(ReplicatedStorage.Shared.Enums.CollisionGroup)

-- [[checkFloor]]

-- number of rays to cast
local NUM_GND_RAYS = 64
-- inward offset of the boundary for the outermost rays
local RADIUS_OFFSET = 0.05
-- ray origin offset from the default hip height
local RAY_Y_OFFSET = 0.1
 -- in rad, angle at which a hit will not be registered
local MAX_INCLINE_ANGLE = math.rad(70)
-- max distance between ordered hit points which, if exceeded, will force the target position to be
-- evaluated differently for ground detection
local MAX_GND_POINT_DIFF = 0.25
 -- if true, picks highest point as target position
local TARGET_CLOSEST = true

-- [[Misc]]

local PHI = 1.61803398875
local BOUND_POINTS = math.round(2 * math.sqrt(NUM_GND_RAYS))
local VEC3_ZERO = Vector3.zero
local VEC3_UP = Vector3.new(0, 1 ,0)
local VEC3_FARDOWN = -999999999 * VEC3_UP

local floorRayParams = RaycastParams.new()
floorRayParams.CollisionGroup = CollisionGroup.PLAYER
floorRayParams.RespectCanCollide = true
floorRayParams.FilterType = Enum.RaycastFilterType.Exclude
floorRayParams.IgnoreWater = true

local wallRayParams = RaycastParams.new()
wallRayParams.CollisionGroup = CollisionGroup.PLAYER
wallRayParams.FilterType = Enum.RaycastFilterType.Exclude
wallRayParams.IgnoreWater = true

------------------------------------------------------------------------------------------------------------------------

local function radiusDist(k: number, n: number, b: number)
	if (k > n-b) then
		return 1
	else
		return math.sqrt(k - 0.5) / math.sqrt(n - (b + 1)/2)
	end
end

-- Calculates a virtual plane normal from given points
local function avgPlaneFromPoints(ptsArr: {Vector3}) : {centroid: Vector3, normal: Vector3}
	local n = #ptsArr
	local noPlane = {
			centroid = VEC3_ZERO,
			normal = VEC3_UP
		}
	if (n < 3) then
		warn("No plane exists")
		return noPlane
	end

	local sum = VEC3_ZERO
	for i,vec: Vector3 in ipairs(ptsArr) do
		sum += vec
	end
	local centroid = sum / n

	local xx, xy, xz, yy, yz, zz = 0, 0, 0, 0, 0, 0
	for i,vec: Vector3 in ipairs(ptsArr) do
		local r : Vector3 = vec - centroid
		xx += r.X * r.X
		xy += r.X * r.Y
		xz += r.X * r.Z
		yy += r.Y * r.Y
		yz += r.Y * r.Z
		zz += r.Z * r.Z
	end
	local det_x = yy*zz - yz*yz
    local det_y = xx*zz - xz*xz
    local det_z = xx*yy - xy*xy

	local det_max = math.max(det_x, det_y, det_z)
	if (det_max <= 0) then
		return noPlane
	end

	local dir: Vector3 = VEC3_ZERO
	if (det_max == det_x) then
		dir = Vector3.new(det_x, xz*yz - xy*zz, xy*yz - xz*yy)
	elseif (det_max == det_y) then
		dir = Vector3.new(xz*yz - xy*zz, det_y, xy*xz - yz*xx)
	else
		dir = Vector3.new(xy*yz - xz*yy, xy*xz - yz*xx, det_z)
	end

	-- Invert normal, if upside down
	if (dir:Dot(VEC3_UP) < 0) then
		dir = -dir
	end

	return {
		centroid = centroid,
		normal = dir.Unit
	}
end

local function avgVecFromVecs(vecArr: {Vector3}): Vector3
	local n = #vecArr
	-- If there is no data, default to a horizontal plane
	if (n == 0) then
		warn("Empty vector array")
		return VEC3_UP
	elseif (n == 1) then
		return vecArr[1]
	end

	local vecSum = VEC3_ZERO
	for _,v in ipairs(vecArr) do
		vecSum += v
	end

	return (vecSum * 1/n)
end

-- Finds the biggest numerical difference between two adjacent numbers in an ordered array
local function biggestOrderedDist(numArr: {number}): number
	local arr = numArr
	table.sort(numArr, function(a0: number, a1: number): boolean 
		return a0 < a1
	end)

	local i = 1
	local max = 0
	while (i < #arr) do
		local dist = math.abs(arr[i] - arr[i + 1]) 
		max = (dist > max) and dist or max
		i += 1
	end

	return max
end

-- local function lineDist(radius: number, point: number, n: number): number
-- 	return (radius / n) * (1 + 2 * point)
-- end

-- -- Finds the biggest difference 
-- local function biggestVecAngleDiff(vecArr: {Vector3}): number
-- 	local maxAng = 0
-- 	local arr = vecArr

-- 	for i, vec: Vector3 in ipairs(arr) do
-- 		arr[i] = vec.Unit
-- 	end

-- 	for i=1, #arr-2, 1 do
-- 		for j=i+1, #arr-1, 1 do
-- 			local dot = arr[i]:Dot(arr[j])

-- 			-- compensate for rounding errors
-- 			if (dot > 1) then dot = 1.0 end
-- 			if (dot < -1) then dot = -1.0 end

-- 			maxAng = math.max(math.acos(dot), maxAng)
-- 		end
-- 	end

-- 	return maxAng
-- end

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------
local PhysCheck = {}

export type groundData = {
	grounded: boolean,
	pos: Vector3,
	closestPos: Vector3,
	normal: Vector3,
	gndHeight: number,
	normalAngle: number
}

export type wallData = {
	nearWall: boolean,
	normal: Vector3,
	position: Vector3,
	bankAngle: number,
	maxAngleDiff: number
}

type wallSide = {
	posArr: {Vector3},
	normalsArr: {Vector3}
}

------------------------------------------------------------------------------------------------------------------------
-- Ground
------------------------------------------------------------------------------------------------------------------------

-- Cylindrical raycast operation for detailed ground proximity data
function PhysCheck.checkFloor(
	rootPos: Vector3,
	maxRadius: number,
	hipHeight: number,
	gndClearDist: number,
	rayParams: RaycastParams?
) : groundData

	local grounded = false
	local closestPos = VEC3_FARDOWN
	local closestDist = math.huge
	local targetPos = VEC3_FARDOWN
    local targetNorm = VEC3_UP
    local targetNormAngle = 0
	local numHits = 0
	local numTotalHits = 0
	local adjHipHeight = hipHeight + RAY_Y_OFFSET
	local _rayParams = rayParams or floorRayParams

	-- Cylinder cast checks with sunflower distribution
	local hitPointsArr = {} :: {Vector3}
	local normalsArr = {} :: {Vector3}
	local ptsHeightArr = {} :: {number}

	-- TODO: return a hit BasePart, which is closest to the RootPart
	--local hitObjectArr = {} :: {BasePart}

	for i=1, NUM_GND_RAYS, 1 do
		local r = radiusDist(i, NUM_GND_RAYS, BOUND_POINTS) * (maxRadius - RADIUS_OFFSET)
		local theta = i * 360 * PHI
		local offsetX = r * math.cos(theta)
		local offsetZ = r * math.sin(theta)

		local ray = Workspace:Raycast(
			Vector3.new(
				rootPos.X + offsetX,
				rootPos.Y + RAY_Y_OFFSET,
				rootPos.Z + offsetZ
			),
			-VEC3_UP * adjHipHeight * 2,
			_rayParams
		)
		if (ray :: RaycastResult) then
			local debug_gnd_hit = false

			numTotalHits += 1
			normalsArr[numTotalHits] = ray.Normal

			if (ray.Distance <= adjHipHeight + gndClearDist) then

				local hitNormAng = math.asin((VEC3_UP:Cross(ray.Normal)).Magnitude)
				if (hitNormAng < MAX_INCLINE_ANGLE) then
					numHits += 1
					hitPointsArr[numHits] = ray.Position
					ptsHeightArr[numHits] = ray.Position.Y

					if (ray.Distance < closestDist) then
						closestDist = ray.Distance
						closestPos = ray.Position
					end
					debug_gnd_hit = true
				end
			end

			-- DEBUG
			if (DebugVisualize.enabled) then
				local gndRayColor
				if (debug_gnd_hit) then
					gndRayColor = Color3.new(0, 255, 0)
				else
					gndRayColor = Color3.new(255, 0, 0)
				end
				DebugVisualize.point(ray.Position, gndRayColor)
			end
		end
	end

	grounded = true

	if (TARGET_CLOSEST) then
		if (numHits > 0) then
			
			local biggestDist = biggestOrderedDist(ptsHeightArr)
			if (biggestDist <= MAX_GND_POINT_DIFF) then
				if (numHits >= 3) then
					targetPos = avgPlaneFromPoints(hitPointsArr).centroid
				elseif (numHits == 2) then
					targetPos = avgVecFromVecs(hitPointsArr)
				else
					targetPos = hitPointsArr[1]
				end
			else
				targetPos = closestPos
			end

			targetPos = closestPos
			targetNorm = avgVecFromVecs(normalsArr)
		else
			grounded = false
			targetNorm = VEC3_UP
		end

	else
		targetNorm = avgVecFromVecs(normalsArr)
		if (numHits > 2) then
			local planeData = avgPlaneFromPoints(hitPointsArr)
			targetPos = planeData.centroid
			targetNorm = planeData.normal
			--pNormAngle = math.deg(math.acos(targetNorm:Dot(VEC3_UP)))
		elseif (numHits == 2 or numHits == 1) then
			targetPos = avgVecFromVecs(hitPointsArr)
		else
			grounded = false
		end
	end

	targetNormAngle = math.asin((VEC3_UP:Cross(targetNorm)).Magnitude)
	--math.deg(math.acos(targetNorm:Dot(VEC3_UP)))

	DebugVisualize.normalPart(targetPos, targetNorm, Vector3.new(0.1, 0.1, 2))

	return {
        grounded = grounded,
		pos = targetPos,
		closestPos = closestPos,
		normal = targetNorm.Unit,
        gndHeight = targetPos.Y,
        normalAngle = targetNormAngle
    } :: groundData
end

return PhysCheck