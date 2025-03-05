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

    clientEvents = {
        requestSpawn = "requestSpawn",
        requestDespawn = "requestDespawn"
    },
    serverEvents = {

    },
    remoteFunctions = {

    }
}

return NetApi