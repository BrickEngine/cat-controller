--!nonstrict

local Workspace = game:GetService("Workspace")

local NUM_RAYS = 32
local PHI = 1.61803398875
local RADIUS_OFFSET = 0.05
local GND_CLEAR = 1
local MAX_INCLINE = 60
local VEC3_UP = Vector3.new(0, 1 ,0)
local VEC3_REGION_SIZE = Vector3.new(4, 4, 4)
local VEC3_REGION_OFFSET = VEC3_UP * 0.6
local BOUND_POINTS = math.round(2 * math.sqrt(NUM_RAYS))

local Phys = {}

local function radiusDist(k, n, b)
	if (k > n-b) then
		return 1
	else
		return math.sqrt(k-1/2) / math.sqrt(n-(b+1)/2)
	end
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
	rayParams: RaycastParams
)
	local rayArr = {}
	local grounded = false
	local inWater = false
	local gndHeight = -9999
    local normal = VEC3_UP
    local normAngle = 0
	local waterDetRegion = Region3.new(
		rootPos + VEC3_REGION_OFFSET - VEC3_REGION_SIZE,
		rootPos + VEC3_REGION_OFFSET + VEC3_REGION_SIZE
	)

	local regionData = Workspace.Terrain:ReadVoxels(waterDetRegion, 4)
	for i, d1 in ipairs(regionData) do
		for _, d2 in pairs(d1) do
			for _, d3 in pairs(d2) do
				if (d3 == Enum.Material.Water) then
					inWater = true break;
				end
			end
		end
	end

	for i=1, NUM_RAYS, 1 do
		local r = radiusDist(i, NUM_RAYS, BOUND_POINTS) * (radius - RADIUS_OFFSET)
		local theta = i * 360 * PHI
		local offsetX = r * math.cos(theta)
		local offsetZ = r * math.sin(theta)
		local rayPos = Vector3.new(
			rootPos.X + offsetX,
			rootPos.Y,
			rootPos.Z + offsetZ
		)
		local ray = Workspace:Raycast(
			rayPos,
			Vector3.new(0, -100, 0),
			rayParams
		)
		if (ray) then
			local onSlope = ray.Normal:Cross(Vector3.yAxis) ~= Vector3.zero
			local rayGndPos = ray.Position.Y
			table.insert(rayArr, ray)

            normAngle = math.deg(math.acos(ray.Normal:Dot(Vector3.yAxis)))
			--if (ray.Distance <= hipHeight + GND_CLEAR) then
			--	grounded = true
			--end
			if (rayGndPos > gndHeight and ray.Distance <= hipHeight + GND_CLEAR) then
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
		end
	end

	--return grounded, gndHeight, normal, normAngle
	return  {grounded, inWater, gndHeight, normal, normAngle} :: physData
end

return Phys.colliderCast