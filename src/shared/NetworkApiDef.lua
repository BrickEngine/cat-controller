--[[
    RemoteEvent and RemoteFunction object definitions for server-client communication:

    clientEvents := fired by client, observed by server
    serverEvents := fired by server, observed by client
    remoteFunctions := always invoked by client
--]]

local FOLD_NAME = "Network"

local NetApi = {}

NetApi = {
    FOLD_NAME = FOLD_NAME,

    -- client -> server
    clientEvents = {
        requestSpawn = "REQUEST_SPAWN",
        requestDespawn = "REQUEST_DESPAWN"
    },
    clientFastEvents = {
        cJointsDataSend = "C_JOINTS_DATA_SEND"
    },
    -- server -> client
    serverEvents = {

    },
    serverFastEvents = {
        cJointsDataRec = "C_JOINTS_DATA_REC"
    },
    -- client -> server -> client
    remoteFunctions = {

    }
}

return NetApi