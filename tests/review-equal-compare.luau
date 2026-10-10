-- Deterministic matched-policy comparison, not a measured Play clear.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local config = require(shared.GrowthConfig)
local growth = require(shared.GrowthMath)
local gameConfig = require(shared.GameConfig)
local scenarios = {
 { Id = "free", Ticket5 = 0, Voucher10 = 0 },
 { Id = "studio_ticket5", Ticket5 = 1, Voucher10 = 0 },
 { Id = "studio_voucher10", Ticket5 = 0, Voucher10 = 1 },
}
local fight = { Gate10 = 60, Gate20 = 90, Gate30 = 120 }
local gateAt = { [10] = "Gate10", [20] = "Gate20", [30] = "Gate30" }
print("IR_REVIEW_COMPARE_META,mode=StudioEditDeterministic,actual_play=false,seed=none,kills_per_minute=8,zone_policy=highest_unlocked,facility_policy=buy_when_affordable,equipment=none,skills=none,drops=omitted,gold=zone_mean,raid_wait=0,fight_seconds_assumed=60/90/120,training_during_raid=true,attack_timing=not_modeled")
print("IR_REVIEW_COMPARE_HEADER,scenario,gate,reach_seconds,queue_wait_seconds,combat_start_seconds,assumed_clear_seconds,actual_clear_seconds,stage,level,facility,attack,available_power,lifetime_power,gold,ticket5_used,voucher10_used,kills")
for _, scenario in ipairs(scenarios) do
 local stage, facility, gold = 1, 1, 0
 local available, lifetime, elapsed = 0, 0, 0
 local killFraction, goldFraction, kills = 0, 0, 0
 local cleared = {}
 local ticketsUsed, vouchersUsed = 0, 0
 if scenario.Voucher10 == 1 then
  local grant = growth.BaseRate(stage, facility) * config.Vouchers.Minutes10.Seconds
  available += grant
  lifetime += grant
  vouchersUsed = 1
  print(string.format("IR_REVIEW_COMPARE_EVENT,%s,0,StudioVoucher10,none,none,0,%d,0,1,1,none", scenario.Id, grant))
 end
 local ticks = 0
 while stage <= config.MaxStage do
  local gate = gateAt[stage]
  if gate and not cleared[gate] then
   local level = growth.LevelProgress(lifetime)
   local attack = gameConfig.Player.InitialBaseAttack + (level - 1) * gameConfig.Level.AttackIncreasePerLevel
   local reach = elapsed
   print(string.format("IR_REVIEW_COMPARE_ROW,%s,%s,%d,0,%d,%d,NOT_MEASURED,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
    scenario.Id, gate, reach, reach, reach + fight[gate], stage, level, facility, attack, available, lifetime, gold, ticketsUsed, vouchersUsed, kills))
   for _ = 1, fight[gate] do
    local power = growth.BaseRate(stage, facility)
    available += power
    lifetime += power
    elapsed += 1
   end
   cleared[gate] = true
   local reward = growth.ReferenceRate(stage) * gameConfig.Raid.RewardTrainingSeconds
   available += reward
   lifetime += reward
   gold += gameConfig.Raid.DifficultyByGate[gate].Gold
   print(string.format("IR_REVIEW_COMPARE_EVENT,%s,%d,RaidReward,%s,none,0,%d,%d,%d,%d,none",
    scenario.Id, elapsed, gate, reward, gameConfig.Raid.DifficultyByGate[gate].Gold, stage, facility))
  end
  if stage == config.MaxStage then break end
  local step = 1
  if scenario.Ticket5 == 1 and ticketsUsed == 0 and growth.CanAdvance(stage, 5, cleared) then step = 5 end
  local cost = growth.BreakthroughCost(stage)
  if available >= cost then
   available -= cost
   local from = stage
   stage += step
   if step == 5 then ticketsUsed = 1 end
   print(string.format("IR_REVIEW_COMPARE_EVENT,%s,%d,Breakthrough,%d_to_%d,none,0,%d,0,%d,%d,none",
    scenario.Id, elapsed, from, stage, -cost, stage, facility))
  else
   local rate = growth.BaseRate(stage, facility)
   available += rate
   lifetime += rate
   elapsed += 1
   killFraction += 8 / 60
   local zone
   for _, candidate in ipairs(config.Zones) do
    if stage >= candidate.RequiredStage then zone = candidate end
   end
   while zone and killFraction >= 1 do
    killFraction -= 1
    local power = growth.EnemyPower(stage, zone.Id)
    available += power
    lifetime += power
    goldFraction += (zone.GoldMin + zone.GoldMax) / 2
    local integerGold = math.floor(goldFraction)
    gold += integerGold
    goldFraction -= integerGold
    kills += 1
    local level = growth.LevelProgress(lifetime)
    local attack = gameConfig.Player.InitialBaseAttack + (level - 1) * gameConfig.Level.AttackIncreasePerLevel
    print(string.format("IR_REVIEW_COMPARE_EVENT,%s,%d,Kill,%s,%s,%d,%d,%d,%d,%d,none",
     scenario.Id, elapsed, zone.Id, zone.EnemyId, attack, power, integerGold, stage, facility))
   end
   local nextFacility = config.Facilities[facility + 1]
   if nextFacility and gold >= nextFacility.GoldCost
    and (not nextFacility.RequiredGate or cleared[nextFacility.RequiredGate]) then
    gold -= nextFacility.GoldCost
    facility += 1
    print(string.format("IR_REVIEW_COMPARE_EVENT,%s,%d,Facility,%d,none,0,0,%d,%d,%d,none",
     scenario.Id, elapsed, facility, -nextFacility.GoldCost, stage, facility))
   end
  end
  ticks += 1
  assert(ticks < 100000, "stalled " .. scenario.Id)
 end
 assert(cleared.Gate10 and cleared.Gate20 and cleared.Gate30)
end
print("IR_REVIEW_COMPARE_RESULT PASS")
