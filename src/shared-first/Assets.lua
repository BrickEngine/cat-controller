-- Defines assets that should be loaded into the game first

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")

local UDIM_ZERO = UDim.new(0, 0)

-- invisible GUI for loading images
local loadedContentGui = Instance.new("ScreenGui", Players.LocalPlayer.PlayerGui)
loadedContentGui.Name = "ABLABLABLA"

local function createImgLabel(id: string)
    local imgLabel = Instance.new("ImageLabel", loadedContentGui)
    imgLabel.Size = UDim2.new(UDIM_ZERO, UDIM_ZERO)
    imgLabel.Image = id
    imgLabel.Name = id
end

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------

local Assets = {
    IMAGE_IDS = table.freeze({
        BTN_RUN_ACTIVE = "rbxassetid://11677094284",
        BTN_RUN_INACTIVE = "rbxassetid://9083826575"
    }),

    AUDIO_IDS = table.freeze({
        LOAD_SCREEN_MUSIC = ""
    }),

    loaded = false
}

------------------------------------------------------------------------------------------------------------------------

function Assets.preLoad()
    local function callback(cId: string, status: Enum.AssetFetchStatus)
        if (status == Enum.AssetFetchStatus.Failure) then
            warn(`[LOAD] - Failed to load asset {cId}`)
        end
    end

    local contTbl = {}
    for _, id: string in pairs(Assets.IMAGE_IDS) do
        table.insert(contTbl, id)
    end
    for _, id: string in pairs(Assets.AUDIO_IDS) do
        table.insert(contTbl, id)
    end

    ContentProvider:PreloadAsync(contTbl, callback)
end

function Assets.preLoadImgPhysical()
    local imgTbl = {}
    for _, id: string in pairs(Assets.IMAGE_IDS) do
        table.insert(imgTbl, id)
    end

    for i, imgId: string in ipairs(imgTbl) do
        createImgLabel(imgId)
    end
    loadedContentGui.Enabled = true
    loadedContentGui.DisplayOrder = -999
    loadedContentGui.AbsolutePosition = -999 * Vector2.one
end

return Assets