-- disable default roblox scripts

local Player = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local playerScripts = Player.LocalPlayer:WaitForChild("PlayerScripts")

local DEFAULT_SCRIPT_NAMES = {
    "PlayerModule",
    "PlayerScriptsLoader",
    "RbxCharacterSounds"
} :: string

local function destroyObjWithDelay(obj: Instance, delay: number)
    task.wait(delay); obj:Destroy()
end

local function deleteDefaultPlayerModule(obj: Instance)
    if (not obj:IsA("LocalScript")) then
        return
    end
    for i, str: string in ipairs(DEFAULT_SCRIPT_NAMES) do
        if (obj.Name == str) then
            obj.Enabled = false
            task.spawn(destroyObjWithDelay, obj, 0.5)
        end
    end
end

local function disableCoreGuis()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.EmotesMenu, false)
end

playerScripts.ChildAdded:Connect(deleteDefaultPlayerModule)
disableCoreGuis()

for _, v in pairs(playerScripts:GetChildren()) do
    deleteDefaultPlayerModule(v)
end