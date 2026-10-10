-- Studio mock: preseed a foreign lease before Main starts, then release it.
local test = game:GetService("StudioTestService")
local server = game:GetService("ServerScriptService"):WaitForChild("Server")
server.Main.Disabled = true
local runner = Instance.new("Script")
runner.Name = "ReviewProfileRetry"
runner.Source = [==[
local players = game:GetService("Players")
local test = game:GetService("StudioTestService")
local server = game.ServerScriptService:WaitForChild("Server")
local store = require(server.ProfileStore)
local schema = require(server.ProfileSchema)
local ok, err = pcall(function()
 local player = players:GetPlayers()[1] or players.PlayerAdded:Wait()
 local raw = schema.New(os.time())
 raw.Gold = 37
 raw._Session = { Owner = "ReviewOtherServer", ExpiresAt = os.time() + 120 }
 store.TestSetMock(player.UserId, raw)
 server.Main.Enabled = true
 task.wait(1.2)
 local waiting = store.GetStatus(player)
 local held = store.TestGetMock(player.UserId)
 assert(held._Session.Owner == "ReviewOtherServer", "foreign lease stolen")
 print("IR_REVIEW_R03_HELD", waiting, held._Session.Owner)
 held._Session = nil
 store.TestSetMock(player.UserId, held)
 local deadline = os.clock() + 12
 while store.GetStatus(player) == "Loading" and os.clock() < deadline do task.wait(0.1) end
 local profile = store.Get(player)
 print("IR_REVIEW_R03_RELEASED", store.GetStatus(player), profile and profile.Gold)
 assert(profile and profile.Gold == 37, "same player session did not recover")
end)
print("IR_REVIEW_R03_RESULT", ok, err)
test:EndTest(if ok then "PASS" else "FAIL")
]==]
runner.Parent = game:GetService("ServerScriptService")
local ok, result = pcall(function() return test:ExecutePlayModeAsync("ReviewProfileRetry") end)
print("IR_REVIEW_R03_LAUNCH", ok, result)
