-- Deterministic economic comparison using the shipped GrowthConfig and GrowthMath.
-- Kill cadence and boss durations are assumptions, not measured gameplay.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local config = require(shared.GrowthConfig)
local growth = require(shared.GrowthMath)
local gameConfig = require(shared.GameConfig)

local scenarios = {
	{ Id = "free_training", KillsPerMinute = 0, BuyFacility = false },
	{ Id = "free_auto_facility", KillsPerMinute = 8, BuyFacility = true },
	{ Id = "studio_ticket5_once", KillsPerMinute = 8, BuyFacility = true, Ticket5 = 1 },
	{ Id = "studio_voucher10_once", KillsPerMinute = 8, BuyFacility = true, Voucher10 = 1 },
}
local assumedFight = { Gate10 = 60, Gate20 = 90, Gate30 = 120 }
local gateAt = { [10] = "Gate10", [20] = "Gate20", [30] = "Gate30" }
print("IR_COMPARE_META,environment=StudioEdit,actual_play=false,kills_per_minute_assumed=8,drop_equipment_omitted=true,actual_clear_time=NOT_MEASURED")
print("IR_COMPARE_HEADER,scenario,gate,reach_seconds,assumed_clear_seconds,actual_clear_seconds,stage,level,facility,available_power,lifetime_power,gold,ticket5_used,voucher10_used")
for _, scenario in ipairs(scenarios) do
	local stage, facility, gold = 1, 1, 0
	local available, lifetime = 0, 0
	local elapsed, fightTime = 0, 0
	local killFraction, goldFraction = 0, 0
	local cleared = {}
	local ticketsUsed, vouchersUsed = 0, 0
	if scenario.Voucher10 then
		local grant = growth.BaseRate(stage, facility) * config.Vouchers.Minutes10.Seconds
		available += grant
		lifetime += grant
		vouchersUsed = 1
		print("IR_COMPARE_USE," .. scenario.Id .. ",Voucher10,stage=1,time=0,grant=" .. tostring(grant))
	end
	local ticks = 0
	while stage <= config.MaxStage do
		local gateId = gateAt[stage]
		if gateId and not cleared[gateId] then
			local level = growth.LevelProgress(lifetime)
			local reach = elapsed + fightTime
			local assumedClear = reach + assumedFight[gateId]
			print(string.format("IR_COMPARE_ROW,%s,%s,%d,%d,NOT_MEASURED,%d,%d,%d,%d,%d,%d,%d,%d",
				scenario.Id, gateId, reach, assumedClear, stage, level, facility, available,
				lifetime, gold, ticketsUsed, vouchersUsed))
			fightTime += assumedFight[gateId]
			cleared[gateId] = true -- hypothetical direct clear, never an in-game grant
			local reward = growth.ReferenceRate(stage) * gameConfig.Raid.RewardTrainingSeconds
			available += reward
			lifetime += reward
			gold += gameConfig.Raid.DifficultyByGate[gateId].Gold
		end
		if stage == config.MaxStage then break end
		local step = 1
		if scenario.Ticket5 and ticketsUsed < scenario.Ticket5
			and growth.CanAdvance(stage, 5, cleared) then step = 5 end
		local cost = growth.BreakthroughCost(stage)
		if available >= cost then
			available -= cost
			stage += step
			if step == 5 then
				ticketsUsed += 1
				print(string.format("IR_COMPARE_USE,%s,Ticket5,stage=%d,time=%d,cost=%d",
					scenario.Id, stage, elapsed + fightTime, cost))
			end
		else
			local rate = growth.BaseRate(stage, facility)
			available += rate
			lifetime += rate
			killFraction += scenario.KillsPerMinute / 60
			local zone
			for _, candidate in ipairs(config.Zones) do
				if stage >= candidate.RequiredStage then zone = candidate end
			end
			while zone and killFraction >= 1 do
				killFraction -= 1
				local reward = growth.EnemyPower(stage, zone.Id)
				available += reward
				lifetime += reward
				goldFraction += (zone.GoldMin + zone.GoldMax) / 2
				local integerGold = math.floor(goldFraction)
				gold += integerGold
				goldFraction -= integerGold
			end
			elapsed += 1
			if scenario.BuyFacility then
				local nextFacility = config.Facilities[facility + 1]
				if nextFacility and gold >= nextFacility.GoldCost
					and (not nextFacility.RequiredGate or cleared[nextFacility.RequiredGate]) then
					gold -= nextFacility.GoldCost
					facility += 1
				end
			end
		end
		ticks += 1
		assert(ticks < 100000, "scenario stalled: " .. scenario.Id)
	end
	assert(cleared.Gate10 and cleared.Gate20 and cleared.Gate30)
end
print("IR_COMPARE_RESULT PASS")
