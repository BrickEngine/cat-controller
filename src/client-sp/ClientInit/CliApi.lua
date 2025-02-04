local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NetApi = require(ReplicatedStorage.Shared.NetworkApi)

local apiObjects = ReplicatedStorage:WaitForChild(NetApi.FOLD_NAME)

local CliApi = {}

for _, eventName in ipairs(NetApi.definitions.clientEvents) do
	local obj = apiObjects:WaitForChild(eventName)

	if (not obj:IsA("RemoteEvent")) then
		error(eventName.." is not a RemoteEvent")
	end
	
	CliApi[eventName] = function(...)
		obj:FireServer(...)
	end
end

for _, remFuncName in ipairs(NetApi.definitions.remoteFunctions) do
	local obj = apiObjects:WaitForChild(remFuncName)

	if (not obj:IsA("RemoteFunction")) then
		error(remFuncName.." is not a RemoteEvent")
	end

	CliApi[remFuncName] = function(...)
		return obj:FireServer(...)
	end
end


return CliApi