local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GrowthConfig = require(game:GetService("ReplicatedStorage").Shared.GrowthConfig)
local GrowthMath = require(game:GetService("ReplicatedStorage").Shared.GrowthMath)
local SafeInteger = require(game:GetService("ReplicatedStorage").Shared.SafeInteger)
local ProfileSchema = require(script.Parent.ProfileSchema)

local ProfileStore = {}
local isMock = RunService:IsStudio()
local store = if isMock then nil else DataStoreService:GetDataStore("IdleRaid_Profile_v2")
local mockRecords = {}
local mockFailures = 0
local entries = {}
local onReady
local beforeSave
local sessionId = (game.JobId ~= "" and game.JobId or "Studio") .. ":" .. HttpService:GenerateGUID(false)
local MAX_JSON_BYTES = 3 * 1024 * 1024

local function clone(value)
	if typeof(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = clone(child) end
	return result
end

local function keyFor(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

local function update(key: string, transformer)
	if isMock then
		if mockFailures > 0 then
			mockFailures -= 1
			error("MockUpdateFailure")
		end
		local old = clone(mockRecords[key])
		local nextRecord = transformer(old)
		if nextRecord ~= nil then mockRecords[key] = clone(nextRecord) end
		return clone(mockRecords[key])
	end
	return store:UpdateAsync(key, transformer)
end

local function tryUpdate(key: string, transformer): (boolean, any)
	local lastError
	for attempt = 1, 3 do
		local ok, result = pcall(update, key, transformer)
		if ok then return true, result end
		lastError = result
		if attempt < 3 then task.wait(0.35 * attempt) end
	end
	return false, lastError
end

local function offlineSettle(profile, now: number)
	local elapsed = math.max(0, now - profile.LastSettlementUnix)
	local accepted = math.min(elapsed, GrowthConfig.OfflineMaxSeconds)
	local oldLifetime = profile.LifetimeTrainingPower
	local oldRate = profile.OfflineRateSnapshot
	local grant = SafeInteger.MultiplyRatioFloor(profile.OfflineRateSnapshot,
		accepted * GrowthConfig.OfflineRateNumerator, GrowthConfig.OfflineRateDenominator)
	if not grant then return nil, "OfflineOverflow" end
	local available = SafeInteger.Add(profile.AvailableTrainingPower, grant)
	local lifetime = SafeInteger.Add(profile.LifetimeTrainingPower, grant)
	if not available or not lifetime then return nil, "PowerCap" end
	profile.AvailableTrainingPower = available
	profile.LifetimeTrainingPower = lifetime
	profile.LastSettlementUnix = now
	profile.OfflineRateSnapshot = GrowthMath.BaseRate(profile.BreakthroughStage, profile.TrainingFacilityTier)
	if grant > 0 then profile.StateRevision += 1 end
	local beforeLevel = GrowthMath.LevelProgress(oldLifetime)
	local afterLevel = GrowthMath.LevelProgress(lifetime)
	return {
		ElapsedSeconds = elapsed,
		AcceptedSeconds = accepted,
		Rate = oldRate,
		EfficiencyNumerator = GrowthConfig.OfflineRateNumerator,
		EfficiencyDenominator = GrowthConfig.OfflineRateDenominator,
		GrantedPower = grant,
		LevelBefore = beforeLevel,
		LevelAfter = afterLevel,
	}, nil
end

local function load(player: Player)
	local entry = { Status = "Loading", Saving = false }
	entries[player] = entry
	local now = os.time()
	local failure
	local offlineSummary
	local ok, record = tryUpdate(keyFor(player), function(raw)
		local lock = raw and raw._Session
		if lock and lock.Owner ~= sessionId and SafeInteger.IsValid(lock.ExpiresAt) and lock.ExpiresAt > now then
			failure = "SessionLocked"
			return nil
		end
		local profile, reason = ProfileSchema.Migrate(raw, now)
		if not profile then failure = reason return nil end
		local summary, settleReason = offlineSettle(profile, now)
		if not summary then failure = settleReason return nil end
		offlineSummary = summary
		profile._Session = { Owner = sessionId, ExpiresAt = now + GrowthConfig.SessionLeaseSeconds }
		return profile
	end)
	if entries[player] ~= entry or player.Parent ~= Players then return end
	if not ok or not record or not record._Session or record._Session.Owner ~= sessionId then
		entry.Status = failure or "LoadFailed"
		warn(string.format("[IdleRaid] Profile load blocked for %s: %s", player.Name, entry.Status))
		if onReady then onReady(player, false) end
		return
	end
	record._Session = nil
	entry.Profile = record
	entry.Status = "Ready"
	entry.OfflineSummary = offlineSummary
	entry.SavedRevision = record.StateRevision
	if onReady then onReady(player, true) end
end

function ProfileStore.Get(player: Player)
	local entry = entries[player]
	return if entry and entry.Status == "Ready" then entry.Profile else nil
end

function ProfileStore.GetStatus(player: Player): string
	local entry = entries[player]
	return if entry then entry.Status else "Loading"
end

function ProfileStore.GetOfflineSummary(player: Player)
	local entry = entries[player]
	return entry and entry.OfflineSummary or nil
end

function ProfileStore.SetReceiptPending(player: Player, pending: boolean)
	local entry = entries[player]
	if entry and entry.Status == "Ready" then entry.ReceiptPending = pending end
end

function ProfileStore.IsReceiptPending(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.ReceiptPending == true
end

function ProfileStore.Touch(player: Player): boolean
	local profile = ProfileStore.Get(player)
	if not profile then return false end
	profile.StateRevision += 1
	return true
end

function ProfileStore.SetBeforeSave(callback)
	beforeSave = callback
end

function ProfileStore.Save(player: Player, release: boolean?): (boolean, string?)
	local entry = entries[player]
	if not entry or entry.Status ~= "Ready" then return false, "ProfileNotReady" end
	local deadline = os.clock() + 10
	while entry.Saving do
		if os.clock() > deadline then return false, "SaveBusy" end
		task.wait(0.05)
	end
	entry.Saving = true
	if beforeSave then
		local settled, errorText = pcall(beforeSave, player)
		if not settled then
			entry.Saving = false
			warn(string.format("[IdleRaid] Profile settlement failed for %s: %s", player.Name, tostring(errorText)))
			return false, "SettlementFailed"
		end
	end
	local profile = entry.Profile
	profile.LastSettlementUnix = os.time()
	profile.OfflineRateSnapshot = GrowthMath.BaseRate(profile.BreakthroughStage, profile.TrainingFacilityTier)
	local snapshot = clone(profile)
	local savedRevision = snapshot.StateRevision
	local failure
	local ok, record = tryUpdate(keyFor(player), function(raw)
		if not raw or not raw._Session or raw._Session.Owner ~= sessionId then
			failure = "SessionLost"
			return nil
		end
		if (raw.StateRevision or 0) > savedRevision then
			failure = "StaleSnapshot"
			return nil
		end
		local nextRecord = clone(snapshot)
		if not release then
			nextRecord._Session = { Owner = sessionId, ExpiresAt = os.time() + GrowthConfig.SessionLeaseSeconds }
		end
		if #HttpService:JSONEncode(nextRecord) > MAX_JSON_BYTES then
			failure = "ProfileTooLarge"
			return nil
		end
		return nextRecord
	end)
	entry.Saving = false
	if not ok or not record or failure or (not release and (not record._Session or record._Session.Owner ~= sessionId)) then
		if failure == "SessionLost" then entry.Status = "SessionLost" end
		warn(string.format("[IdleRaid] Profile save failed for %s: %s", player.Name, tostring(failure or record)))
		return false, failure or "SaveFailed"
	end
	entry.SavedRevision = savedRevision
	if release then entries[player] = nil end
	return true, nil
end

function ProfileStore.SaveReceipt(player: Player, purchaseId: string): (boolean, string?)
	local profile = ProfileStore.Get(player)
	if not profile or not profile.ProcessedPurchases[purchaseId] then return false, "ReceiptNotGranted" end
	local ok, reason = ProfileStore.Save(player)
	if not ok then return false, reason end
	local entry = entries[player]
	if entry and entry.SavedRevision < profile.StateRevision then
		return ProfileStore.Save(player)
	end
	return true, nil
end

function ProfileStore.Start(callback)
	onReady = callback
	Players.PlayerAdded:Connect(function(player) task.spawn(load, player) end)
	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		if entry and entry.Status == "Ready" then
			local saved = false
			for attempt = 1, 3 do
				saved = ProfileStore.Save(player, true)
				if saved or entry.Status ~= "Ready" then break end
				if attempt < 3 then task.wait(attempt * 2) end
			end
			if not saved then warn("[IdleRaid] Final profile save failed for " .. player.Name) end
		end
		entries[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do task.spawn(load, player) end
	task.spawn(function()
		while true do
			task.wait(GrowthConfig.AutosaveSeconds)
			for player, entry in pairs(entries) do
				if player.Parent == Players and entry.Status == "Ready" then
					task.spawn(ProfileStore.Save, player)
				end
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player, entry in pairs(entries) do
			if entry.Status == "Ready" then
				pending += 1
				task.spawn(function()
					local saved = ProfileStore.Save(player, true)
					if not saved then warn("[IdleRaid] Shutdown profile save failed for " .. player.Name) end
					pending -= 1
				end)
			end
		end
		local deadline = os.clock() + 25
		while pending > 0 and os.clock() < deadline do task.wait(0.1) end
		if pending > 0 then warn("[IdleRaid] Shutdown timed out with pending profile saves") end
	end)
end

if isMock then
	function ProfileStore.TestOfflineSettle(profile, now: number)
		return offlineSettle(profile, now)
	end
	function ProfileStore.TestFailNextUpdates(count: number)
		assert(SafeInteger.IsValid(count) and count <= 10)
		mockFailures = count
	end
	function ProfileStore.TestSetMock(userId: number, raw)
		mockRecords["Player_" .. tostring(userId)] = clone(raw)
	end
	function ProfileStore.TestGetMock(userId: number)
		return clone(mockRecords["Player_" .. tostring(userId)])
	end
end

return ProfileStore
