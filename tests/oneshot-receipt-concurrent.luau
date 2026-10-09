-- Studio mock concurrency check for one synthetic purchase ID; no real Roblox purchase.
local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local testScript = Instance.new("Script")
testScript.Name = "OneShotReceiptConcurrentServer"
testScript.Source = [==[
local Players = game:GetService("Players")
local test = game:GetService("StudioTestService")
local services = game.ServerScriptService:WaitForChild("Server")
local store = require(services.ProfileStore)
local payments = require(services.MonetizationService)
local training = require(services.TrainingService)
local ok, err = pcall(function()
 local player = Players.PlayerAdded:Wait()
 local deadline = os.clock() + 20
 while not store.Get(player) and os.clock() < deadline do task.wait(0.1) end
 assert(store.Get(player), "profile not ready")
 training.SetEnabled(player, false)
 -- Hold the first save open so the second request reaches receiptBusy concurrently.
 store.SetBeforeSave(function() task.wait(0.25); return true end)
 local first, second
 task.spawn(function() first = payments.ProcessSynthetic(player, "ParallelReceipt", "Ticket5") end)
 task.spawn(function() second = payments.ProcessSynthetic(player, "ParallelReceipt", "Ticket5") end)
 local finish = os.clock() + 15
 while (first == nil or second == nil) and os.clock() < finish do task.wait(0.05) end
 assert(first ~= nil and second ~= nil, "concurrent calls did not finish")
 assert((first == Enum.ProductPurchaseDecision.PurchaseGranted
  and second == Enum.ProductPurchaseDecision.NotProcessedYet)
  or (second == Enum.ProductPurchaseDecision.PurchaseGranted
  and first == Enum.ProductPurchaseDecision.NotProcessedYet), "requests did not overlap safely")
 local profile = store.Get(player)
 assert(profile.BreakthroughTickets["5"] == 1
  and profile.ProcessedPurchases.ParallelReceipt == "Ticket5:v1", "duplicate grant")
 assert(payments.ProcessSynthetic(player, "ParallelReceipt", "Ticket5")
  == Enum.ProductPurchaseDecision.PurchaseGranted, "saved retry not acknowledged")
 assert(store.Get(player).BreakthroughTickets["5"] == 1, "retry double grant")
 print("IR_RECEIPT_PARALLEL_PASS one_grant_two_calls_and_retry")
end)
print("IR_RECEIPT_PARALLEL_RESULT", ok, err)
test:EndTest(if ok then "PASS" else "FAIL")
]==]
testScript.Parent = ServerScriptService
local ok, result = pcall(function() return StudioTestService:ExecutePlayModeAsync("OneShotReceiptConcurrent") end)
print("IR_RECEIPT_PARALLEL_LAUNCH", ok, result)
