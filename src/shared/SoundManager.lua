--[[
    Sound manager module.

    Creates predefined sound instances for each player and plays them across the 
    server-client boundary for other players.
    This module is meant to be used client-side only.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerSoundItem = require(ReplicatedStorage.Shared.Enums.PlayerSoundItem)
local Network = require(ReplicatedStorage.Shared.Network)
local CliNetApi = require(ReplicatedStorage.Shared.GameClient.CliNetApi)

local SOUND_DATA = table.freeze({
    [PlayerSoundItem.DAMAGE] = {
        SoundId = "rbxassetid://5466166437",
    },
    [PlayerSoundItem.JUMP] = {
        SoundId = "rbxassetid://86604727900745",--"rbxassetid://5466166437",
        Volume = 0.5,
    },
    [PlayerSoundItem.FLOOR_HIT] = {
        SoundId = "rbxassetid://127822240770734",--"rbxassetid://135370882594044",
        Volume = 1.2,
        PlaybackRegionsEnabled = true,
        PlaybackRegion = NumberRange.new(0, 0.15)
    },
    [PlayerSoundItem.WATER_SPLASH] = {
        SoundId = "rbxassetid://5466166437",
    },
    [PlayerSoundItem.WATER_MOVEMENT] = {
        SoundId = "rbxassetid://5466166437",
    },
})

local soundEffectsMap = {} :: {[Sound]: {SoundEffect}}
local playerSoundsMap = {} :: {[Player]: {[string]: Sound}}
local playerConnTbl = {} :: {[Player]: {RBXScriptConnection}}

local localPlr = Players.LocalPlayer

------------------------------------------------------------------------------------------------------------------------

-- Creates a sound instance that is parented to a player's primary part, maps sound item to player
local function createSounds(plr: Player, char: Model, item: string)
    local primaryPart = char.PrimaryPart
    assert(primaryPart, `Missing primary part of '{plr.Name}'`)

    local sound = Instance.new("Sound", primaryPart)
    sound.Name = item

    -- set all predefined sound properties
    for propName: string, propVal: any in pairs(SOUND_DATA[item]) do
        sound[propName] = propVal
    end

    -- map sound item to player
    if (not playerSoundsMap[plr]) then
        playerSoundsMap[plr] = {}
    end
    playerSoundsMap[plr][item] = sound
end

local function resetSound(sound: Sound)
    sound:Stop()
    sound:Play()
end

local function updateSound(sound: Sound, play: boolean)
    if (not play) then
        if (sound.IsPlaying) then
            sound:Stop()
        end
        sound.TimePosition = 0
    end
    if (sound.Looped) then
        if (sound.IsPlaying) then
            return
        end
        resetSound(sound)
    else
        if (play) then
            resetSound(sound)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------

local SoundManager = {
    soundItem = PlayerSoundItem
}

function SoundManager.init()
    local function addPlrSounds(plr: Player, char: Model)
        for _, item: string in pairs(PlayerSoundItem) do
            createSounds(plr, char, item)
        end
    end

    local function clearPlrSounds(plr: Player)
        if (not playerSoundsMap[plr]) then
            return
        end
        for _, sound: Sound in pairs(playerSoundsMap[plr]) do
            sound:Destroy()
        end
        playerSoundsMap[plr] = nil
    end

    local function onPlayerAdded(plr: Player)
        local charAddedConn = plr.CharacterAdded:Connect(function(char: Model) addPlrSounds(plr, char) end)
        local charRemConn = plr.CharacterRemoving:Connect(function(char: Model) clearPlrSounds(plr) end)
        playerConnTbl[plr] = {charAddedConn, charRemConn}
    end

    local function onPlayerRemoving(plr: Player)
        if (playerConnTbl[plr]) then
            for _, c: RBXScriptConnection in pairs(playerConnTbl[plr]) do
                c:Disconnect()
            end
            playerConnTbl[plr] = nil
        end
        clearPlrSounds(plr)
    end

    ---------------------------------

    -- in case init was called before
    if (playerConnTbl) then
        for plr: Player, _ in pairs(playerConnTbl) do
            for _, c: RBXScriptConnection in pairs(playerConnTbl[plr]) do
                c:Disconnect()
            end
        end
    end
    playerConnTbl = {}

    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)

    -- add sounds for existing players
    for _, plr: Player in pairs(Players:GetPlayers()) do
        onPlayerAdded(plr)
        local char = plr.Character
        if (char and char.PrimaryPart) then
            addPlrSounds(plr, char)
        end
    end
end

------------------------------------------------------------------------------------------------------------------------

-- Updates the specified sound item of another player
function SoundManager.updatePlayerSound(plr: Player, item: string, play: boolean)
    if (plr == localPlr) then 
        return 
    end
    if (not (playerSoundsMap[plr] and playerSoundsMap[plr][item])) then
        warn("No sound"); return
    end
    updateSound(playerSoundsMap[plr][item], play)
end

-- Plays the specified sound item locally
function SoundManager.playLocal(item: string, play: boolean)
    local sound = playerSoundsMap[localPlr][item]
    if (not sound) then error(`Nonexisten sound for '{item}'`) end

    updateSound(sound, play)
end

function SoundManager.updateGlobalSound(item: string, play: boolean)
    SoundManager.playLocal(item, play)
    CliNetApi.events[Network.clientEvents.requestSound]:FireServer(item, play)
end

function SoundManager.addSoundEffects(sound: Sound, effects: {SoundEffect})
    local tbl = soundEffectsMap[sound] and soundEffectsMap[sound] or {}
    for _, eff: SoundEffect in pairs(effects) do
        eff.Parent = sound
        eff.Enabled = true
        table.insert(tbl, eff)
    end
    soundEffectsMap[sound] = tbl
end

function SoundManager.clearAllEffects(sound: Sound)
    local tbl = soundEffectsMap[sound]
    if (tbl) then
        for _, e: SoundEffect in pairs(tbl) do
            e:Destroy()
        end 
    end
    soundEffectsMap[sound] = nil
end

return SoundManager