local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)

-- Create the folder for storing network objects, if it does not exist
local netContainer = ReplicatedStorage:FindFirstChild(Network.CONTAINER_NAME)
if (not netContainer) then
    netContainer = Instance.new("Folder", ReplicatedStorage)
    netContainer.Name = Network.CONTAINER_NAME
end

local function addApiObject(obj: Instance)
    obj.Parent = netContainer
    Network.container[obj.Name] = obj
end

local ServApi = {}

-- table of RemoteEvents to implement
function ServApi.implementREvents(tbl: any)
    for _, eventName in pairs(Network.clientEvents) do
        local remEvent = Instance.new("RemoteEvent")
        remEvent.Name = eventName

        local serverMethod = tbl[eventName]

        if not serverMethod then
			warn("missing RE implementation for " .. tostring(eventName))
        else
            remEvent.OnServerEvent:Connect(serverMethod)
            addApiObject(remEvent)
        end
    end
end

-- table of FastRemoteEvents to implement
function ServApi.implementFastREvents(tbl: any)
    for _, eventName in pairs(Network.clientFastEvents) do
        local fastRemEvent = Instance.new("UnreliableRemoteEvent")
        fastRemEvent.Name = eventName

        local serverMethod = tbl[eventName]

        if not serverMethod then
			warn("missing RE implementation for " .. tostring(eventName))
		else
            fastRemEvent.OnServerEvent:Connect(serverMethod)
            addApiObject(fastRemEvent)
        end
    end
end

-- table of RemoteFunctions to implement
function ServApi.implementRFunctions(tbl: any)
    for _, eventName in pairs(Network.remoteFunctions) do
        local remFunc = Instance.new("RemoteFunction")
        remFunc.Name = eventName
        remFunc.Parent = netContainer

        local serverMethod = tbl[eventName]

        if not serverMethod then
			warn("missing RF implementation for " .. tostring(eventName))
		end

        remFunc.OnServerInvoke = function(...)
            return serverMethod(...)
        end
    end
end

--[[
    Connects functions to RemoteEvents
]]
function ServApi.setConnection(name: string, func: any)
    assert(Network[name], "Missing definition of: "..name)


end

return ServApi