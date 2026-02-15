-- Server only

local Workspace = game:GetService("Workspace")

local STREAMING_ENABLED = Workspace.StreamingEnabled

local defaultFocus

-- setup
if (STREAMING_ENABLED) then
    local basePlate = Workspace:FindFirstChild("Baseplate")
    if (basePlate) then
        defaultFocus = basePlate
    else
        defaultFocus = Instance.new("Part")
        defaultFocus.CFrame = CFrame.identity
        defaultFocus.Transparency = 1
        defaultFocus.CanCollide, defaultFocus.CanQuery, defaultFocus.CanTouch = false, false, false
        defaultFocus.Anchored = true
        defaultFocus.Parent = Workspace
    end
end

local StreamUtils = {}

function StreamUtils.setDefaultReplicationFocus(plr: Player)
    if (not STREAMING_ENABLED) then
        return
    end

    if (plr.ReplicationFocus) then
        warn("overwriting existing ReplicationFocus of "..plr.Name)
    end
    plr.ReplicationFocus = defaultFocus
end

function StreamUtils.setReplicationFocus(plr: Player, focus: BasePart)
    if (not STREAMING_ENABLED) then
        return
    end

    plr.ReplicationFocus = focus
end

return StreamUtils