local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GrowthConfig = require(ReplicatedStorage.Shared.GrowthConfig)
local GrowthMath = require(ReplicatedStorage.Shared.GrowthMath)
local SafeInteger = require(ReplicatedStorage.Shared.SafeInteger)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProfileStore = require(script.Parent.ProfileStore)
local StateSyncService = require(script.Parent.StateSyncService)

local TrainingService = {}
local lastAt = {}
local MAX_CHUNK_MILLIS = 60000

function TrainingService.Settle(player: Player): boolean
	local now = os.clock()
	local profile = ProfileStore.Get(player)
	if not profile then lastAt[player] = nil return false end
	local previous = lastAt[player]
	if not previous then lastAt[player] = now return true end
	local millis = math.floor((now - previous) * 1000)
	if millis <= 0 then return true end
	lastAt[player] = previous + millis / 1000
	if not profile.TrainingEnabled then return true end
	local rate = GrowthMath.BaseRate(profile.BreakthroughStage, profile.TrainingFacilityTier)
	if not rate then return false end
	local remaining = millis
	local remainder = profile.TrainingRemainderMillis
	local grant = 0
	while remaining > 0 do
		local chunk = math.min(remaining, MAX_CHUNK_MILLIS)
		local numerator = SafeInteger.Multiply(rate, chunk)
		if not numerator then return false end
		local total = SafeInteger.Add(numerator, remainder)
		if not total then return false end
		local gained = math.floor(total / 1000)
		local nextGrant = SafeInteger.Add(grant, gained)
		if not nextGrant then return false end
		grant = nextGrant
		remainder = total % 1000
		remaining -= chunk
	end
	if grant > 0 and not PlayerDataService.AddPowerFinal(player, grant, "OnlineTraining") then
		warn("[IdleRaid] Training power cap reached for " .. player.Name)
		return false
	end
	profile.TrainingRemainderMillis = remainder
	return true
end

function TrainingService.SetEnabled(player: Player, enabled: any): boolean
	if typeof(enabled) ~= "boolean" then return false end
	local profile = ProfileStore.Get(player)
	if not profile then return false end
	TrainingService.Settle(player)
	if profile.TrainingEnabled == enabled then return true end
	profile.TrainingEnabled = enabled
	ProfileStore.Touch(player)
	StateSyncService.PushGrowth(player)
	return true
end

function TrainingService.Start()
	ProfileStore.SetBeforeSave(TrainingService.Settle)
	Players.PlayerRemoving:Connect(function(player) lastAt[player] = nil end)
	local remote = Instance.new("RemoteEvent")
	remote.Name = "SetTrainingEnabled"
	remote.Parent = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
	remote.OnServerEvent:Connect(function(player, enabled)
		TrainingService.SetEnabled(player, enabled)
	end)
	task.spawn(function()
		while true do
			task.wait(GrowthConfig.OnlineTickSeconds)
			for _, player in ipairs(Players:GetPlayers()) do TrainingService.Settle(player) end
		end
	end)
end

return TrainingService
