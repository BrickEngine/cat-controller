local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetApi = require(ReplicatedStorage.Shared.NetworkApi)

-- Init folder for storing events
local apiObjFold = Instance.new("Folder")
apiObjFold.Name = NetApi.FOLD_NAME
apiObjFold.Parent = ReplicatedStorage

local ServApi = {}

-- Table of events to implement
function ServApi.implementREvents(tbl: any)
    for _, eventName in ipairs(NetApi.definitions.clientEvents) do
        local remEvent = Instance.new("RemoteEvent")
        remEvent.Name = eventName

        local serverMethod = tbl[eventName]

        if not serverMethod then
			error("missing RE implementation for " .. tostring(eventName))
		end

        remEvent.OnServerEvent:Connect(serverMethod)

        remEvent.Parent = apiObjFold
    end
end

function ServApi.implementRFunctions(tbl: any)
    for _, eventName in ipairs(NetApi.definitions.remoteFunctions) do
        local remFunc = Instance.new("RemoteFunction")
        remFunc.Name = eventName
        remFunc.Parent = apiObjFold

        local serverMethod = tbl[eventName]

        if not serverMethod then
			error("missing RF implementation for " .. tostring(eventName))
		end

        remFunc.OnServerInvoke = function(...)
            return serverMethod(...)
        end
    end
end

return ServApi