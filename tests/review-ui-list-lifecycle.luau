-- Independent Studio virtual-input check for menu reopen subscriptions and scroll retention.
local test = game:GetService("StudioTestService")
local server = game.ServerScriptService:WaitForChild("Server")
server.Main.Disabled = true
local result = Instance.new("RemoteEvent")
result.Name = "ReviewUIListLifecycleResult"
result.Parent = game.ReplicatedStorage
local update = Instance.new("RemoteEvent")
update.Name = "ReviewUIListLifecycleUpdate"
update.Parent = game.ReplicatedStorage

local client = Instance.new("LocalScript")
client.Name = "ReviewUIListLifecycleClient"
client.Source = [==[
local player = game.Players.LocalPlayer
local input = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")
local stateController = require(script.Parent:WaitForChild("Client").StateController)
local result = game.ReplicatedStorage:WaitForChild("ReviewUIListLifecycleResult")
local update = game.ReplicatedStorage:WaitForChild("ReviewUIListLifecycleUpdate")
local ok, err = pcall(function()
 local function waitFor(predicate, label, seconds)
  local untilAt = os.clock() + seconds
  while not predicate() and os.clock() < untilAt do task.wait(0.02) end
  assert(predicate(), "timeout " .. label)
 end
 waitFor(function() local s=stateController.GetSnapshot(); return s and s.Ready end, "profile", 20)
 local gui = player.PlayerGui:WaitForChild("IdleRaidUI")
 local panel = gui.MenuPanel
 local bag = panel.BagPage
 local nav = gui.MenuNavigation.BagMenu
 local scroll = bag.Inventory.Items
 local row = scroll:WaitForChild("ClothArmor", 8)
 local count, destroyed = 0, 0
 row.Activated:Connect(function() count += 1 end)
 row.Destroying:Connect(function() destroyed += 1 end)
 local virtual = input:CreateVirtualInput()
 local function click(button)
  local point = button.AbsolutePosition + button.AbsoluteSize / 2 + guiService:GetGuiInset()
  virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
  task.wait(0.05)
  virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
 end
 -- Check the actual BagMenu virtual-input path separately from the row race.
 for cycle = 1, 20 do
  click(nav)
  waitFor(function() return panel.Visible and bag.Visible end, "bag open " .. cycle, 3)
  click(row)
  waitFor(function() return count == cycle end, "row Activated " .. cycle, 2)
  click(panel.CloseMenu)
  waitFor(function() return not panel.Visible end, "bag close " .. cycle, 3)
 end
 click(nav)
 waitFor(function() return panel.Visible and bag.Visible end, "bag final open", 3)
 task.wait(0.15)
 scroll.CanvasPosition = Vector2.new(0, 60)
 task.wait(0.15)
 local before = scroll.CanvasPosition.Y
 assert(before > 0, "scroll has no overflow")
 local revision = stateController.GetSnapshot().StateRevision
 update:FireServer("full")
 waitFor(function() return stateController.GetSnapshot().StateRevision > revision end, "full", 3)
 assert(scroll:FindFirstChild("ClothArmor") == row and destroyed == 0, "full replaced row")
 assert(math.abs(scroll.CanvasPosition.Y - before) <= 1, "full reset scroll")
 revision = stateController.GetSnapshot().StateRevision
 update:FireServer("partial")
 waitFor(function() return stateController.GetSnapshot().StateRevision > revision end, "partial", 3)
 assert(scroll:FindFirstChild("ClothArmor") == row and destroyed == 0, "partial replaced row")
 assert(math.abs(scroll.CanvasPosition.Y - before) <= 1, "partial reset scroll")
 print("IR_UI_LIFECYCLE_OBS", "cycles", count, "destroyed", destroyed, "scroll", before, scroll.CanvasPosition.Y)
end)
print("IR_UI_LIFECYCLE_CLIENT_RESULT", ok, err)
result:FireServer(ok, tostring(err))
]==]
client.Parent = game.StarterPlayer.StarterPlayerScripts

local runner = Instance.new("Script")
runner.Name = "ReviewUIListLifecycleServer"
runner.Source = [==[
local test = game:GetService("StudioTestService")
local server = game.ServerScriptService:WaitForChild("Server")
local store = require(server.ProfileStore)
local schema = require(server.ProfileSchema)
local result = game.ReplicatedStorage:WaitForChild("ReviewUIListLifecycleResult")
local update = game.ReplicatedStorage:WaitForChild("ReviewUIListLifecycleUpdate")
local player = game.Players:GetPlayers()[1] or game.Players.PlayerAdded:Wait()
local profile = schema.New(os.time())
for itemId in pairs(require(game.ReplicatedStorage.Shared.ItemConfig).Items) do
 profile.Inventory[itemId] = 1
end
profile.TrainingEnabled = false
store.TestSetMock(player.UserId, profile)
server.Main.Enabled = true
update.OnServerEvent:Connect(function(from, mode)
 if from ~= player then return end
 local sync = require(server.StateSyncService)
 if mode == "full" then sync.Push(from) elseif mode == "partial" then sync.PushGrowth(from) end
end)
local done = false
result.OnServerEvent:Connect(function(from, ok, err)
 if from ~= player or done then return end
 done = true
 print("IR_UI_LIFECYCLE_RESULT", ok, err)
 test:EndTest(if ok then "PASS" else "FAIL")
end)
task.delay(100, function()
 if not done then print("IR_UI_LIFECYCLE_RESULT false timeout"); test:EndTest("TIMEOUT") end
end)
]==]
runner.Parent = server
local ok, launchResult = pcall(function() return test:ExecutePlayModeAsync("ReviewUIListLifecycle") end)
print("IR_UI_LIFECYCLE_LAUNCH", ok, launchResult)
