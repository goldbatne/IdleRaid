local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StateController = {}
local changed = Instance.new("BindableEvent")
local notificationReceived = Instance.new("BindableEvent")
local currentState
local offlineShown = false

function StateController.Subscribe(callback)
	local connection = changed.Event:Connect(callback)
	if currentState then callback(currentState) end
	return connection
end

function StateController.OnNotification(callback)
	return notificationReceived.Event:Connect(callback)
end

function StateController.GetSnapshot()
	return currentState
end

function StateController.ApplySnapshot(snapshot, notification): boolean
	if typeof(snapshot) ~= "table" or typeof(snapshot.StateRevision) ~= "number" then return false end
	if currentState and snapshot.StateRevision <= (currentState.StateRevision or -1) then return false end
	if snapshot._Partial and currentState then
		if typeof(snapshot._ClearKeys) == "table" then
			for _, key in ipairs(snapshot._ClearKeys) do
				if typeof(key) == "string" and key ~= "StateRevision" then currentState[key] = nil end
			end
		end
		for key, value in pairs(snapshot) do
			if key ~= "_Partial" and key ~= "_ClearKeys" then currentState[key] = value end
		end
	else
		currentState = snapshot
	end
	changed:Fire(currentState)
	if not offlineShown and currentState.Ready and typeof(currentState.OfflineSummary) == "table" then
		offlineShown = true
		notificationReceived:Fire({ Kind = "Offline", Summary = currentState.OfflineSummary })
	end
	if typeof(notification) == "table" then notificationReceived:Fire(notification) end
	return true
end

function StateController.Start()
	local remotes = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
	remotes:WaitForChild("PlayerStateUpdated").OnClientEvent:Connect(StateController.ApplySnapshot)
	remotes:WaitForChild("RequestPlayerState"):FireServer()
end

return StateController
