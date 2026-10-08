local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateController = {}

local changed = Instance.new("BindableEvent")
local notificationReceived = Instance.new("BindableEvent")
local currentState

function StateController.Subscribe(callback)
	local connection = changed.Event:Connect(callback)
	if currentState then
		callback(currentState)
	end
	return connection
end

function StateController.OnNotification(callback)
	return notificationReceived.Event:Connect(callback)
end

function StateController.Start()
	local remotes = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
	local updated = remotes:WaitForChild("PlayerStateUpdated")
	updated.OnClientEvent:Connect(function(snapshot, notification)
		if typeof(snapshot) ~= "table" then
			return
		end
		currentState = snapshot
		changed:Fire(snapshot)
		if typeof(notification) == "table" then
			notificationReceived:Fire(notification)
		end
	end)
	remotes:WaitForChild("RequestPlayerState"):FireServer()
end

return StateController
