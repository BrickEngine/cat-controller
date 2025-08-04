local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- source / license:
-- https://github.com/LPGhatguy/luanoid
-- license: CC0, MIT

local Global = require(ReplicatedStorage.Shared.Global)

local Terrain = game:GetService("Workspace").Terrain

local unusedPoints = {}
local usedPoints = {}
local unusedVectors = {}
local usedVectors = {}
local unusedParts = {}
local usedParts = {}

local DebugVisualize = {
	enabled = Global.GAME_PHYS_DEBUG,
}

function DebugVisualize.point(position, color)
	if not DebugVisualize.enabled then
		return
	end

	local instance = table.remove(unusedPoints)

	if not instance then
		instance = Instance.new("SphereHandleAdornment")
		instance.ZIndex = 1
		instance.Name = "Debug Handle"
		instance.AlwaysOnTop = true
		instance.Radius = 0.04
		instance.Adornee = Terrain
		instance.Parent = Terrain
	end

	instance.CFrame = CFrame.new(position)
	instance.Color3 = color

	table.insert(usedPoints, instance)
end

function DebugVisualize.vector(position, direction, color)
	if (not DebugVisualize.enabled) then
		return
	end

	local instance = table.remove(unusedVectors)

	if not instance then
		instance = Instance.new("BoxHandleAdornment")
		instance.Color3 = Color3.new(1, 1, 1)
		instance.AlwaysOnTop = true
		instance.ZIndex = 2
		instance.Transparency = 0.25
		instance.Size = Vector3.new(0.1, 0.1, 1)
		instance.Parent = Terrain
		instance.Adornee = Terrain
	end

	instance.CFrame = CFrame.new(position, position + direction)
	instance.Color3 = color

	table.insert(usedVectors, instance)
end

function DebugVisualize.normalPart(pos: Vector3, norm: Vector3, size: Vector3?)
	if (not DebugVisualize.enabled) then
		return
	end

	local part = table.remove(unusedParts)

	if (not part) then
		part = Instance.new("Part", workspace)
		part.Anchored = true
		part.CanCollide = false
		if (size) then
			part.Size = size
		else
			part.Size = Vector3.new(0.1, 0.1, 0.1)
		end
	end

	part.CFrame = CFrame.lookAlong(pos, norm)
	part.Color = Color3.fromRGB(51, 0, 255)

	table.insert(usedParts, part)
end

function DebugVisualize.step()
	while #unusedPoints > 0 do
		table.remove(unusedPoints):Destroy()
	end

	while #unusedVectors > 0 do
		table.remove(unusedVectors):Destroy()
	end

	while #unusedParts > 0 do
		table.remove(unusedParts):Destroy()
	end

	usedPoints, unusedPoints = unusedPoints, usedPoints
	usedVectors, unusedVectors = unusedVectors, usedVectors
	usedParts, unusedParts = unusedParts, usedParts
end

return DebugVisualize