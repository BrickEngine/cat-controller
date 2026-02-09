local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Network = require(script.Parent)

local netObjectsContainer = ReplicatedStorage:WaitForChild(Network.CONTAINER_NAME)

local CliApi = {}

for _, eventName in pairs(Network.clientEvents) do
	local obj = netObjectsContainer:WaitForChild(eventName)

	if (not obj:IsA("RemoteEvent")) then
		error(eventName.." is not a RemoteEvent")
	end
	CliApi[eventName] = function(...)
		obj:FireServer(...)
	end
end

for _, eventName in pairs(Network.clientFastEvents) do
	local obj = netObjectsContainer:WaitForChild(eventName)

	if (not obj:IsA("UnreliableRemoteEvent")) then
		error(eventName.." is not a UnreliableRemoteEvent")
	end
	CliApi[eventName] = function(...)
		obj:FireServer(...)
	end
end

return CliApi