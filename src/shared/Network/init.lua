--[[
    RemoteEvent and RemoteFunction object definitions for server-client communication:

    clientEvents - fired by client, observed by server;
    serverEvents - fired by server, observed by client;
    remoteFunctions - always invoked by client;
--]]
local NetApi = {

    FOLDER_NAME = "NetworkInstContainer",

    -- client -> server
    clientEvents = {
        requestSpawn = "RequestSpawn",
        requestDespawn = "RequestDespawn",
        requestSound = "RequestSound"
    },
    clientFastEvents = {
        jointsDataToServer = "JointsDataToServer"
    },
    -- server -> client
    serverEvents = {
        playSound = "PlaySound",
    },
    serverFastEvents = {
        jointsDataToClient = "JointsDataToClient"
    },
    -- client -> server -> client
    remoteFunctions = {

    }
}

return NetApi