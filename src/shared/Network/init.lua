--[[
    RemoteEvent and RemoteFunction object definitions for server-client communication:

    clientEvents - fired by client, observed by server;
    serverEvents - fired by server, observed by client;
    remoteFunctions - always invoked by client;
--]]
local NetApi = {

    CONTAINER_NAME = "NetworkContainer",
    -- refs to network objects
    container = {},

    -- client -> server
    clientEvents = {
        requestSpawn = "RequestSpawn",
        requestDespawn = "RequestDespawn"
    },
    clientFastEvents = {
        cJointsDataSend = "CJointsDataSend"
    },
    -- server -> client
    serverEvents = {

    },
    serverFastEvents = {
        CJointsDataReceive = "CJointsDataReceive"
    },
    -- client -> server -> client
    remoteFunctions = {

    }
}

return NetApi