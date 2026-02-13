local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(ReplicatedStorage.Shared.Network)

local netObjFolder = ReplicatedStorage:WaitForChild(Network.FOLDER_NAME)

------------------------------------------------------------------------------------------------------------------------
-- Module
------------------------------------------------------------------------------------------------------------------------

local CliApi = {
	events = {} :: {[string]: RemoteEvent},
	fastEvents = {} :: {[string]: UnreliableRemoteEvent}
}

------------------------------------------------------------------------------------------------------------------------
-- CLIENT -> SERVER
------------------------------------------------------------------------------------------------------------------------

-- Connect client side network instances to functions and check if they were already created
do
	for _, eventName in pairs(Network.clientEvents) do
		local remEvent = netObjFolder:WaitForChild(eventName)

		assert(remEvent, `Missing RemoteEvent for '{eventName}'`)
		CliApi.events[eventName] = remEvent
	end

	for _, eventName in pairs(Network.clientFastEvents) do
		local fastRemEvent = netObjFolder:WaitForChild(eventName)

		assert(fastRemEvent, `Missing FastRemoteEvent for '{eventName}'`)
		CliApi.fastEvents[eventName] = fastRemEvent
	end
end

------------------------------------------------------------------------------------------------------------------------
-- SERVER -> CLIENT
------------------------------------------------------------------------------------------------------------------------

-- Implements client RemoteEvents from table
function CliApi.implementREvents(tbl: any)
    for _, eventName in pairs(Network.serverEvents) do
        local cliMethod = tbl[eventName]
        if (not cliMethod) then
			warn(`missing client RE implementation for '{eventName}'`); continue
        end

		local remEvent = netObjFolder:WaitForChild(eventName)
        remEvent.OnClientEvent:Connect(function(...)  
            cliMethod(...)
        end)
    end
end

-- Implements client FastRemoteEvents from table
function CliApi.implementFastREvents(tbl: any)
    for _, eventName in pairs(Network.serverFastEvents) do
        local cliMethod = tbl[eventName]
        if (not cliMethod) then
			warn(`missing client FastRE implementation for '{eventName}'`); continue
        end

        local fastRemEvent = netObjFolder:WaitForChild(eventName)
        fastRemEvent.OnClientEvent:Connect(function(...)  
            cliMethod(...)
        end)
    end
end


return CliApi