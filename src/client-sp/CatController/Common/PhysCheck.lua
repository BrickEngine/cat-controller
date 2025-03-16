--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)

local DebugVisualize = require(script.Parent.DebugVisualize)

local NUM_RAYS = 32
local RADIUS_OFFSET = 0.05
local GND_CLEAR = 0.5
local RAY_Y_OFFSET = 0.2
local GROUND_MODE = 0 -- 0: highest point; 1: point average; 2: lowest point

local PHI = 1.61803398875
local VEC3_ZERO = Vector3.zero
local VEC3_UP = Vector3.new(0, 1 ,0)
local VEC3_REGION_SIZE = Vector3.new(4, 4, 4)
local VEC3_REGION_OFFSET = Vector3.new(0, 1 ,0)
local BOUND_POINTS = math.round(2 * math.sqrt(NUM_RAYS))
local WATER_OVERLAPPARAMS = OverlapParams.new()

do
	local function getWaterPartsInWorkspace()
		local waterParts = {}
		for _, v in pairs(Workspace:GetDescendants()) do
			if (v:IsA("BasePart") and v.CollisionGroup == CollisionGroups.WATER) then
				table.insert(waterParts, v)
			end
		end
		return waterParts
	end

	WATER_OVERLAPPARAMS.FilterDescendantsInstances = getWaterPartsInWorkspace()
	WATER_OVERLAPPARAMS.FilterType = Enum.RaycastFilterType.Include
	WATER_OVERLAPPARAMS.MaxParts = 10
end

local Phys = {}

local function radiusDist(k: number, n: number, b: number)
	if (k > n-b) then
		return 1
	else
		return math.sqrt(k - 0.5) / math.sqrt(n - (b + 1)/2)
	end
end


local function checkStepCondition()
	
end

export type physData = {
	grounded: boolean,
	inWater: boolean,
	gndHeight: number,
	normal: Vector3,
	normalAngle: number,
}

function Phys.colliderCast(
	rootPos: Vector3,
	radius: number,
	hipHeight: number,
	maxIncline: number,
	rayParams: RaycastParams,
	buoySensor: BuoyancySensor?,
	calcWaterParts: boolean?
)
	local _grounded = false
	local _inWater = false
	local _gndHeight = -9999
    local _normal = VEC3_UP
    local _normalAngle = 0

	local rayArr = {}
	local adjHipHeight = hipHeight + RAY_Y_OFFSET

	-- terrain water check, use BuoyancySensor if availible
	if (buoySensor) then
		_inWater = buoySensor.FullySubmerged or buoySensor.TouchingSurface
	else
		local waterDetRegion = Region3.new(
			rootPos + VEC3_REGION_OFFSET - VEC3_REGION_SIZE,
			rootPos + VEC3_REGION_OFFSET + VEC3_REGION_SIZE
		)
		local regionData = Workspace.Terrain:ReadVoxels(waterDetRegion, 4)
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
	if (calcWaterParts) then
		local partsArr = Workspace:GetPartBoundsInRadius(
			rootPos + VEC3_REGION_OFFSET, 2, WATER_OVERLAPPARAMS
		)
		if (#partsArr > 0) then
			_inWater = true
		end
	end

	-- cylinder cast checks
	for i=1, NUM_RAYS, 1 do
		local r = radiusDist(i, NUM_RAYS, BOUND_POINTS) * (radius - RADIUS_OFFSET)
		local theta = i * 360 * PHI
		local offsetX = r * math.cos(theta)
		local offsetZ = r * math.sin(theta)
		local ray = Workspace:Raycast(
			Vector3.new(
				rootPos.X + offsetX,
				rootPos.Y + RAY_Y_OFFSET,
				rootPos.Z + offsetZ
			),
			Vector3.new(0, -100, 0),
			rayParams
		)
		if (ray) then
			local onSlope = ray.Normal:Cross(Vector3.yAxis) ~= VEC3_ZERO
			local rayGndPos = ray.Position.Y
			table.insert(rayArr, ray)

            _normalAngle = math.deg(math.acos(ray.Normal:Dot(Vector3.yAxis)))

			if (rayGndPos >= _gndHeight and ray.Distance <= adjHipHeight + GND_CLEAR) then
				if (onSlope) then
					if (_normalAngle <= maxIncline) then
                        _normal = ray.Normal
						_gndHeight = rayGndPos
						_grounded = true
					end
				else
					_gndHeight = rayGndPos
					_grounded = true
				end
			end

			-- DEBUG
			if (DebugVisualize.enabled) then
				local rayColor
				if (
					rayGndPos >= _gndHeight
					and ray.Distance <= adjHipHeight + GND_CLEAR
					and _normalAngle <= maxIncline
				) then
					rayColor = Color3.new(0, 255, 0)
				else
					rayColor = Color3.new(255, 0, 0)
				end
				DebugVisualize.point(ray.Position, rayColor)
			end
		end
	end

	return {
        grounded = _grounded,
        inWater = _inWater,
        gndHeight = _gndHeight,
        normal = _normal,
        normalAngle = _normalAngle,
    } :: physData
end

return Phys.colliderCast