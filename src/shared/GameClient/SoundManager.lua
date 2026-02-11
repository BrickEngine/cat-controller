--[[
    Sound manager module.

    Creates predefined sound instances and plays them across the server-client boundary for
    clients.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SoundItem = require(ReplicatedStorage.Shared.Enums.SoundItem)
local Network = require(ReplicatedStorage.Shared.Network)
local CliNetApi = require(ReplicatedStorage.Shared.GameClient.CliNetApi)

local soundIds= table.freeze({
    [SoundItem.DAMAGE] = "",
    [SoundItem.JUMP] = "rbxassetid://5466166437",
    [SoundItem.WATER_SPLASH] = "",
    [SoundItem.WATER_MOVEMENT] = "",
})

local function configSound(sound: Sound, volume: number, loopRegion: NumberRange, effect: SoundEffect?)
    sound.Volume = volume
    sound.LoopRegion = loopRegion

    if (effect) then
        effect.Parent = sound
        effect.Enabled = true
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------

local SoundManager = {
    sounds = {} :: {[string]: Sound},
    soundParts = {} :: {[string]: BasePart}
}

function SoundManager.playLocal(item: string)
    SoundManager.sounds[item]:Play()
end

function SoundManager.playLocalOnPart(part: BasePart)
    local sound = part:FindFirstChildWhichIsA("Sound")
    assert(sound, "Missing sound")


end

function SoundManager.playGlobalAtPos(
    item: string, volume: number, loopRegion: NumberRange, position: Vector3, effect: SoundEffect?
)
    local part = SoundManager.soundParts[item]
    part.Position = position

    SoundManager.playGlobalOnPart(item, volume, loopRegion, part, effect)
end

function SoundManager.playGlobalOnPart(
    item: string, volume: number, loopRegion: NumberRange, part: BasePart, effect: SoundEffect?
)
    assert(SoundManager.sounds[item], `No sound item found with name '{item}'`)

    local sound = SoundManager.sounds[item]
    configSound(sound, volume, loopRegion, effect)
    sound.Parent = part

    SoundManager.playLocal(item)
    CliNetApi[Network.clientEvents.requestSound](part)
end

function SoundManager.broadcast()
    
end

-- Init sound instances
do
    local soundFolder = Instance.new("Folder", Workspace)
    soundFolder.Name = "SoundInstances"

    for _, itemName: string in pairs(SoundItem) do
        if (not soundIds[itemName]) then
            warn(`No sound id table entry for {itemName}`); continue
        end

        local sound = Instance.new("Sound", soundFolder)
        local soundPart = Instance.new("Part", soundFolder)
        sound.Name = itemName
        soundPart.Name = itemName .. "Part"

        soundPart.CanCollide, soundPart.CanQuery, soundPart.CanTouch = false, false, false
        soundPart.Anchored = true; soundPart.Transparency = 1

        sound.SoundId = soundIds[itemName]

        SoundManager.soundParts[itemName] = soundPart
        SoundManager.sounds[itemName] = sound
    end
end

return SoundManager