-- Various utility functions involving vectors and numbers

local VEC3_ZERO = Vector3.zero
local VEC3_UP = Vector3.new(0, 1, 0)

local DEFAULT_RATE = 0.5 -- balanced, as all things should be

local MathUtil = {}

-- Standard lerp function;
-- v0: current, v1: target, dt: time delta
function MathUtil.lerp(v0: number, v1: number, dt: number): number
	-- if (math.abs(v1 - v0) < 0.1) then
	-- 	return v1
	-- end
	return (1 - dt) * v0 + dt * v1
end

-- v0: current, v1: target, dt: time delta
function MathUtil.easeOutQuad(v0: number, v1: number, dt: number): number
    return -(v1 - v0) * dt * (dt - 2) + v0
end

-- Framerate independent lerp function; slightly less efficient than lerp;
-- v0: current, v1: target, r: rate (value between 0 and 1), dt: time delta
function MathUtil.flerp(v0: number, v1: number, dt: number, r: number?): number
	local _r = r
    if (not _r) then
        _r = DEFAULT_RATE
    end
	return MathUtil.lerp(v0, v1, 1 - math.pow(_r, dt))
end

-- Standard lerp for each value of the Vector3;
-- vec0: current, vec1: target, r: rate (value between 0 and 1), dt: time delta
function MathUtil.vec3Lerp(vec0: Vector3, vec1: Vector3, dt:number): Vector3
	return Vector3.new(
		MathUtil.lerp(vec0.X, vec1.X, dt),
		MathUtil.lerp(vec0.Y, vec1.Y, dt),
		MathUtil.lerp(vec0.Z, vec1.Z, dt)
	)
end

-- Framerate independent lerp for each value of the Vector3;
-- vec0: current, vec1: target, r: rate (value between 0 and 1), dt: time delta
function MathUtil.vec3Flerp(vec0: Vector3, vec1: Vector3, dt: number, r: number?): Vector3
	return Vector3.new(
		MathUtil.flerp(vec0.X, vec1.X, dt, r),
		MathUtil.flerp(vec0.Y, vec1.Y, dt, r),
		MathUtil.flerp(vec0.Z, vec1.Z, dt, r)
	)
end

-- Clamps each value of the Vector3, equivalent to math.clamp
function MathUtil.vec3Clamp(vec: Vector3, vMin: Vector3, vMax: Vector3): Vector3
	return Vector3.new(
		math.clamp(vec.X, vMin.X, vMax.X),
		math.clamp(vec.Y, vMin.Y, vMax.Y),
		math.clamp(vec.Z, vMin.Z, vMax.Z)
	)
end

-- Project a Vector3 onto a plane with given plane normal
function MathUtil.projectOnPlaneVec3(v: Vector3, norm: Vector3): Vector3
    local sqrMag = norm:Dot(norm)
    if (sqrMag < 0.01) then
        return v
    end
    local dot = v:Dot(norm)
    return Vector3.new(
        v.X - norm.X * dot / sqrMag,
        v.Y - norm.Y * dot / sqrMag,
        v.Z - norm.Z * dot / sqrMag
    )
end

-- Rotates a Vector3 around another vector with a given angle in radiants
function MathUtil.rotateAroundAxisVec3(vec: Vector3, axisVec: Vector3, phi: number): Vector3
	local k = axisVec.Unit
	local cos = math.cos(phi)
	local sin = math.sin(phi)

	return vec * cos
	+ k:Cross(vec) * sin
	+ k * (k:Dot(vec) * (1 - cos))
end

-- Returns the angle between two vectors
function MathUtil.getAngleVec3(v0: Vector3, v1: Vector3): number
    local dot = v0.Unit:Dot(v1.Unit)

    -- compensate for rounding errors
    if (dot > 1) then dot = 1.0 end
    if (dot < -1) then dot = -1.0 end

    return math.acos(dot)
end

-- Clamps a Vector3 to a virtual cone with a given angle in radiants
function MathUtil.clampVectorToCone(v: Vector3, n: Vector3, phi: number): Vector3
    local mag = v.Magnitude
    if (mag < 0.01) then
        return v
    end

    local u = v.Unit
    local axis = n.Unit

    local dot = math.clamp(u:Dot(axis), -1, 1)
    local theta = math.acos(dot)

	-- Return v, if located inside the cone
    if (theta <= phi) then
        return v
    end

    -- Project onto cone surface
    local cosPhi = math.cos(phi)
    local sinPhi = math.sin(phi)

    local perp = u - axis * dot
    local perpMag = perp.Magnitude

    if (perpMag < 0.01) then
        perp = axis:Cross(Vector3.new(1,0,0))
        if (perp.Magnitude < 0.01) then
            perp = axis:Cross(Vector3.new(0,1,0))
        end
        perp = perp.Unit
    else
        perp = perp / perpMag
    end

    local uProj = (axis * cosPhi + perp * sinPhi).Unit

    return uProj * mag
end

-- Returns the average of a given array of vectors
function MathUtil.avgVecFromVecs(vecArr: {Vector3}): Vector3
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

-- Calculates a virtual plane normal from given points
function MathUtil.avgPlaneFromPoints(ptsArr: {Vector3}) : {centroid: Vector3, normal: Vector3}
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

-- Returns the height of a plane at any given point 
function MathUtil.planeHeightAtPoint(centroid: Vector3, normal: Vector3, loc: Vector3): number
	local x, z = loc.X, loc.Z
	return centroid.Y - ((normal.X * (x - centroid.X) + normal.Z * (z - centroid.Z)) / normal.Y)
end

------------------------------------------------------------------------------------------------------------------------
-- Quaternions
------------------------------------------------------------------------------------------------------------------------

-- Constructs a Quaternion (set of numbers) from the rotation components of the given CFrame
-- returns components in order: x, y, z, w
function MathUtil.createQuaternionFromCFrame(cframe: CFrame): (number, number, number, number)
	local _, _, _, m00, m01, m02, m10, m11, m12, m20, m21, m22 = cframe:Orthonormalize():GetComponents()

	local x, y, z, w

	local trace = m00 + m11 + m22
	if (trace > 0) then
		local s = math.sqrt(trace + 1) * 2
		x = (m21 - m12) / s
		y = (m02 - m20) / s
		z = (m10 - m01) / s
		w = 0.25 * s
	elseif (m00 > m11 and m00 > m22) then
		local s = math.sqrt(1 + m00 - m11 - m22) * 2
		x = 0.25 * s
		y = (m01 + m10) / s
		z = (m02 + m20) / s
		w = (m21 - m12) / s
	elseif (m11 > m22) then
		local s = math.sqrt(1 + m11 - m00 - m22) * 2
		x = (m01 + m10) / s
		y = 0.25 * s
		z = (m12 + m21) / s
		w = (m02 - m20) / s
	else
		local s = math.sqrt(1 + m22 - m00 - m11) * 2
		x = (m02 + m20) / s
		y = (m12 + m21) / s
		z = 0.25 * s
		w = (m10 - m01) / s
	end

	return x, y, z, w
end

-- Converts a Qaternion (set of numbers) to a CFrame
function MathUtil.getCFrameFromQuaternion(x: number, y: number, z: number, w: number, position: Vector3?): CFrame
	local pos = position or VEC3_ZERO

	-- local mag = math.sqrt(x*x + y*y + z*z * w*w)
	-- x, y, z, w = x/mag, y/mag, z/mag, w/mag
	return CFrame.new(pos.X, pos.Y, pos.Z, x, y, z, w)
end

return MathUtil