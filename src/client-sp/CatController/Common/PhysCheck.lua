local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)

local DebugVisualize = require(script.Parent.DebugVisualize)

local NUM_RAYS = 32
local RADIUS_OFFSET = 0.01
local RAY_Y_OFFSET = 0.25
local REG_WATER_PARTS = false
local DO_CEIL_CHECKS = false

local PHI = 1.61803398875
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

local Phys = {}

export type physData = {
	grounded: boolean,
	inWater: boolean,
	atCeiling: boolean,
	gndHeight: number,
	avgNormal: Vector3,
	avgNormalAngle: number,
}

function Phys.colliderCast(
	rootPos: Vector3,
	maxRadius: number,
	hipHeight: number,
	torsoHeight: number,
	maxIncline: number,
	gndClearDist: number,
	rayParams: RaycastParams,
	buoySensor: BuoyancySensor?
)
	local _grounded = false
	local _inWater = false
	local _atCeiling = false
	local _gndHeight = 0
	local _ceilHeight = 0
    local _avgNormal = VEC3_UP
    local _avgNormalAngle = 0

	local numHitGndRays = 0
	local numHitCeilRays = 0
	local numHitNormals = 0
	local adjHipHeight = hipHeight + RAY_Y_OFFSET
	local adjTorsoHeight = torsoHeight + RAY_Y_OFFSET
	local adjFullHeight = 3 - RAY_Y_OFFSET

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
	for i=1, NUM_RAYS, 1 do
		local r = radiusDist(i, NUM_RAYS, BOUND_POINTS) * (maxRadius - RADIUS_OFFSET)
		local theta = i * 360 * PHI
		local offsetX = r * math.cos(theta)
		local offsetZ = r * math.sin(theta)
		--local pHipHeightOffset = -(r^4)*(adjHipHeight/maxRadius^4)
		--local currGndClearDis = gndClearDist + pHipHeightOffset

		local ray = Workspace:Raycast(
			Vector3.new(
				rootPos.X + offsetX,
				rootPos.Y + RAY_Y_OFFSET,
				rootPos.Z + offsetZ
			),
			-VEC3_UP * 100,
			rayParams
		)
		if (ray :: RaycastResult) then
			local debug_gnd_hit = false
			local debug_ceil_hit = false
			local onSlope = ray.Normal:Cross(Vector3.yAxis) ~= VEC3_ZERO
			local normAng = math.deg(math.acos(ray.Normal:Dot(Vector3.yAxis)))

			_avgNormal += ray.Normal

			if (ray.Distance <= adjHipHeight + gndClearDist) then
				if (onSlope and normAng <= maxIncline) then
					_avgNormal += ray.Normal
					_avgNormalAngle += normAng
					numHitNormals += 1
				end
				_gndHeight += ray.Position.Y
				numHitGndRays += 1
				debug_gnd_hit = true
			end

			--check ceiling
			local ceilRay = false
			if (DO_CEIL_CHECKS) then
				ceilRay = Workspace:Raycast(
					Vector3.new(
						rootPos.X + offsetX,
						rootPos.Y + RAY_Y_OFFSET,
						rootPos.Z + offsetZ
					),
					VEC3_UP * 100,
					rayParams
				)
				if (ceilRay :: RaycastResult) then
					if (ceilRay.Distance <= adjTorsoHeight - 0.25) then
						debug_ceil_hit = true
						numHitCeilRays += 1
					end
				end
			end

			-- DEBUG
			if (DebugVisualize.enabled) then
				local gndRayColor
				local ceilRayColor
				if (debug_gnd_hit) then
					gndRayColor = Color3.new(0, 255, 0)
				else
					gndRayColor = Color3.new(255, 0, 0)
				end
				if (debug_ceil_hit) then
					ceilRayColor = Color3.new(0, 255, 0)
				else
					ceilRayColor = Color3.new(255, 0, 0)
				end
				DebugVisualize.point(ray.Position, gndRayColor)
				if (ceilRay) then
					DebugVisualize.point(ceilRay.Position, ceilRayColor)
				end
			end
		end
	end

	if (numHitGndRays > 0) then
		_gndHeight = _gndHeight / numHitGndRays

		if (numHitNormals > 0) then
			_avgNormalAngle = _avgNormalAngle / numHitNormals
		end
		_grounded = true
	end
	_atCeiling = (numHitCeilRays > 0)

	return {
        grounded = _grounded,
        inWater = _inWater,
		atCeiling = _atCeiling,
        gndHeight = _gndHeight,
        avgNormal = _avgNormal,
        avgNormalAngle = _avgNormalAngle
    } :: physData
end

return Phys.colliderCast