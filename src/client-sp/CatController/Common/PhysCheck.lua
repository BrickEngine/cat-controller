--!strict

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)

local DebugVisualize = require(script.Parent.DebugVisualize)

local NUM_RAYS = 32
local RADIUS_OFFSET = 0.05
local GND_CLEAR = 0.45
local RAY_Y_OFFSET = 0.2
local MAX_INCLINE = 60 -- deg
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
	normalAngle: number
}

function Phys.colliderCast(
	rootPos: Vector3,
	radius: number,
	hipHeight: number,
	rayParams: RaycastParams,
	buoySensor: BuoyancySensor?,
	calcWaterParts: boolean?
)
	local rayArr = {}
	local grounded = false
	local inWater = false
	local gndHeight = -9999
    local normal = VEC3_UP
	local adjHipHeight = hipHeight + RAY_Y_OFFSET
    local normAngle = 0

	-- terrain water check, use BuoyancySensor if availible
	if (buoySensor) then
		inWater = buoySensor.FullySubmerged or buoySensor.TouchingSurface
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
						inWater = true; break
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
			inWater = true
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

            normAngle = math.deg(math.acos(ray.Normal:Dot(Vector3.yAxis)))

			if (rayGndPos >= gndHeight and ray.Distance <= adjHipHeight + GND_CLEAR) then
				if (onSlope) then
					if (normAngle <= MAX_INCLINE) then
                        normal = ray.Normal
						gndHeight = rayGndPos
						grounded = true
					end
				else
					gndHeight = rayGndPos
					grounded = true
				end
			end

			-- DEBUG
			do
				local rayColor
				if (rayGndPos >= gndHeight and ray.Distance <= adjHipHeight + GND_CLEAR + RAY_Y_OFFSET) then
					rayColor = Color3.new(0, 255, 0)
				else
					rayColor = Color3.new(255, 0, 0)
				end
				DebugVisualize.point(ray.Position, rayColor)
			end
		end
	end

	return {
        grounded = grounded,
        inWater = inWater,
        gndHeight = gndHeight,
        normal = normal,
        normalAngle = normAngle
    } :: physData
end

return Phys.colliderCast