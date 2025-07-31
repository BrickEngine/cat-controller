local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetApiDef = require(ReplicatedStorage.Shared.NetworkApiDef)

-- Init folder for storing events
local apiObjFold = Instance.new("Folder")
apiObjFold.Name = NetApiDef.FOLD_NAME
apiObjFold.Parent = ReplicatedStorage

local ServApi = {}

-- table of RemoteEvents to implement
function ServApi.implementREvents(tbl: any)
    for _, eventName in pairs(NetApiDef.clientEvents) do
        local remEvent = Instance.new("RemoteEvent")
        remEvent.Name = eventName

        local serverMethod = tbl[eventName]

        if not serverMethod then
			warn("missing RE implementation for " .. tostring(eventName))
		end

        remEvent.OnServerEvent:Connect(serverMethod)

        remEvent.Parent = apiObjFold
    end
end

-- table of FastRemoteEvents to implement
function ServApi.implementFastREvents(tbl: any)
    for _, eventName in pairs(NetApiDef.clientFastEvents) do
        local fastRemEvent = Instance.new("UnreliableRemoteEvent")
        fastRemEvent.Name = eventName

        local serverMethod = tbl[eventName]

        if not serverMethod then
			warn("missing RE implementation for " .. tostring(eventName))
		end

        fastRemEvent.OnServerEvent:Connect(serverMethod)

        fastRemEvent.Parent = apiObjFold
    end
end

-- table of RemoteFunctions to implement
function ServApi.implementRFunctions(tbl: any)
    for _, eventName in pairs(NetApiDef.remoteFunctions) do
        local remFunc = Instance.new("RemoteFunction")
        remFunc.Name = eventName
        remFunc.Parent = apiObjFold

        local serverMethod = tbl[eventName]

        if not serverMethod then
			warn("missing RF implementation for " .. tostring(eventName))
		end

        remFunc.OnServerInvoke = function(...)
            return serverMethod(...)
        end
    end
end

return ServApi