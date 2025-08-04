local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetApiDef = require(ReplicatedStorage.Shared.NetworkApiDef)

local apiObjects = ReplicatedStorage:WaitForChild(NetApiDef.FOLD_NAME)

local CliApi = {}

for _, eventName in pairs(NetApiDef.clientEvents) do
	local obj = apiObjects:WaitForChild(eventName)

	if (not obj:IsA("RemoteEvent")) then
		error(eventName.." is not a RemoteEvent")
	end
	CliApi[eventName] = function(...)
		obj:FireServer(...)
	end
end

for _, eventName in pairs(NetApiDef.clientFastEvents) do
	local obj = apiObjects:WaitForChild(eventName)

	if (not obj:IsA("UnreliableRemoteEvent")) then
		error(eventName.." is not a UnreliableRemoteEvent")
	end
	CliApi[eventName] = function(...)
		obj:FireServer(...)
	end
end


for _, remFuncName in pairs(NetApiDef.remoteFunctions) do
	local obj = apiObjects:WaitForChild(remFuncName)

	if (not obj:IsA("RemoteFunction")) then
		error(remFuncName.." is not a RemoteFunction")
	end

	CliApi[remFuncName] = function(...)
		return obj:FireServer(...)
	end
end

return CliApi