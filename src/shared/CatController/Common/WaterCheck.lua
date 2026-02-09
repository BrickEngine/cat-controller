local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)

local DebugVisualize = require(script.Parent.DebugVisualize)

local NUM_RAYS = 32
local RADIUS_OFFSET = 0.05
local RAY_Y_OFFSET = 0.1
local REG_WATER_PARTS = false

local PHI = 1.61803398875
local TAN_THETA = math.tan(math.rad(60))
local TAN_START_THETA = math.tan(math.rad(60) - math.rad(2.5))
local VEC3_ZERO = Vector3.zero
local VEC3_UP = Vector3.new(0, 1 ,0)
local VEC3_REGION_SIZE = Vector3.new(4, 4, 4)
local VEC3_REGION_OFFSET = Vector3.new(0, 1 ,0)
local BOUND_POINTS = math.round(2 * math.sqrt(NUM_RAYS))
local WATER_OVERLAPPARAMS = OverlapParams.new()

do
	local function getWaterPartsInWorkspace(): {[number]:Instance}
		local waterParts = {}
		for _, v in pairs(Workspace:GetDescendants()) do
			if (v:IsA("BasePart") and v.CollisionGroup == CollisionGroups.WATER) then
				v.CanCollide = false
				table.insert(waterParts, v)
			end
		end
		return waterParts
	end

	WATER_OVERLAPPARAMS.FilterDescendantsInstances = getWaterPartsInWorkspace()
	WATER_OVERLAPPARAMS.FilterType = Enum.RaycastFilterType.Include
	WATER_OVERLAPPARAMS.MaxParts = 10
end

local function radiusDist(k: number, n: number, b: number)
	if (k > n-b) then
		return 1
	else
		return math.sqrt(k - 0.5) / math.sqrt(n - (b + 1)/2)
	end
end

local function avgPlaneFromPoints(ptsArr: {Vector3}) : {centroid: Vector3, normal: Vector3}
	local n = #ptsArr
	local noPlane = {
			centroid = VEC3_ZERO,
			normal = VEC3_UP
		}
	if (n < 3) then
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

	return {
		centroid = centroid,
		normal = dir.Unit
	}
end

local Phys = {}

export type physData = {
	grounded: boolean,
	inWater: boolean,
	pos: Vector3,
	normal: Vector3,
	gndHeight: number,
	normalAngle: number,
	steepness: number
}

function Phys.colliderCast(
	rootPos: Vector3,
	maxRadius: number,
	hipHeight: number,
	maxIncline: number,
	gndClearDist: number,
	rayParams: RaycastParams,
	buoySensor: BuoyancySensor?
)
	local _grounded = false
	local _inWater = false
	local targetPos = -VEC3_UP * 9999
    local targetNorm = VEC3_UP
    local pNormAngle = 0

	local numHits = 0
	local adjHipHeight = hipHeight + RAY_Y_OFFSET

	-- terrain water check, use BuoyancySensor if availible
	if (buoySensor) then
		_inWater = buoySensor.TouchingSurface or buoySensor.FullySubmerged
	else
		local waterDetRegion = Region3.new(
			rootPos + VEC3_REGION_OFFSET - VEC3_REGION_SIZE,
			rootPos + VEC3_REGION_OFFSET + VEC3_REGION_SIZE
		)
		local regionData = Workspace.Terrain:ReadVoxels(waterDetRegion:ExpandToGrid(4), 4)
		for i, d1 in ipairs(regionData) do
			for _, d2 in pairs(d1) do
				for _, d3 in pairs(d2) do
					if (d3 == Enum.Material.Water) then
						_inWater = true; break
					end
				end
			end
		end
	end

	-- parts with assigned Water coll group, aka. "custom water"
	if (REG_WATER_PARTS) then
		local partsArr = Workspace:GetPartBoundsInRadius(
			rootPos + VEC3_REGION_OFFSET, 2, WATER_OVERLAPPARAMS
		)
		if (#partsArr > 0) then
			_inWater = true
		end
	end

	-- cylinder cast checks

	local hitPointsArr = {} :: {Vector3}
	local hitNormalsArr = {} :: {Vector3}
	-- TODO: return a hit BasePart, which is closest to the root part
	--local hitObjectArr = {} :: {BasePart}

	for i=1, NUM_RAYS, 1 do
		local r = radiusDist(i, NUM_RAYS, BOUND_POINTS) * (maxRadius - RADIUS_OFFSET)
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
			rayParams
		)
		if (ray :: RaycastResult) then
			local debug_gnd_hit = false
			--local onSlope = ray.Normal:Cross(Vector3.yAxis) ~= VEC3_ZERO
			--local normAng = math.deg(math.acos(ray.Normal:Dot(Vector3.yAxis)))

			if (ray.Distance <= adjHipHeight + gndClearDist) then
				numHits += 1
				hitPointsArr[numHits] = ray.Position
				hitNormalsArr[numHits] = ray.Normal
				debug_gnd_hit = true
			else
				debug_gnd_hit = false
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

	_grounded = true

	if (numHits > 2) then
		local planeData = avgPlaneFromPoints(hitPointsArr, hitNormalsArr)
		targetPos = planeData.centroid
		targetNorm = planeData.normal
		pNormAngle = math.deg(math.acos(targetNorm:Dot(VEC3_UP)))
	elseif (numHits == 2) then
		local p1, p2 = hitPointsArr[1], hitPointsArr[2]
		local n1, n2 = hitNormalsArr[1], hitNormalsArr[2]
		targetPos = (p1 + p2)*0.5
		targetNorm = (n1 + n2)*0.5
	elseif (numHits == 1) then
		targetPos = hitPointsArr[1]
		targetNorm = hitNormalsArr[1]
	else
		_grounded = false
	end

	pNormAngle = math.asin((VEC3_UP:Cross(targetNorm)).Magnitude) --math.deg(math.acos(targetNorm:Dot(VEC3_UP)))

	local steepness = 0
	local y = targetNorm.Y
	local x = Vector2.new(targetNorm.X, targetNorm.Z).Magnitude
	if math.abs(x) > 0 then
		steepness = math.min(1, math.max(0, x/y - TAN_START_THETA) / (TAN_THETA - TAN_START_THETA))
	elseif y < 0 then
		steepness = 1
	end

	DebugVisualize.normalPart(targetPos, targetNorm, Vector3.new(0.1,0.1,2))
	--DebugVisualize.normalPart(avgPos, Vector3.FromAxis(Enum.Axis.Y))
	return {
        grounded = _grounded,
        inWater = _inWater,
		pos = targetPos,
		normal = targetNorm.Unit,
        gndHeight = targetPos.Y,
        normalAngle = pNormAngle,
		steepness = steepness
    } :: physData
end

return Phys.colliderCast