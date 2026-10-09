-- Studio Play test: real client RemoteFunction calls, server record assertions.
local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local channel = Instance.new("RemoteEvent")
channel.Name = "OneShotSandboxChannel"
channel.Parent = ReplicatedStorage

local client = Instance.new("LocalScript")
client.Name = "OneShotSandboxClient"
client.Source = [==[
local channel = game.ReplicatedStorage.OneShotSandboxChannel
local remotes = game.ReplicatedStorage:WaitForChild("IdleRaidRemotes")
local profileMode = remotes:WaitForChild("StudioProfileMode")
local grant = remotes:WaitForChild("StudioGrowthGrant")
local grantItem = remotes:WaitForChild("StudioInventoryGrant")
local receipt = remotes:WaitForChild("StudioSyntheticReceipt")
local waiting
channel.OnClientEvent:Connect(function(kind, ok)
 if kind == "ack" and waiting then waiting:Fire(ok) end
end)
local function step(label)
 local signal = Instance.new("BindableEvent")
 waiting = signal
 channel:FireServer(label)
 local passed = signal.Event:Wait()
 waiting = nil
 signal:Destroy()
 assert(passed, "server rejected " .. label)
end
local ok, err = pcall(function()
 step("ready")
 assert(grant:InvokeServer("Power", 1000) == false, "normal profile accepted development grant")
 assert(grantItem:InvokeServer("TrainingSword") == false, "normal item grant accepted")
 assert(profileMode:InvokeServer(true), "sandbox switch failed")
 assert(grant:InvokeServer("Power", 1000), "sandbox power grant failed")
 assert(grantItem:InvokeServer("TrainingSword"), "sandbox item grant failed")
 assert(receipt:InvokeServer("StudioSandboxReceiptA", "Ticket5") == Enum.ProductPurchaseDecision.PurchaseGranted,
  "synthetic receipt failed")
 step("sandbox")
 assert(profileMode:InvokeServer(false), "normal switch failed")
 step("normal")
 assert(profileMode:InvokeServer(true), "sandbox reentry failed")
 step("reentry")
 assert(profileMode:InvokeServer(false), "final normal switch failed")
end)
channel:FireServer("done", ok, tostring(err))
]==]
client.Parent = StarterPlayer.StarterPlayerScripts

local server = Instance.new("Script")
server.Name = "OneShotSandboxServer"
server.Source = [==[
local Players = game:GetService("Players")
local StudioTestService = game:GetService("StudioTestService")
local channel = game.ReplicatedStorage.OneShotSandboxChannel
local services = game.ServerScriptService:WaitForChild("Server")
local store = require(services.ProfileStore)
local training = require(services.TrainingService)
local data = require(services.PlayerDataService)
local expected
local failed = false
local function ready(player)
 local deadline = os.clock() + 20
 repeat
  if store.Get(player) then
   training.SetEnabled(player, false)
   local normal = store.Get(player)
   expected = { Power = normal.AvailableTrainingPower, Gold = normal.Gold,
    Sword = normal.Inventory.TrainingSword or 0 }
   return
  end
  task.wait(0.1)
 until os.clock() > deadline
 error("profile not ready")
end
channel.OnServerEvent:Connect(function(player, kind, clientOk, clientError)
 if kind == "done" then
  print("IR_SANDBOX_RESULT", not failed and clientOk == true, clientError)
  StudioTestService:EndTest(if not failed and clientOk == true then "PASS" else "FAIL")
  return
 end
 local ok, err = pcall(function()
  if kind == "ready" then ready(player)
  elseif kind == "sandbox" then
   assert(store.IsStudioSandbox(player), "sandbox mode missing")
   local profile = store.Get(player)
   assert(profile.AvailableTrainingPower >= 1000 and profile.Inventory.TrainingSword == 1
    and profile.BreakthroughTickets["5"] == 1, "sandbox grants missing")
  elseif kind == "normal" then
   assert(not store.IsStudioSandbox(player), "normal mode missing")
   local profile = store.Get(player)
   assert(profile.AvailableTrainingPower == expected.Power and profile.Gold == expected.Gold
    and (profile.Inventory.TrainingSword or 0) == expected.Sword
    and profile.BreakthroughTickets["5"] == 0, "normal profile contaminated")
  elseif kind == "reentry" then
   assert(store.IsStudioSandbox(player), "sandbox mode not restored")
   local profile = store.Get(player)
   assert(profile.Inventory.TrainingSword == 1 and profile.BreakthroughTickets["5"] == 1
    and profile.ProcessedPurchases.StudioSandboxReceiptA == "Ticket5:v1",
    "sandbox record not restored")
  else error("unknown step") end
 end)
 if ok then print("IR_SANDBOX_PASS", kind)
 else failed = true; warn("IR_SANDBOX_FAIL " .. tostring(err)) end
 channel:FireClient(player, "ack", ok)
end)
]==]
server.Parent = ServerScriptService
local ok, result = pcall(function() return StudioTestService:ExecutePlayModeAsync("OneShotSandbox") end)
print("IR_SANDBOX_LAUNCH", ok, result)
