local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionGroups = require(ReplicatedStorage.Shared.CollisionGroups)

local DebugVisualize = require(script.Parent.DebugVisualize)

local NUM_RAYS = 32
local RADIUS_OFFSET = 0.05
local RAY_Y_OFFSET = 0.1
local PHI = 1.61803398875

local VEC3_ZERO = Vector3.zero
local VEC3_UP = Vector3.new(0, 1 ,0)
local BOUND_POINTS = math.round(2 * math.sqrt(NUM_RAYS))

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
	-- how did I overlook this?
	if (dir:Dot(VEC3_UP) < 0) then
		dir = -dir
	end

	return {
		centroid = centroid,
		normal = dir.Unit
	}
end

local Phys = {}

export type physData = {
	grounded: boolean,
	pos: Vector3,
	normal: Vector3,
	gndHeight: number,
	normalAngle: number
}

function Phys.colliderCast(
	rootPos: Vector3,
	maxRadius: number,
	hipHeight: number,
	gndClearDist: number,
	rayParams: RaycastParams
)
	local _grounded = false
	local targetPos = -VEC3_UP * 9999
    local targetNorm = VEC3_UP
    local pNormAngle = 0

	local numHits = 0
	local adjHipHeight = hipHeight + RAY_Y_OFFSET

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

	DebugVisualize.normalPart(targetPos, targetNorm, Vector3.new(0.1,0.1,2))

	return {
        grounded = _grounded,
		pos = targetPos,
		normal = targetNorm.Unit,
        gndHeight = targetPos.Y,
        normalAngle = pNormAngle
    } :: physData
end

return Phys.colliderCast