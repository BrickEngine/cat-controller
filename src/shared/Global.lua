-- Global constants for client and server side modules.

local RunService = game:GetService("RunService")
RunService:GetActor()

local PRINT_INFO_DEBUG = true

return table.freeze({
    GAME_PHYS_DEBUG = false,
    GAME_CHAR_DEBUG = false,
    GAME_UI_DEBUG = false,

    PLAYERS_INST_FOLDER_NAME = "PlayerInstContainer",

    logInfo = function(...)
        if (not PRINT_INFO_DEBUG) then return end
        print("[INFO] - " .. ... .."  -  " .. debug.info(2, "s"):match("([^%.]+)$"))
    end,
})