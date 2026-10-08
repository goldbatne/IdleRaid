local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateSyncService = {}
local snapshotProvider
local updatedRemote: RemoteEvent?
local started = false
local lastRequestAt = {}
local revisions = {}
local initialSent = {}

local function send(player: Player, kind: string, notification)
	if not updatedRemote or not snapshotProvider or player.Parent ~= Players then return end
	local snapshot = snapshotProvider(player, kind)
	if not snapshot then return end
	local revision = (revisions[player] or 0) + 1
	revisions[player] = revision
	snapshot.StateRevision = revision
	if kind == "Growth" then snapshot._Partial = true end
	if kind == "Full" then initialSent[player] = true end
	updatedRemote:FireClient(player, snapshot, notification)
end

function StateSyncService.Push(player: Player, notification)
	send(player, "Full", notification)
end

function StateSyncService.PushGrowth(player: Player, notification)
	if not initialSent[player] then send(player, "Full", notification)
	else send(player, "Growth", notification) end
end

function StateSyncService.Start(provider)
	if started then return end
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
		if now - (lastRequestAt[player] or -math.huge) < 1 then return end
		lastRequestAt[player] = now
		StateSyncService.Push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequestAt[player] = nil
		revisions[player] = nil
		initialSent[player] = nil
	end)
end

return StateSyncService
