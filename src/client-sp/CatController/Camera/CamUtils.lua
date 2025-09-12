-- Math utility for camera modules

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local CamUtils = {}

local function round(num: number)
	return math.floor(num + 0.5)
end

-- Critically damped spring class for fluid motion effects
local Spring = {} do
	Spring.__index = Spring

	-- Initialize to a given undamped frequency and default position
	function Spring.new(freq, pos)
		return setmetatable({
			freq = freq,
			goal = pos,
			pos = pos,
			vel = 0,
		}, Spring)
	end

	-- Advance the spring simulation by `dt` seconds
	function Spring:step(dt: number)
		local f: number = self.freq::number * 2.0 * math.pi
		local g: Vector3 = self.goal
		local p0: Vector3 = self.pos
		local v0: Vector3 = self.vel

		local offset = p0 - g
		local decay = math.exp(-f*dt)

		local p1 = (offset*(1 + f*dt) + v0*dt)*decay + g
		local v1 = (v0*(1 - f*dt) - offset*(f*f*dt))*decay

		self.pos = p1
		self.vel = v1

		return p1
	end
end

CamUtils.Spring = Spring

-- map a value from one range to another
function CamUtils.map(x: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	return (x - inMin)*(outMax - outMin)/(inMax - inMin) + outMin
end

-- maps a value from one range to another, clamping to the output range. order does not matter
function CamUtils.mapClamp(x: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	return math.clamp(
		(x - inMin)*(outMax - outMin)/(inMax - inMin) + outMin,
		math.min(outMin, outMax),
		math.max(outMin, outMax)
	)
end

-- Ritter's loose bounding sphere algorithm
function CamUtils.getLooseBoundingSphere(parts: {BasePart})
	local points = table.create(#parts)
	for idx, part in pairs(parts) do
		points[idx] = part.Position
	end

	-- pick an arbitrary starting point
	local x = points[1]

	-- get y, the point furthest from x
	local y = x
	local yDist = 0

	for _, p in ipairs(points) do
		local pDist = (p - x).Magnitude

		if pDist > yDist then
			y = p
			yDist = pDist
		end
	end

	-- get z, the point furthest from y
	local z = y
	local zDist = 0

	for _, p in ipairs(points) do
		local pDist = (p - y).Magnitude

		if pDist > zDist then
			z = p
			zDist = pDist
		end
	end

	-- use (y, z) as the initial bounding sphere
	local sc = (y + z)*0.5
	local sr = (y - z).Magnitude*0.5

	-- expand sphere to fit any outlying points
	for _, p in ipairs(points) do
		local pDist = (p - sc).Magnitude

		if pDist > sr then
			-- shift to midpoint
			sc = sc + (pDist - sr)*0.5*(p - sc).Unit

			-- expand
			sr = (pDist + sr)*0.5
		end
	end

	return sc, sr
end

-- canonicalize an angle to +-180 degrees
function CamUtils.sanitizeAngle(a: number): number
	return (a + math.pi)%(2*math.pi) - math.pi
end

-- From TransparencyController
function CamUtils.round(num: number, places: number): number
	local decimalPivot = 10^places
	return math.floor(num * decimalPivot + 0.5) / decimalPivot
end

function CamUtils.isFinite(val: number): boolean
	return val == val and val ~= math.huge and val ~= -math.huge
end

function CamUtils.isFiniteVector3(vec3: Vector3): boolean
	return CamUtils.isFinite(vec3.X) and CamUtils.isFinite(vec3.Y) and CamUtils.isFinite(vec3.Z)
end

-- Legacy implementation renamed
function CamUtils.getAngleBetweenXZVectors(v1: Vector3, v2: Vector3): number
	return math.atan2(v2.X*v1.Z-v2.Z*v1.X, v2.X*v1.X+v2.Z*v1.Z)
end

function CamUtils.rotateVectorByAngleAndRound(camLook: Vector3, rotateAngle: number, roundAmount: number): number
	if camLook.Magnitude > 0 then
		camLook = camLook.Unit
		local currAngle = math.atan2(camLook.Z, camLook.X)
		local newAngle = round((math.atan2(camLook.Z, camLook.X) + rotateAngle) / roundAmount) * roundAmount
		return newAngle - currAngle
	end
	return 0
end

-- K is a tunable parameter that changes the shape of the S-curve
-- the larger K is the more straight/linear the curve gets
local k = 0.35
local lowerK = 0.8
local function sCurveTranform(t: number)
	t = math.clamp(t, -1, 1)
	if t >= 0 then
		return (k*t) / (k - t + 1)
	end
	return -((lowerK*-t) / (lowerK + t + 1))
end

local DEADZONE = 0.1
local function toSCurveSpace(t: number)
	return (1 + DEADZONE) * (2*math.abs(t) - 1) - DEADZONE
end

local function fromSCurveSpace(t: number)
	return t/2 + 0.5
end

function CamUtils.GamepadLinearToCurve(thumbstickPosition: Vector2)
	local function onAxis(axisValue)
		local sign = 1
		if axisValue < 0 then
			sign = -1
		end
		local point = fromSCurveSpace(sCurveTranform(toSCurveSpace(math.abs(axisValue))))
		point = point * sign
		return math.clamp(point, -1, 1)
	end
	return Vector2.new(onAxis(thumbstickPosition.X), onAxis(thumbstickPosition.Y))
end

local function getMouse()
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
		localPlayer = Players.LocalPlayer
	end
	assert(localPlayer)
	return localPlayer:GetMouse()
end

local savedMouseIcon: string = ""
local lastMouseIconOverride: string? = nil
function CamUtils.setMouseIconOverride(icon: string)
	local mouse = getMouse()
	-- Only save the icon if it was written by another script.
	if mouse.Icon ~= lastMouseIconOverride then
		savedMouseIcon = mouse.Icon
	end

	mouse.Icon = icon
	lastMouseIconOverride = icon
end

function CamUtils.restoreMouseIcon()
	local mouse = getMouse()
	-- Only restore if it wasn't overwritten by another script.
	if mouse.Icon == lastMouseIconOverride then
		mouse.Icon = savedMouseIcon
	end
	lastMouseIconOverride = nil
end

function CamUtils.setMouseIconEnabled(enabled: boolean)
	UserInputService.MouseIconEnabled = enabled
end

local savedMouseBehavior: Enum.MouseBehavior = Enum.MouseBehavior.Default
local lastMouseBehaviorOverride: Enum.MouseBehavior? = nil
function CamUtils.setMouseBehaviorOverride(value: Enum.MouseBehavior)
	if UserInputService.MouseBehavior ~= lastMouseBehaviorOverride then
		savedMouseBehavior = UserInputService.MouseBehavior
	end

	UserInputService.MouseBehavior = value
	lastMouseBehaviorOverride = value
end

function CamUtils.restoreMouseBehavior()
	if UserInputService.MouseBehavior == lastMouseBehaviorOverride then
		UserInputService.MouseBehavior = savedMouseBehavior
	end
	lastMouseBehaviorOverride = nil
end

local savedRotationType: Enum.RotationType = Enum.RotationType.MovementRelative
local lastRotationTypeOverride: Enum.RotationType? = nil
function CamUtils.setRotationTypeOverride(value: Enum.RotationType)
	if UserGameSettings.RotationType ~= lastRotationTypeOverride then
		savedRotationType = UserGameSettings.RotationType
	end

	UserGameSettings.RotationType = value
	lastRotationTypeOverride = value
end

function CamUtils.restoreRotationType()
	if UserGameSettings.RotationType == lastRotationTypeOverride then
		UserGameSettings.RotationType = savedRotationType
	end
	lastRotationTypeOverride = nil
end

return CamUtils