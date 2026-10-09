-- Run against a Rojo-built place with Roblox Studio --task RunScript.
-- The simulator imports the shipped Luau GrowthConfig/GrowthMath; no copied formula.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local config = require(shared.GrowthConfig)
local mathGrowth = require(shared.GrowthMath)
local safe = require(shared.SafeInteger)
local gameConfig = require(shared.GameConfig)
local formatter = require(shared.NumberFormatter)

local function check(name, condition)
	assert(condition, name)
	print("IR_GROWTH_TEST_PASS", name)
end
check("safe_integer_limit", safe.Add(config.MaxSafePower, 1) == nil and safe.Subtract(3, 4) == nil)
check("safe_integer_ratio", safe.MultiplyRatioFloor(120, 3, 2) == 180)
check("display_rounding_boundary", formatter.Format(999995) == "1.00M" and formatter.Format(999994) == "999.99K")
check("display_invalid", formatter.Format(math.huge) == "--" and formatter.Format(-1) == "--")
check("stage_cost_independent_of_facility", mathGrowth.BreakthroughCost(10) == mathGrowth.ReferenceRate(10) * mathGrowth.TargetBaseSeconds(10))
check("voucher_120_per_sec", mathGrowth.BaseRate(1, 1) * 600 == 6000 and 120 * 600 == 72000)
check("gate_7_plus_3", mathGrowth.CanAdvance(7, 3, {}) == true)
check("gate_8_plus_2", mathGrowth.CanAdvance(8, 2, {}) == true)
check("gate_8_plus_5", mathGrowth.CanAdvance(8, 5, {}) == false)
check("gate_9_plus_2", mathGrowth.CanAdvance(9, 2, {}) == false)
check("gate_10_lock", mathGrowth.CanAdvance(10, 1, {}) == false)
check("legacy_stage_above_uncleared_gate_locked", mathGrowth.CanAdvance(11, 1, {}) == false
	and mathGrowth.NextGate(11, {}).Id == "Gate10")
check("gate_10_clear", mathGrowth.CanAdvance(10, 5, { Gate10 = true }) == true)
check("gate_18_plus_2", mathGrowth.CanAdvance(18, 2, { Gate10 = true }) == true)
check("gate_18_plus_5", mathGrowth.CanAdvance(18, 5, { Gate10 = true }) == false)
check("stage_30_cap", mathGrowth.CanAdvance(30, 1, { Gate10 = true, Gate20 = true, Gate30 = true }) == false)

local schema = require(game:GetService("ServerScriptService").Server.ProfileSchema)
local legacy = {
	Level = 3, Exp = 100, Gold = 77, RaidToken = 4,
	Inventory = { TrainingSword = 2 },
	Equipment = { Weapon = "TrainingSword" },
	BreakthroughTickets = { ["2"] = 1 },
	TrainingVouchers = { Minutes10 = 2 },
	ProcessedPurchases = { receipt1 = "Ticket2:v1" },
}
local migrated, migrationError = schema.Migrate(legacy, 1000)
check("legacy_profile_migration", migrated ~= nil and migrationError == nil
	and migrated.DataVersion == config.DataVersion and migrated.Gold == 77 and migrated.RaidToken == 4
	and migrated.Inventory.TrainingSword == 2 and migrated.Equipment.Weapon == "TrainingSword"
	and migrated.BreakthroughTickets["2"] == 1 and migrated.TrainingVouchers.Minutes10 == 2
	and migrated.ProcessedPurchases.receipt1 == "Ticket2:v1"
	and migrated.AvailableTrainingPower == 0 and migrated.BreakthroughStage == 1
	and mathGrowth.LevelProgress(migrated.LifetimeTrainingPower) == 3)
local migratedAgain = schema.Migrate(migrated, 1001)
check("migration_runs_once", migratedAgain and migratedAgain.LifetimeTrainingPower == migrated.LifetimeTrainingPower
	and migratedAgain.AvailableTrainingPower == 0 and migratedAgain.Migration.FromVersion == 1)
check("future_profile_rejected", schema.Migrate({ DataVersion = config.DataVersion + 1 }, 1000) == nil)
check("corrupt_profile_rejected", schema.Migrate({ DataVersion = 1, Gold = -1 }, 1000) == nil)
check("negative_client_input_rejected", not safe.IsValid(-1) and not safe.IsValid(math.huge)
	and not safe.IsValid(1.5) and not safe.IsValid("100"))
local profileStore = require(game:GetService("ServerScriptService").Server.ProfileStore)
local offlineProfile = schema.New(1000)
offlineProfile.BreakthroughStage = 10
offlineProfile.TrainingFacilityTier = 2
offlineProfile.OfflineRateSnapshot = 120
local offlineSummary = profileStore.TestOfflineSettle(offlineProfile, 4600)
check("offline_saved_rate_and_cursor", offlineSummary.GrantedPower == 108000
	and offlineProfile.LifetimeTrainingPower == 108000
	and offlineProfile.OfflineRateSnapshot == mathGrowth.BaseRate(10, 2)
	and offlineProfile.LastSettlementUnix == 4600)
local repeatSummary = profileStore.TestOfflineSettle(offlineProfile, 4600)
check("offline_idempotent", repeatSummary.GrantedPower == 0
	and offlineProfile.LifetimeTrainingPower == 108000)
local futureProfile = schema.New(9000)
futureProfile.LastSettlementUnix = 10000
local futureSummary = profileStore.TestOfflineSettle(futureProfile, 9000)
check("offline_future_time", futureSummary.GrantedPower == 0 and futureProfile.LastSettlementUnix == 9000)
local disabledProfile = schema.New(1000)
disabledProfile.TrainingEnabled = false
disabledProfile.OfflineRateSnapshot = 120
local disabledSummary = profileStore.TestOfflineSettle(disabledProfile, 4600)
check("offline_training_disabled", disabledSummary.GrantedPower == 0
	and disabledSummary.Rate == 0 and disabledProfile.LastSettlementUnix == 4600)

local cappedProfile = schema.New(1000)
cappedProfile.OfflineRateSnapshot = 120
local cappedSummary = profileStore.TestOfflineSettle(cappedProfile, 1000 + 24 * 3600)
check("offline_eight_hour_cap", cappedSummary.AcceptedSeconds == 28800
	and cappedSummary.GrantedPower == 864000)
print("IR_ZONE_CSV,stage,zone,pure_power_per_min,auto_extra_power_per_min,previous_zone_extra_power_per_min,auto_gold_per_min,previous_zone_gold_per_min")
for _, stage in ipairs({ 1, 9, 10, 19, 20, 29 }) do
	local zoneIndex = 1
	for index, zone in ipairs(config.Zones) do
		if stage >= zone.RequiredStage then zoneIndex = index end
	end
	local zone = config.Zones[zoneIndex]
	local previous = config.Zones[zoneIndex - 1]
	local purePerMinute = mathGrowth.BaseRate(stage, 1) * 60
	local currentExtra = mathGrowth.EnemyPower(stage, zone.Id) * 8
	local previousExtra = if previous then mathGrowth.EnemyPower(stage, previous.Id) * 8 else 0
	local currentGold = (zone.GoldMin + zone.GoldMax) / 2 * 8
	local previousGold = if previous then (previous.GoldMin + previous.GoldMax) / 2 * 8 else 0
	if previous then
		check("current_zone_better_" .. stage, currentExtra > previousExtra and currentGold > previousGold)
	end
	print(string.format("IR_ZONE_CSV,%d,%s,%d,%d,%d,%d,%d",
		stage, zone.Id, purePerMinute, currentExtra, previousExtra, currentGold, previousGold))
end
local scenarios = {
	{ Id = "free_training" },
	{ Id = "auto_facility", KillsPerMinute = 8, AutoFacility = true },
	{ Id = "direct_raid", KillsPerMinute = 10, AutoFacility = true },
	{ Id = "ticket2_once", Tickets = { [2] = 1 } },
	{ Id = "ticket3_once", Tickets = { [3] = 1 } },
	{ Id = "ticket5_once", Tickets = { [5] = 1 } },
	{ Id = "ticket_repeat", Tickets = { [2] = 20, [3] = 20, [5] = 20 } },
	{ Id = "voucher_only", Vouchers = { Minutes10 = 1 } },
	{ Id = "voucher_ticket", Tickets = { [5] = 1 }, Vouchers = { Minutes10 = 1 } },
	{ Id = "offline_8h", OfflineSeconds = 28800 },
}
local fights = { Gate10 = 60, Gate20 = 90, Gate30 = 120 }
local gates = { [10] = "Gate10", [20] = "Gate20", [30] = "Gate30" }
print("IR_GROWTH_CSV,scenario,stage,elapsed_training_seconds,assumed_fight_seconds,total_seconds,available_power,lifetime_power,level,facility_tier,gold,tickets_2_used,tickets_3_used,tickets_5_used,vouchers_used,cleared_gates")
for _, scenario in ipairs(scenarios) do
	local stage, facility, gold = 1, 1, 0
	local available, lifetime = 0, 0
	local goldFraction = 0
	local trainingSeconds, fightSeconds = 0, 0
	local cleared = {}
	local ticketUsed = { [2] = 0, [3] = 0, [5] = 0 }
	local vouchersUsed = 0
	local tickets = table.clone(scenario.Tickets or {})
	if scenario.OfflineSeconds then
		local offline = math.floor(mathGrowth.BaseRate(stage, facility)
			* math.min(scenario.OfflineSeconds, config.OfflineMaxSeconds)
			* config.OfflineRateNumerator / config.OfflineRateDenominator)
		available += offline
		lifetime += offline
		trainingSeconds += scenario.OfflineSeconds
	end
	if scenario.Vouchers then
		for id, count in pairs(scenario.Vouchers) do
			local voucher = config.Vouchers[id]
			for _ = 1, count do
				local grant = mathGrowth.BaseRate(stage, facility) * voucher.Seconds
				available += grant
				lifetime += grant
				vouchersUsed += 1
			end
		end
	end
	local function row()
		local level = mathGrowth.LevelProgress(lifetime)
		local count = 0
		for _ in pairs(cleared) do count += 1 end
		print(string.format("IR_GROWTH_CSV,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
			scenario.Id, stage, trainingSeconds, fightSeconds, trainingSeconds + fightSeconds,
			available, lifetime, level, facility, gold, ticketUsed[2], ticketUsed[3], ticketUsed[5], vouchersUsed, count))
	end
	row()
	local ticks = 0
	while true do
		if gates[stage] and not cleared[gates[stage]] then
			local gateId = gates[stage]
			fightSeconds += fights[gateId]
			cleared[gateId] = true
			-- Every route earns the actual server-configured gate reward on an assumed clear.
			local reward = mathGrowth.ReferenceRate(stage) * gameConfig.Raid.RewardTrainingSeconds
			available += reward
			lifetime += reward
			gold += gameConfig.Raid.DifficultyByGate[gateId].Gold
			row()
		end
		if stage == config.MaxStage then break end
		local steps = 1
		for _, option in ipairs({ 5, 3, 2 }) do
			if (tickets[option] or 0) > 0 and mathGrowth.CanAdvance(stage, option, cleared) then
				steps = option
				break
			end
		end
		local cost = mathGrowth.BreakthroughCost(stage)
		if available < cost then
			local rate = mathGrowth.BaseRate(stage, facility)
			if scenario.KillsPerMinute then
				local zone = config.Zones[1]
				for _, candidate in ipairs(config.Zones) do
					if stage >= candidate.RequiredStage then zone = candidate end
				end
				local killPower = mathGrowth.EnemyPower(stage, zone.Id)
				rate += math.floor(killPower * scenario.KillsPerMinute / 60)
				goldFraction += (zone.GoldMin + zone.GoldMax) / 2 * scenario.KillsPerMinute / 60
				local gainedGold = math.floor(goldFraction)
				gold += gainedGold
				goldFraction -= gainedGold
			end
			available += rate
			lifetime += rate
			trainingSeconds += 1
			if scenario.AutoFacility then
				local nextFacility = config.Facilities[facility + 1]
				if nextFacility and gold >= nextFacility.GoldCost
					and (not nextFacility.RequiredGate or cleared[nextFacility.RequiredGate]) then
					gold -= nextFacility.GoldCost
					facility += 1
				end
			end
		else
			available -= cost
			if steps > 1 then
				tickets[steps] -= 1
				ticketUsed[steps] += 1
			end
			stage += steps
			row()
		end
		ticks += 1
		assert(ticks < 100000, "scenario did not finish: " .. scenario.Id)
	end
	check("all_gates_played_" .. scenario.Id, cleared.Gate10 and cleared.Gate20 and cleared.Gate30)
end
print("IR_GROWTH_SIM_RESULT PASS")
