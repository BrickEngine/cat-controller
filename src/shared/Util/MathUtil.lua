-- Various utility functions involving vectors and numbers

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


return MathUtil