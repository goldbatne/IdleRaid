-- Studio mock: receipt grant -> forced persistence failure -> normal save only.
local test = game:GetService("StudioTestService")
local scriptService = game:GetService("ServerScriptService")
local runner = Instance.new("Script")
runner.Name = "ReviewReceiptRecovery"
runner.Source = [==[
local players = game:GetService("Players")
local test = game:GetService("StudioTestService")
local services = game.ServerScriptService:WaitForChild("Server")
local store = require(services.ProfileStore)
local payments = require(services.MonetizationService)
local training = require(services.TrainingService)
local ok, err = pcall(function()
 local player = players.PlayerAdded:Wait()
 local deadline = os.clock() + 20
 while not store.Get(player) and os.clock() < deadline do task.wait(0.1) end
 assert(store.Get(player), "profile not ready")
 training.SetEnabled(player, false)
 store.TestFailNextUpdates(3)
 local first = payments.ProcessSynthetic(player, "ReviewRecoveryReceipt", "Ticket5")
 local profile = store.Get(player)
 assert(first == Enum.ProductPurchaseDecision.NotProcessedYet, "failure acknowledged")
 assert(profile.BreakthroughTickets["5"] == 1 and store.IsReceiptPending(player), "pending grant missing")
 local saved = store.Save(player)
 local durable = store.TestGetMock(player.UserId)
 local recovered = saved and not store.IsReceiptPending(player)
  and durable.ProcessedPurchases.ReviewRecoveryReceipt == "Ticket5:v1"
  and durable.BreakthroughTickets["5"] == 1
 print("IR_REVIEW_R04_AUTOSAVE", saved, recovered, store.IsReceiptPending(player), durable.BreakthroughTickets["5"])
 assert(recovered, "normal save did not recover receipt state")
 assert(payments.ProcessSynthetic(player, "ReviewRecoveryReceipt", "Ticket5")
  == Enum.ProductPurchaseDecision.PurchaseGranted, "durable retry rejected")
 assert(store.Get(player).BreakthroughTickets["5"] == 1, "duplicate ownership")
 local original = store.SaveReceipt
 store.SaveReceipt = function() error("ReviewInjectedReceiptException") end
 local exceptionResult = payments.ProcessSynthetic(player, "ReviewExceptionReceipt", "Ticket2")
 store.SaveReceipt = original
 assert(exceptionResult == Enum.ProductPurchaseDecision.NotProcessedYet, "exception acknowledged")
 assert(payments.ProcessSynthetic(player, "ReviewExceptionReceipt", "Ticket2")
  == Enum.ProductPurchaseDecision.PurchaseGranted, "busy lock survived exception")
 assert(store.Get(player).BreakthroughTickets["2"] == 1, "exception retry double grant")
 print("IR_REVIEW_R04_PASS autosave_recovery_duplicate_exception")
end)
print("IR_REVIEW_R04_RESULT", ok, err)
test:EndTest(if ok then "PASS" else "FAIL")
]==]
runner.Parent = scriptService
local ok, result = pcall(function() return test:ExecutePlayModeAsync("ReviewReceiptRecovery") end)
print("IR_REVIEW_R04_LAUNCH", ok, result)
