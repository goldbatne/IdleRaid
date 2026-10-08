local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateSyncService = {}

local snapshotProvider
local updatedRemote: RemoteEvent?
local started = false
local lastRequestAt = {}

function StateSyncService.Push(player: Player, notification)
	if not updatedRemote or not snapshotProvider or player.Parent ~= Players then
		return
	end
	local snapshot = snapshotProvider(player)
	if snapshot then
		updatedRemote:FireClient(player, snapshot, notification)
	end
end

function StateSyncService.Start(provider)
	if started then
		return
	end
	started = true
	snapshotProvider = provider

	local folder = ReplicatedStorage:FindFirstChild("IdleRaidRemotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "IdleRaidRemotes"
		folder.Parent = ReplicatedStorage
	end

	local updated = Instance.new("RemoteEvent")
	updated.Name = "PlayerStateUpdated"
	updated.Parent = folder
	updatedRemote = updated

	local request = Instance.new("RemoteEvent")
	request.Name = "RequestPlayerState"
	request.Parent = folder
	request.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if now - (lastRequestAt[player] or -math.huge) < 1 then
			return
		end
		lastRequestAt[player] = now
		StateSyncService.Push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
	end)
end

return StateSyncService
