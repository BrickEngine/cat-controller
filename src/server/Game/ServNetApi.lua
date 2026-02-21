local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)

local LOG_EVENTS = true
local LOG_FAST_EVENTS = false

-- Create the folder for storing network objects, if it does not exist
local netContainer = ReplicatedStorage:FindFirstChild(Network.FOLDER_NAME)
if (not netContainer) then
    netContainer = Instance.new("Folder", ReplicatedStorage)
    netContainer.Name = Network.FOLDER_NAME
end

local function addApiObject(obj: Instance, name: string)
    obj.Parent = netContainer
    obj.Name = name
end

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------

local ServApi = {
    events = {} :: {[string]: RemoteEvent},
	fastEvents = {} :: {[string]: UnreliableRemoteEvent}
}

------------------------------------------------------------------------------------------------------------------------
-- SERVER -> CLIENT(S)
------------------------------------------------------------------------------------------------------------------------

-- Create network instaces for clients, which are sent by clients
do
    for _, eventName in pairs(Network.serverEvents) do
        local remEvent = Instance.new("RemoteEvent")
        addApiObject(remEvent, eventName)
        ServApi.events[eventName] = remEvent
    end

    for _, eventName in pairs(Network.serverFastEvents) do
        local fastRemEvent = Instance.new("UnreliableRemoteEvent")
        addApiObject(fastRemEvent, eventName)
        ServApi.fastEvents[eventName] = fastRemEvent
    end
end

local function logEvent(str: string, isFastEvent: boolean)
    if (not LOG_EVENTS or (isFastEvent and not LOG_FAST_EVENTS)) then
        return
    end
    print("[NET] - "..str)
end
------------------------------------------------------------------------------------------------------------------------
-- CLIENT -> SERVER
------------------------------------------------------------------------------------------------------------------------

-- Implements RemoteEvents from table
function ServApi.implementREvents(tbl: any)
    for _, eventName in pairs(Network.clientEvents) do
        local serverMethod = tbl[eventName]
        local remEvent = Instance.new("RemoteEvent")
        addApiObject(remEvent, eventName)

        if (not serverMethod) then
			warn(`Missing RE implementation for '{eventName}'`); continue
        end
        remEvent.OnServerEvent:Connect(function(...)  
            logEvent(`Server received '{eventName}'`, false)
            serverMethod(...)
        end)
    end
end

-- Implements FastRemoteEvents from table
function ServApi.implementFastREvents(tbl: any)
    for _, eventName in pairs(Network.clientFastEvents) do
        local serverMethod = tbl[eventName]
        local fastRemEvent = Instance.new("UnreliableRemoteEvent")
        addApiObject(fastRemEvent, eventName)

        if (not serverMethod) then
			warn(`Missing FastRE implementation for '{eventName}'`); continue
        end
        fastRemEvent.OnServerEvent:Connect(function(...)  
            logEvent(`Server received '{eventName}'`, true)
            serverMethod(...)
        end)
    end
end

-- Implements RemoteFunctions from table
function ServApi.implementRFunctions(tbl: any)
    for _, eventName in pairs(Network.remoteFunctions) do
        local serverMethod = tbl[eventName]
        local remFunc = Instance.new("RemoteFunction")
        addApiObject(remFunc, eventName)

        if not serverMethod then
			warn(`Missing RF implementation for '{eventName}'`); continue
		end
        remFunc.OnServerInvoke = function(...)
            return serverMethod(...)
        end
    end
end
-- Connects functions to RemoteEvents
function ServApi.setConnection(name: string, func: any)
    assert(Network[name], "Missing definition of: "..name)
end

return ServApi