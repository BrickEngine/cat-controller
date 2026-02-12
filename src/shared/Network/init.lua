--[[
    RemoteEvent and RemoteFunction object definitions for server-client communication:

    clientEvents - fired by client, observed by server;
    serverEvents - fired by server, observed by client;
    remoteFunctions - always invoked by client;
--]]
local NetApi = table.freeze({

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
})

-- Assert all network object names are unique
local function findDuplicates(tbl: {[any]: any})
    local seen = {}
    local duplicated = {}

    local function traverse(subTbl)
        for i,_ in pairs(subTbl) do
            local element = subTbl[i]
            if (type(element) == 'table') then
                traverse(element)
            else
                if (seen[element]) then 
                    duplicated[element] = true
                else
                    seen[element] = true
                end 
            end 
        end 
    end
    traverse(tbl)

    return duplicated
end

local duplicates = findDuplicates(NetApi)
if (duplicates and #duplicates ~= 0) then
    error("There are duplicate network object name definitions")
end

return NetApi