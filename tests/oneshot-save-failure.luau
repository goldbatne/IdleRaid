-- Studio mock assertion that a rejected settlement cannot be acknowledged as a saved receipt.
local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local testScript = Instance.new("Script")
testScript.Name = "OneShotSaveFailureServer"
testScript.Source = [==[
local Players = game:GetService("Players")
local test = game:GetService("StudioTestService")
local services = game.ServerScriptService:WaitForChild("Server")
local store = require(services.ProfileStore)
local ok, err = pcall(function()
 local player = Players.PlayerAdded:Wait()
 local deadline = os.clock() + 20
 while not store.Get(player) and os.clock() < deadline do task.wait(0.1) end
 assert(store.Get(player), "profile not ready")
 local original = store.TestGetMock(player.UserId)
 store.SetBeforeSave(function() return false end)
 local saved, reason = store.Save(player)
 assert(not saved and reason == "SettlementFailed", "failed handler acknowledged")
 local after = store.TestGetMock(player.UserId)
 assert(after.StateRevision == original.StateRevision, "mock record changed after failed settlement")
 print("IR_SAVE_FAILURE_PASS handler_false_rejected")
end)
print("IR_SAVE_FAILURE_RESULT", ok, err)
test:EndTest(if ok then "PASS" else "FAIL")
]==]
testScript.Parent = ServerScriptService
local ok, result = pcall(function() return StudioTestService:ExecutePlayModeAsync("OneShotSaveFailure") end)
print("IR_SAVE_FAILURE_LAUNCH", ok, result)
