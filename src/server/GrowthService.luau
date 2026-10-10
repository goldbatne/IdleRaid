local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GrowthConfig = require(ReplicatedStorage.Shared.GrowthConfig)
local GrowthMath = require(ReplicatedStorage.Shared.GrowthMath)
local SafeInteger = require(ReplicatedStorage.Shared.SafeInteger)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProfileStore = require(script.Parent.ProfileStore)
local TrainingService = require(script.Parent.TrainingService)
local StateSyncService = require(script.Parent.StateSyncService)

local GrowthService = {}
local raidBusyCheck = function(_player) return false end
local busy = {}
local requestCache = {}
local lastRemoteAt = {}

local function failed(reason: string, extra)
	return { Ok = false, Reason = reason, Preview = extra }
end

local function validRequestId(value: any): boolean
	return typeof(value) == "string" and #value >= 8 and #value <= 64
end

local function inRaid(player: Player): boolean
	return raidBusyCheck(player)
end

function GrowthService.SetRaidBusyCheck(callback)
	raidBusyCheck = callback
end

function GrowthService.PreviewBreakthrough(player: Player, steps: any)
	local profile = ProfileStore.Get(player)
	if not profile then return failed("ProfileNotReady") end
	if not SafeInteger.IsValid(steps) or (steps ~= 1 and steps ~= 2 and steps ~= 3 and steps ~= 5) then
		return failed("InvalidStep")
	end
	local stage = profile.BreakthroughStage
	local allowed, gateReason = GrowthMath.CanAdvance(stage, steps, profile.ClearedRaidGates)
	local cost = if stage < GrowthConfig.MaxStage then GrowthMath.BreakthroughCost(stage) else 0
	local reason = if ProfileStore.IsReceiptPending(player) then "ReceiptSaving"
		elseif inRaid(player) then "RaidInProgress" elseif not allowed then gateReason
		elseif steps > 1 and (profile.BreakthroughTickets[tostring(steps)] or 0) < 1 then "NoTicket"
		elseif profile.AvailableTrainingPower < cost then "InsufficientPower" else nil
	return {
		Ok = reason == nil,
		Reason = reason,
		Stage = stage,
		TargetStage = if allowed then stage + steps else nil,
		Cost = cost,
		AvailablePower = profile.AvailableTrainingPower,
		Tickets = if steps > 1 then profile.BreakthroughTickets[tostring(steps)] or 0 else nil,
		CurrentMultiplier = GrowthMath.StageMultiplier(stage),
		TargetMultiplier = if allowed then GrowthMath.StageMultiplier(stage + steps) else nil,
		CurrentRate = GrowthMath.BaseRate(stage, profile.TrainingFacilityTier),
		TargetRate = if allowed then GrowthMath.BaseRate(stage + steps, profile.TrainingFacilityTier) else nil,
		NextGate = GrowthMath.NextGate(stage, profile.ClearedRaidGates),
	}
end

function GrowthService.TryBreakthrough(player: Player, steps: any, expectedStage: any)
	local profile = ProfileStore.Get(player)
	if not profile then return failed("ProfileNotReady") end
	if not SafeInteger.IsValid(expectedStage) or profile.BreakthroughStage ~= expectedStage then
		return failed("StalePreview", GrowthService.PreviewBreakthrough(player, steps))
	end
	if ProfileStore.IsReceiptPending(player) then return failed("ReceiptSaving") end
	if inRaid(player) then return failed("RaidInProgress") end
	TrainingService.Settle(player)
	local preview = GrowthService.PreviewBreakthrough(player, steps)
	if not preview.Ok then return failed(preview.Reason, preview) end
	local cost = preview.Cost
	local remaining = SafeInteger.Subtract(profile.AvailableTrainingPower, cost)
	if not remaining then return failed("InsufficientPower", preview) end
	local key = tostring(steps)
	if steps > 1 then
		if profile.BreakthroughTickets[key] < 1 then return failed("NoTicket", preview) end
		profile.BreakthroughTickets[key] -= 1
	end
	profile.AvailableTrainingPower = remaining
	profile.BreakthroughStage += steps
	PlayerDataService.AfterGrowthChange(player, nil, {
		Kind = "Breakthrough", Steps = steps, From = preview.Stage,
		To = profile.BreakthroughStage, BeforeRate = preview.CurrentRate,
		AfterRate = preview.TargetRate, Cost = cost,
	})
	return { Ok = true, Stage = profile.BreakthroughStage, Cost = cost }
end

function GrowthService.TryUpgradeFacility(player: Player, expectedTier: any)
	local profile = ProfileStore.Get(player)
	if not profile then return failed("ProfileNotReady") end
	if not SafeInteger.IsValid(expectedTier) or expectedTier ~= profile.TrainingFacilityTier then
		return failed("StalePreview")
	end
	if ProfileStore.IsReceiptPending(player) then return failed("ReceiptSaving") end
	if inRaid(player) then return failed("RaidInProgress") end
	local beforeRate = GrowthMath.BaseRate(profile.BreakthroughStage, profile.TrainingFacilityTier)
	local nextFacility = GrowthConfig.Facilities[profile.TrainingFacilityTier + 1]
	if not nextFacility then return failed("MaxFacility") end
	if nextFacility.RequiredGate and not profile.ClearedRaidGates[nextFacility.RequiredGate] then
		return failed("GateRequired")
	end
	TrainingService.Settle(player)
	if profile.Gold < nextFacility.GoldCost then return failed("InsufficientGold") end
	profile.Gold -= nextFacility.GoldCost
	profile.TrainingFacilityTier += 1
	PlayerDataService.AfterGrowthChange(player, nil, {
		Kind = "Facility", Tier = profile.TrainingFacilityTier,
		BeforeRate = beforeRate,
		AfterRate = GrowthMath.BaseRate(profile.BreakthroughStage, profile.TrainingFacilityTier),
		GoldSpent = nextFacility.GoldCost,
	})
	return { Ok = true, Tier = profile.TrainingFacilityTier }
end

function GrowthService.PreviewVoucher(player: Player, voucherId: any)
	local profile = ProfileStore.Get(player)
	if not profile then return failed("ProfileNotReady") end
	if typeof(voucherId) ~= "string" then return failed("InvalidVoucher") end
	local voucher = GrowthConfig.Vouchers[voucherId]
	if not voucher then return failed("InvalidVoucher") end
	local rate = GrowthMath.BaseRate(profile.BreakthroughStage, profile.TrainingFacilityTier)
	local grant = SafeInteger.Multiply(rate, voucher.Seconds)
	local room = SafeInteger.PowerRoom(profile.AvailableTrainingPower, profile.LifetimeTrainingPower)
	if not grant or not room or grant > room then return failed("PowerCap") end
	return {
		Ok = (profile.TrainingVouchers[voucherId] or 0) > 0 and not inRaid(player),
		Reason = if inRaid(player) then "RaidInProgress"
			elseif (profile.TrainingVouchers[voucherId] or 0) < 1 then "NoVoucher" else nil,
		VoucherId = voucherId, Count = profile.TrainingVouchers[voucherId] or 0,
		Rate = rate, Grant = grant, Stage = profile.BreakthroughStage,
		FacilityTier = profile.TrainingFacilityTier,
	}
end

function GrowthService.TryUseVoucher(player: Player, voucherId: any, expectedRate: any, expectedCount: any)
	local profile = ProfileStore.Get(player)
	if not profile then return failed("ProfileNotReady") end
	if ProfileStore.IsReceiptPending(player) then return failed("ReceiptSaving") end
	if inRaid(player) then return failed("RaidInProgress") end
	TrainingService.Settle(player)
	local preview = GrowthService.PreviewVoucher(player, voucherId)
	if preview.Reason == "PowerCap" then return failed("PowerCap") end
	if expectedRate ~= preview.Rate or expectedCount ~= preview.Count then
		return failed("StalePreview", preview)
	end
	if not preview.Ok then return failed(preview.Reason, preview) end
	local available = SafeInteger.Add(profile.AvailableTrainingPower, preview.Grant)
	local lifetime = SafeInteger.Add(profile.LifetimeTrainingPower, preview.Grant)
	if not available or not lifetime then return failed("PowerCap", preview) end
	local oldLifetime = profile.LifetimeTrainingPower
	profile.TrainingVouchers[voucherId] -= 1
	profile.AvailableTrainingPower = available
	profile.LifetimeTrainingPower = lifetime
	PlayerDataService.AfterGrowthChange(player, oldLifetime, { Kind = "Voucher", Amount = preview.Grant })
	return { Ok = true, GrantedPower = preview.Grant }
end

function GrowthService.TryExchangeTicket(player: Player, steps: any, expectedTokens: any, expectedCount: any)
	local profile = ProfileStore.Get(player)
	if not profile then return failed("ProfileNotReady") end
	if ProfileStore.IsReceiptPending(player) then return failed("ReceiptSaving") end
	if inRaid(player) then return failed("RaidInProgress") end
	if not SafeInteger.IsValid(steps) or not GrowthConfig.TokenTicketCost[steps] then return failed("InvalidStep") end
	local key = tostring(steps)
	if expectedTokens ~= profile.RaidToken or expectedCount ~= profile.BreakthroughTickets[key] then
		return failed("StalePreview")
	end
	local cost = GrowthConfig.TokenTicketCost[steps]
	if profile.RaidToken < cost then return failed("InsufficientToken") end
	local nextCount = SafeInteger.Add(profile.BreakthroughTickets[key], 1)
	if not nextCount then return failed("TicketCap") end
	profile.RaidToken -= cost
	profile.BreakthroughTickets[key] = nextCount
	PlayerDataService.AfterGrowthChange(player, nil, { Kind = "TokenExchange", Steps = steps })
	return { Ok = true, TokensSpent = cost, Tickets = nextCount }
end

function GrowthService.GrantOwnership(player: Player, kind: string, value: any, count: number): boolean
	local profile = ProfileStore.Get(player)
	if not profile or not SafeInteger.IsValid(count) or count < 1 then return false end
	local bucket, key
	if kind == "Ticket" and SafeInteger.IsValid(value) and GrowthConfig.TokenTicketCost[value] then
		bucket, key = profile.BreakthroughTickets, tostring(value)
	elseif kind == "Voucher" and typeof(value) == "string" and GrowthConfig.Vouchers[value] then
		bucket, key = profile.TrainingVouchers, value
	else return false end
	local nextCount = SafeInteger.Add(bucket[key] or 0, count)
	if not nextCount then return false end
	bucket[key] = nextCount
	PlayerDataService.AfterGrowthChange(player, nil, { Kind = "Ownership", Item = key, Count = count })
	return true
end

function GrowthService.CanClearGate(player: Player, gateId: string): boolean
	local profile = ProfileStore.Get(player)
	if not profile then return false end
	for _, gate in ipairs(GrowthConfig.Gates) do
		if gate.Id == gateId then
			if profile.BreakthroughStage < gate.Stage then return false end
			return true
		end
		if not profile.ClearedRaidGates[gate.Id] then return false end
	end
	return false
end

function GrowthService.RecordGateClear(player: Player, gateId: string): boolean
	local profile = ProfileStore.Get(player)
	if not profile or profile.ClearedRaidGates[gateId] or not GrowthService.CanClearGate(player, gateId) then
		return false
	end
	profile.ClearedRaidGates[gateId] = true
	PlayerDataService.AfterGrowthChange(player, nil, { Kind = "GateClear", GateId = gateId })
	return true
end

local function callAction(player: Player, action: any, payload: any)
	if typeof(action) ~= "string" or typeof(payload) ~= "table" then return failed("InvalidRequest") end
	if action == "PreviewBreakthrough" then return GrowthService.PreviewBreakthrough(player, payload.Steps) end
	if action == "PreviewVoucher" then return GrowthService.PreviewVoucher(player, payload.VoucherId) end
	local requestId = payload.RequestId
	if not validRequestId(requestId) then return failed("InvalidRequestId") end
	local cache = requestCache[player]
	if not cache then cache = { Results = {}, Order = {} } requestCache[player] = cache end
	local previous = cache.Results[requestId]
	if previous then return if previous.Action == action then previous.Result else failed("RequestIdReused") end
	if busy[player] then return failed("Busy") end
	busy[player] = true
	local ok, result = pcall(function()
		if action == "Breakthrough" then return GrowthService.TryBreakthrough(player, payload.Steps, payload.ExpectedStage)
		elseif action == "UpgradeFacility" then return GrowthService.TryUpgradeFacility(player, payload.ExpectedTier)
		elseif action == "UseVoucher" then return GrowthService.TryUseVoucher(player, payload.VoucherId, payload.ExpectedRate, payload.ExpectedCount)
		elseif action == "ExchangeTicket" then return GrowthService.TryExchangeTicket(player, payload.Steps, payload.ExpectedTokens, payload.ExpectedCount)
		else return failed("UnknownAction") end
	end)
	busy[player] = nil
	if not ok then
		warn("[IdleRaid] Growth request failed: " .. tostring(result))
		return failed("ServerError")
	end
	cache.Results[requestId] = { Action = action, Result = result }
	table.insert(cache.Order, requestId)
	if #cache.Order > 128 then cache.Results[table.remove(cache.Order, 1)] = nil end
	return result
end

local function handleRemote(player, action, payload)
	if typeof(payload) == "table" and typeof(payload.RequestId) == "string" then
		local cache = requestCache[player]
		local previous = cache and cache.Results[payload.RequestId]
		if previous then return if previous.Action == action then previous.Result else failed("RequestIdReused") end
	end
	local now = os.clock()
	if now - (lastRemoteAt[player] or -math.huge) < 0.05 then return failed("RateLimited") end
	lastRemoteAt[player] = now
	return callAction(player, action, payload)
end

function GrowthService.Start()
	local folder = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
	local remote = Instance.new("RemoteFunction")
	remote.Name = "GrowthAction"
	remote.Parent = folder
	remote.OnServerInvoke = handleRemote
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
		requestCache[player] = nil
		lastRemoteAt[player] = nil
	end)
	if RunService:IsStudio() then
		GrowthService.TestHandleRemote = handleRemote
		local debugGrant = Instance.new("RemoteFunction")
		debugGrant.Name = "StudioGrowthGrant"
		debugGrant.Parent = folder
		debugGrant.OnServerInvoke = function(player, kind, value)
			if not ProfileStore.IsStudioSandbox(player) then return false end
			if kind == "Power" and SafeInteger.IsValid(value) and value > 0 then
				return PlayerDataService.AddPowerFinal(player, value, "StudioTest")
			elseif kind == "Gold" and SafeInteger.IsValid(value) and value > 0 then
				return PlayerDataService.AddGold(player, value)
			elseif kind == "Ticket" then
				return GrowthService.GrantOwnership(player, "Ticket", value, 1)
			elseif kind == "Voucher" then
				return GrowthService.GrantOwnership(player, "Voucher", value, 1)
			end
			return false
		end
	end
end

return GrowthService
