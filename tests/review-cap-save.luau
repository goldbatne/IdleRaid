-- Studio mock: online cap must not prevent a normal save; voucher stays intact.
local test = game:GetService("StudioTestService")
local runner = Instance.new("Script")
runner.Name = "ReviewCapSave"
runner.Source = [==[
local players = game:GetService("Players")
local test = game:GetService("StudioTestService")
local server = game.ServerScriptService:WaitForChild("Server")
local store = require(server.ProfileStore)
local training = require(server.TrainingService)
local growth = require(server.GrowthService)
local config = require(game.ReplicatedStorage.Shared.GrowthConfig)
local ok, err = pcall(function()
 local player = players:GetPlayers()[1] or players.PlayerAdded:Wait()
 local deadline = os.clock() + 20
 while not store.Get(player) and os.clock() < deadline do task.wait(0.1) end
 server:WaitForChild("DebugGetPlayerState")
 local profile = assert(store.Get(player), "profile not ready")
 local cap = config.MaxSafePower
 profile.AvailableTrainingPower = cap - 1
 profile.LifetimeTrainingPower = cap - 1
 profile.TrainingVouchers.Minutes10 = 1
 profile.BreakthroughStage = config.MaxStage
 profile.TrainingFacilityTier = #config.Facilities
 profile.TrainingEnabled = true
 profile.TrainingRemainderMillis = 0
 store.Touch(player)
 local preview = growth.PreviewVoucher(player, "Minutes10")
 print("IR_REVIEW_R05_VOUCHER", preview.Ok, preview.Reason, profile.TrainingVouchers.Minutes10)
 assert(preview.Ok == false and preview.Reason == "PowerCap", "voucher cap preview accepted")
 local use = growth.TryUseVoucher(player, "Minutes10", preview.Rate, preview.Count)
 assert(use.Ok == false and use.Reason == "PowerCap" and profile.TrainingVouchers.Minutes10 == 1, "voucher cap consumed")
 -- Preview result is logged; the save boundary is asserted below.
 training.ResetClock(player)
 task.wait(0.2)
 local settled = training.Settle(player)
 local saved, reason = store.Save(player)
 local durable = store.TestGetMock(player.UserId)
 print("IR_REVIEW_R05_SAVE", settled, saved, reason, profile.AvailableTrainingPower,
  durable and durable.AvailableTrainingPower)
 assert(settled and saved and profile.AvailableTrainingPower == cap
  and profile.LifetimeTrainingPower == cap
  and durable.AvailableTrainingPower == cap and durable.LifetimeTrainingPower == cap,
  "cap blocked valid save")
 assert(profile.TrainingVouchers.Minutes10 == 1, "voucher consumed")
end)
print("IR_REVIEW_R05_RESULT", ok, err)
test:EndTest(if ok then "PASS" else "FAIL")
]==]
runner.Parent = game:GetService("ServerScriptService")
local ok, result = pcall(function() return test:ExecutePlayModeAsync("ReviewCapSave") end)
print("IR_REVIEW_R05_LAUNCH", ok, result)
