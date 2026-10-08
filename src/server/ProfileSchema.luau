local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage.Shared
local GrowthConfig = require(shared.GrowthConfig)
local GrowthMath = require(shared.GrowthMath)
local SafeInteger = require(shared.SafeInteger)
local ItemConfig = require(shared.ItemConfig)

local ProfileSchema = {}
local slots = { "Weapon", "Armor", "Accessory" }

local function copyCounts(raw, keys): ({ [string]: number }?, string?)
	if raw == nil then raw = {} end
	if typeof(raw) ~= "table" then return nil, "InvalidCounts" end
	local result = {}
	for _, key in ipairs(keys) do
		local value = raw[key] or 0
		if not SafeInteger.IsValid(value) then return nil, "InvalidCount_" .. key end
		result[key] = value
	end
	return result, nil
end

local function inventory(raw): ({ [string]: number }?, string?)
	if raw == nil then return {}, nil end
	if typeof(raw) ~= "table" then return nil, "InvalidInventory" end
	local result = {}
	for key, entry in pairs(raw) do
		local itemId, quantity
		if typeof(key) == "number" and typeof(entry) == "table" then
			itemId, quantity = entry.ItemId, entry.Quantity
		else
			itemId, quantity = key, entry
		end
		if typeof(itemId) ~= "string" or not ItemConfig.Items[itemId]
			or not SafeInteger.IsValid(quantity) or quantity < 1 then return nil, "InvalidInventoryEntry" end
		local nextQuantity = SafeInteger.Add(result[itemId] or 0, quantity)
		if not nextQuantity then return nil, "InventoryOverflow" end
		result[itemId] = nextQuantity
	end
	return result, nil
end

local function equipment(raw, owned): ({ [string]: string }?, string?)
	if raw == nil then return {}, nil end
	if typeof(raw) ~= "table" then return nil, "InvalidEquipment" end
	local result = {}
	for _, slot in ipairs(slots) do
		local itemId = raw[slot]
		if itemId ~= nil then
			local definition = typeof(itemId) == "string" and ItemConfig.Items[itemId]
			if not definition or definition.Type ~= slot or not owned[itemId] then
				return nil, "InvalidEquipment_" .. slot
			end
			result[slot] = itemId
		end
	end
	return result, nil
end

local function gates(raw): ({ [string]: boolean }?, string?)
	if raw == nil then return {}, nil end
	if typeof(raw) ~= "table" then return nil, "InvalidGates" end
	local result = {}
	for _, gate in ipairs(GrowthConfig.Gates) do
		local value = raw[gate.Id]
		if value ~= nil and typeof(value) ~= "boolean" then return nil, "InvalidGate_" .. gate.Id end
		if value == true then result[gate.Id] = true end
	end
	return result, nil
end

local function receipts(raw): ({ [string]: string }?, string?)
	if raw == nil then return {}, nil end
	if typeof(raw) ~= "table" then return nil, "InvalidReceipts" end
	local result = {}
	for purchaseId, productKey in pairs(raw) do
		if typeof(purchaseId) ~= "string" or #purchaseId < 1 or #purchaseId > 128
			or typeof(productKey) ~= "string" or #productKey > 64 then return nil, "InvalidReceipt" end
		result[purchaseId] = productKey
	end
	return result, nil
end

function ProfileSchema.New(now: number)
	return {
		DataVersion = GrowthConfig.DataVersion,
		StateRevision = 0,
		AvailableTrainingPower = 0,
		LifetimeTrainingPower = 0,
		BreakthroughStage = 1,
		TrainingFacilityTier = 1,
		TrainingEnabled = true,
		ClearedRaidGates = {},
		Gold = 0,
		RaidToken = 0,
		Inventory = {},
		Equipment = {},
		BreakthroughTickets = { ["2"] = 0, ["3"] = 0, ["5"] = 0 },
		TrainingVouchers = { Minutes10 = 0, Minutes30 = 0, Minutes120 = 0 },
		ProcessedPurchases = {},
		LastSettlementUnix = now,
		OfflineRateSnapshot = GrowthMath.BaseRate(1, 1),
		TrainingRemainderMillis = 0,
	}
end

function ProfileSchema.Migrate(raw: any, now: number): (any, string?)
	if not SafeInteger.IsValid(now) then return nil, "InvalidServerTime" end
	if raw == nil then return ProfileSchema.New(now), nil end
	if typeof(raw) ~= "table" then return nil, "CorruptProfile" end
	local version = raw.DataVersion or 1
	if not SafeInteger.IsValid(version) or version > GrowthConfig.DataVersion or version < 1 then
		return nil, "UnsupportedDataVersion"
	end
	local profile = ProfileSchema.New(now)
	local owned, errorText = inventory(raw.Inventory)
	if not owned then return nil, errorText end
	profile.Inventory = owned
	local equipped
	equipped, errorText = equipment(raw.Equipment, owned)
	if not equipped then return nil, errorText end
	profile.Equipment = equipped
	for _, key in ipairs({ "Gold", "RaidToken" }) do
		local value = raw[key] or 0
		if not SafeInteger.IsValid(value) then return nil, "Invalid" .. key end
		profile[key] = value
	end
	local tickets
	tickets, errorText = copyCounts(raw.BreakthroughTickets, { "2", "3", "5" })
	if not tickets then return nil, errorText end
	profile.BreakthroughTickets = tickets
	local vouchers
	vouchers, errorText = copyCounts(raw.TrainingVouchers, { "Minutes10", "Minutes30", "Minutes120" })
	if not vouchers then return nil, errorText end
	profile.TrainingVouchers = vouchers
	local purchases
	purchases, errorText = receipts(raw.ProcessedPurchases)
	if not purchases then return nil, errorText end
	profile.ProcessedPurchases = purchases
	if version == 1 then
		local oldLevel = raw.Level or 1
		local oldExp = raw.Exp or 0
		local oldRequired = 100 + (oldLevel - 1) * 50
		if not SafeInteger.IsValid(oldLevel) or oldLevel < 1 or oldLevel > GrowthConfig.MaxLevel
			or not SafeInteger.IsValid(oldExp) or oldExp >= oldRequired then return nil, "InvalidLegacyLevel" end
		profile.LifetimeTrainingPower = GrowthMath.LifetimeForLevel(oldLevel, oldExp, oldRequired)
		profile.Migration = { FromVersion = 1, At = now }
		return profile, nil
	end
	for _, key in ipairs({ "AvailableTrainingPower", "LifetimeTrainingPower", "BreakthroughStage",
		"TrainingFacilityTier", "StateRevision", "LastSettlementUnix", "OfflineRateSnapshot", "TrainingRemainderMillis" }) do
		local value = raw[key]
		if not SafeInteger.IsValid(value) then return nil, "Invalid" .. key end
		profile[key] = value
	end
	if profile.AvailableTrainingPower > profile.LifetimeTrainingPower
		or profile.BreakthroughStage < 1 or profile.BreakthroughStage > GrowthConfig.MaxStage
		or not GrowthConfig.Facilities[profile.TrainingFacilityTier]
		or profile.TrainingRemainderMillis >= 1000 then return nil, "InvalidGrowthState" end
	if typeof(raw.TrainingEnabled) ~= "boolean" then return nil, "InvalidTrainingEnabled" end
	profile.TrainingEnabled = raw.TrainingEnabled
	local cleared
	cleared, errorText = gates(raw.ClearedRaidGates)
	if not cleared then return nil, errorText end
	profile.ClearedRaidGates = cleared
	if raw.Migration ~= nil then profile.Migration = raw.Migration end
	return profile, nil
end

return ProfileSchema
