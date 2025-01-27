local Phys = {}

local NUM_RAYS = 32
local ALPHA = 2
local PHI = 1.61803398875
local RADIUS_OFFSET = 0.05
local GND_CLEAR = 1
local MAX_STEEP = 60
local VEC_UP = Vector3.new(0, 1 ,0)

local function radiusDist(k, n, b)
	if (k > n-b) then
		return 1
	else
		return math.sqrt(k-1/2) / math.sqrt(n-(b+1)/2)
	end
end

function Phys.createForces(mdl:Model)
	local defPos = mdl.PrimaryPart.CFrame 

	local velocity0 = Instance.new("Attachment")
	velocity0.Name = "Velocity0"
	velocity0.Parent = mdl.PrimaryPart
	
	local velocity1 = Instance.new("Attachment")
	velocity1.Name = "Velocity1"
	velocity1.Parent = mdl.PrimaryPart

	--local orient0 = Instance.new("Attachment")
	--orient0.Name = "Orient0"
	--orient0.CFrame = defPos
	--orient0.Parent = mdl.PrimaryPart
	--orient0.Axis = Vector3.new(0,1,0)
	--orient0.SecondaryAxis = Vector3.new(0,0,-1)

	--local alignOrient = Instance.new("AlignOrientation")
	--alignOrient.Mode = Enum.OrientationAlignmentMode.OneAttachment
	--alignOrient.AlignType = Enum.AlignType.PrimaryAxisParallel
	--alignOrient.PrimaryAxis = Vector3.new(0,1,0)
	--alignOrient.ReactionTorqueEnabled = true
	--alignOrient.RigidityEnabled = true
	--alignOrient.Attachment0 = orient0
	--alignOrient.Parent = mdl.PrimaryPart
	--alignOrient.CFrame = defPos
	--alignOrient.Enabled = true
	local vertVecForce = Instance.new("VectorForce")
	--vertVecForce.ApplyAtCenterOfMass = true
	vertVecForce.Force = Vector3.new(0, 0, 0)
	vertVecForce.RelativeTo = Enum.ActuatorRelativeTo.World
	vertVecForce.Attachment0 = velocity0
	vertVecForce.Parent = mdl.PrimaryPart

	local horVecForce = Instance.new("VectorForce")
	--horVecForce.ApplyAtCenterOfMass = true
	horVecForce.Force = Vector3.new(0, 0, 0)
	horVecForce.RelativeTo = Enum.ActuatorRelativeTo.World
	horVecForce.Attachment0 = velocity0
	horVecForce.Parent = mdl.PrimaryPart

	return vertVecForce, horVecForce
end

function Phys.colliderCast(rayCenterPos:Vector3, radius, hipHeight, rayParams:RaycastParams, currVel:Vector3)
	local rayArr = {}
	local boundPts = math.round(ALPHA * math.sqrt(NUM_RAYS))
	local grounded = false
	local gndHeight = -9999
    local normal = VEC_UP
    local normAngle = 0

	for i=1, NUM_RAYS, 1 do
		local r = radiusDist(i, NUM_RAYS, boundPts) * (radius - RADIUS_OFFSET)
		local theta = i * 360 * PHI
		local offsetX = r * math.cos(theta)
		local offsetZ = r * math.sin(theta)
		local rayPos = Vector3.new(
			rayCenterPos.X + offsetX, 
			rayCenterPos.Y, 
			rayCenterPos.Z + offsetZ
		)
		local ray = workspace:Raycast(
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
					if (normAngle <= MAX_STEEP) then
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

	return grounded, gndHeight, normal, normAngle
end

return Phys.colliderCast