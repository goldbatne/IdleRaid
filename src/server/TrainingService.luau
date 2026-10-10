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
local capWarned = {}
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
	local room = SafeInteger.PowerRoom(profile.AvailableTrainingPower, profile.LifetimeTrainingPower)
	if not room then return false end
	if room == 0 then
		profile.TrainingRemainderMillis = 0
		if not capWarned[player] then
			capWarned[player] = true
			warn("[IdleRaid] Online training capped at " .. tostring(os.time()) .. " for " .. player.Name)
		end
		return true
	end
	capWarned[player] = nil
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
		if gained >= room - grant then
			grant = room
			remainder = 0
			remaining = 0
			break
		end
		grant += gained
		remainder = total % 1000
		remaining -= chunk
	end
	if grant > 0 and not PlayerDataService.AddPowerFinal(player, grant, "OnlineTraining") then return false end
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

function TrainingService.ResetClock(player: Player)
	lastAt[player] = os.clock()
end

function TrainingService.Start()
	ProfileStore.SetBeforeSave(TrainingService.Settle)
	Players.PlayerRemoving:Connect(function(player) lastAt[player] = nil capWarned[player] = nil end)
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
