local client = game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("Client")
local state = require(client.StateController)
local auto = require(client.AutoCombatController)
local growth = require(game.ReplicatedStorage.Shared.GrowthMath)
assert(state.ApplySnapshot({
 StateRevision = 1, Ready = true, BreakthroughStage = 29, BreakthroughCost = 100,
 Gold = 5, Raid = { IsParticipant = false, Status = "Idle", Defeated = false },
}))
assert(state.ApplySnapshot({
 StateRevision = 2, _Partial = true, _ClearKeys = { "BreakthroughCost" },
 BreakthroughStage = 30, Gold = 6,
}))
local now = state.GetSnapshot()
assert(now.BreakthroughCost == nil and now.BreakthroughStage == 30 and now.Gold == 6)
assert(growth.NextGate(30, { Gate10 = true, Gate20 = true }).Id == "Gate30")
assert(growth.NextGate(30, { Gate10 = true, Gate20 = true, Gate30 = true }) == nil)
assert(not auto.ShouldResetForRaid(false, false, false, false, false, false))
assert(auto.ShouldResetForRaid(false, false, false, true, true, false))
assert(auto.ShouldResetForRaid(true, true, false, true, true, true))
assert(auto.ShouldResetForRaid(true, true, false, false, false, false))
assert(not auto.ShouldResetForRaid(true, true, false, true, true, false))
print("IR_REVIEW_R06_R07_PASS", now.BreakthroughStage, now.BreakthroughCost)
