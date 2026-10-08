local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local spawn = Instance.new("SpawnLocation")
spawn.Name = "GrowthIntegrationSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0, 0)
spawn.Parent = workspace

local testScript = Instance.new("Script")
testScript.Name = "GrowthV2IntegrationServer"
testScript.Source = [==[
local Players = game:GetService("Players")
local StudioTestService = game:GetService("StudioTestService")
local player = Players.PlayerAdded:Wait()
local server = game.ServerScriptService:WaitForChild("Server")
local debugState = server:WaitForChild("DebugGetPlayerState", 20)
local deadline = os.clock() + 20
local state
repeat
	state = debugState:Invoke(player)
	task.wait(0.1)
until (state and state.Ready) or os.clock() > deadline
local function check(name, condition)
	assert(condition, name)
	print("IR_INTEGRATION_PASS", name)
end
local ok, err = pcall(function()
	check("ready", state and state.Ready)
	local growth = require(server.GrowthService)
	local profileStore = require(server.ProfileStore)
	local data = require(server.PlayerDataService)
	local training = require(server.TrainingService)
	local mathGrowth = require(game.ReplicatedStorage.Shared.GrowthMath)
	local monetization = require(server.MonetizationService)
	check("training_off", training.SetEnabled(player, false))
	check("gold_grant", data.AddGold(player, 1000))
	local upgrade = growth.TryUpgradeFacility(player, 1)
	state = debugState:Invoke(player)
	check("facility_gold_and_rate", upgrade.Ok and state.TrainingFacilityTier == 2
		and state.Gold == 880 and state.BaseTrainingRate == 15
		and state.BreakthroughCost == 450)
	check("power_grant", data.AddPowerFinal(player, 1000000, "Test"))
	local before = debugState:Invoke(player)
	local free = growth.TryBreakthrough(player, 1, 1)
	state = debugState:Invoke(player)
	check("free_breakthrough_ledger", free.Ok and state.BreakthroughStage == 2
		and state.LifetimeTrainingPower == before.LifetimeTrainingPower
		and state.AvailableTrainingPower == before.AvailableTrainingPower - 450)
	check("ticket_ownership", growth.GrantOwnership(player, "Ticket", 5, 1))
	local plusFive = growth.TryBreakthrough(player, 5, 2)
	check("ticket_2_to_7", plusFive.Ok and plusFive.Stage == 7)
	local stage7 = debugState:Invoke(player)
	check("gate_skip_rejected", not growth.TryBreakthrough(player, 5, 7).Ok)
	local afterSkip = debugState:Invoke(player)
	check("gate_skip_keeps_wallet_and_ticket",
		afterSkip.AvailableTrainingPower == stage7.AvailableTrainingPower
		and afterSkip.BreakthroughTickets["5"] == stage7.BreakthroughTickets["5"])
	check("grant_plus3", growth.GrantOwnership(player, "Ticket", 3, 1))
	local gateArrival = growth.TryBreakthrough(player, 3, 7)
	check("seven_plus_three_to_gate", gateArrival.Ok and gateArrival.Stage == 10)
	check("stage10_locked", not growth.TryBreakthrough(player, 1, 10).Ok)
	check("gate_eligible", growth.CanClearGate(player, "Gate10"))
	check("trusted_gate_record", growth.RecordGateClear(player, "Gate10"))
	check("more_power", data.AddPowerFinal(player, 10000000, "Test"))
	check("second_plus5", growth.GrantOwnership(player, "Ticket", 5, 1))
	local advance = growth.TryBreakthrough(player, 5, 10)
	check("cleared_gate_advances", advance.Ok and advance.Stage == 15)
	check("voucher_ownership", growth.GrantOwnership(player, "Voucher", "Minutes10", 1))
	local voucher = growth.PreviewVoucher(player, "Minutes10")
	check("voucher_preview_formula", voucher.Ok and voucher.Grant == voucher.Rate * 600)
	local beforeVoucher = debugState:Invoke(player)
	local used = growth.TryUseVoucher(player, "Minutes10", voucher.Rate, voucher.Count)
	local afterVoucher = debugState:Invoke(player)
	check("voucher_exact_once", used.Ok
		and afterVoucher.AvailableTrainingPower - beforeVoucher.AvailableTrainingPower == voucher.Grant
		and afterVoucher.LifetimeTrainingPower - beforeVoucher.LifetimeTrainingPower == voucher.Grant
		and afterVoucher.TrainingVouchers.Minutes10 == 0)
	check("bad_item_rejected", not require(server.InventoryService).AddItem(player, "ForgedSword", 1))
	check("token_grant", data.AddRaidToken(player, 20))
	local tokenBefore = debugState:Invoke(player)
	local exchanged = growth.TryExchangeTicket(player, 2, tokenBefore.RaidToken,
		tokenBefore.BreakthroughTickets["2"])
	local tokenAfter = debugState:Invoke(player)
	check("token_exchange_atomic", exchanged.Ok and tokenAfter.RaidToken == 10
		and tokenAfter.BreakthroughTickets["2"] == tokenBefore.BreakthroughTickets["2"] + 1)
	check("token_stale_rejected", not growth.TryExchangeTicket(player, 2, tokenBefore.RaidToken,
		tokenBefore.BreakthroughTickets["2"]).Ok)
	local receiptId = "StudioIntegrationReceipt"
	local beforeReceipt = debugState:Invoke(player)
	local first = monetization.ProcessSynthetic(player, receiptId, "Ticket2")
	local second = monetization.ProcessSynthetic(player, receiptId, "Ticket2")
	local afterReceipt = debugState:Invoke(player)
	check("receipt_idempotent", first == Enum.ProductPurchaseDecision.PurchaseGranted
		and second == Enum.ProductPurchaseDecision.PurchaseGranted
		and afterReceipt.BreakthroughTickets["2"] == beforeReceipt.BreakthroughTickets["2"] + 1)
	check("receipt_wrong_contract_rejected",
		monetization.ProcessSynthetic(player, receiptId, "Ticket3") == Enum.ProductPurchaseDecision.NotProcessedYet)
	local stored = profileStore.TestGetMock(player.UserId)
	check("receipt_saved_with_profile", stored and stored.ProcessedPurchases[receiptId] == "Ticket2:v1"
		and stored.BreakthroughTickets["2"] == afterReceipt.BreakthroughTickets["2"])
	local remote = game.ReplicatedStorage.IdleRaidRemotes.GrowthAction
	task.wait(0.1)
	local request = { Steps = 2, ExpectedTokens = afterReceipt.RaidToken,
		ExpectedCount = afterReceipt.BreakthroughTickets["2"], RequestId = "integration-repeat-001" }
	local firstExchange = growth.TestHandleRemote(player, "ExchangeTicket", request)
	local repeatExchange = growth.TestHandleRemote(player, "ExchangeTicket", request)
	local finalState = debugState:Invoke(player)
	check("remote_request_idempotent", firstExchange.Ok and repeatExchange.Ok
		and finalState.RaidToken == afterReceipt.RaidToken - 10
		and finalState.BreakthroughTickets["2"] == afterReceipt.BreakthroughTickets["2"] + 1)
	check("invalid_remote_amount_rejected", not growth.PreviewBreakthrough(player, math.huge).Ok)
	local beforeFailedReceipt = debugState:Invoke(player)
	profileStore.TestFailNextUpdates(3)
	local failedReceipt = monetization.ProcessSynthetic(player, "StudioRetryReceipt", "Ticket3")
	local afterFailedReceipt = debugState:Invoke(player)
	local durableBeforeRetry = profileStore.TestGetMock(player.UserId)
	check("receipt_save_failure_retained_for_retry",
		failedReceipt == Enum.ProductPurchaseDecision.NotProcessedYet
		and afterFailedReceipt.BreakthroughTickets["3"] == beforeFailedReceipt.BreakthroughTickets["3"] + 1
		and durableBeforeRetry.ProcessedPurchases.StudioRetryReceipt == nil
		and profileStore.IsReceiptPending(player))
	check("spending_blocked_while_receipt_pending",
		growth.TryBreakthrough(player, 1, afterFailedReceipt.BreakthroughStage).Reason == "ReceiptSaving")
	local retriedReceipt = monetization.ProcessSynthetic(player, "StudioRetryReceipt", "Ticket3")
	local afterRetriedReceipt = debugState:Invoke(player)
	local durableAfterRetry = profileStore.TestGetMock(player.UserId)
	check("receipt_retry_no_double_grant",
		retriedReceipt == Enum.ProductPurchaseDecision.PurchaseGranted
		and afterRetriedReceipt.BreakthroughTickets["3"] == afterFailedReceipt.BreakthroughTickets["3"]
		and durableAfterRetry.ProcessedPurchases.StudioRetryReceipt == "Ticket3:v1"
		and not profileStore.IsReceiptPending(player))
	local foreign = profileStore.TestGetMock(player.UserId)
	foreign._Session = { Owner = "AnotherServer", ExpiresAt = os.time() + 120 }
	profileStore.TestSetMock(player.UserId, foreign)
	local saved, saveReason = profileStore.Save(player)
	check("session_lock_loss_blocks_profile",
		not saved and saveReason == "SessionLost" and profileStore.Get(player) == nil)
end)
print("IR_INTEGRATION_RESULT", ok, err)
StudioTestService:EndTest(if ok then "PASS" else "FAIL")
]==]
testScript.Parent = ServerScriptService
local ok, result = pcall(function() return StudioTestService:ExecutePlayModeAsync("GrowthV2Integration") end)
print("IR_INTEGRATION_LAUNCH", ok, result)
