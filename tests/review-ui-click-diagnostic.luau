-- One isolated Studio mock profile per run. No production source mutation.
local test = game:GetService("StudioTestService")
local server = game:GetService("ServerScriptService"):WaitForChild("Server")
server.Main.Disabled = true
local remote = Instance.new("RemoteEvent")
remote.Name = "ReviewUIClickResult"
remote.Parent = game.ReplicatedStorage

local client = Instance.new("LocalScript")
client.Name = "ReviewUIClickClient"
client.Source = [==[
local players = game:GetService("Players")
local input = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")
local player = players.LocalPlayer
local report = game.ReplicatedStorage:WaitForChild("ReviewUIClickResult")
local stateController = require(script.Parent:WaitForChild("Client").StateController)
local ok, err = pcall(function()
 local deadline = os.clock() + 20
 while (not stateController.GetSnapshot() or not stateController.GetSnapshot().Ready) and os.clock() < deadline do task.wait(0.05) end
 local state = assert(stateController.GetSnapshot(), "no state")
 assert(state.Ready, "profile not ready")
 local gui = player.PlayerGui:WaitForChild("IdleRaidUI", 20)
 local nav = gui:WaitForChild("MenuNavigation")
 local panel = gui:WaitForChild("MenuPanel")
 local bag = panel:WaitForChild("BagPage")
 local virtual = input:CreateVirtualInput()
 local function click(button)
  local p = button.AbsolutePosition + button.AbsoluteSize / 2 + guiService:GetGuiInset()
  virtual:SendMouseButton(p, Enum.UserInputType.MouseButton1, true, 0)
  task.wait(0.03)
  virtual:SendMouseButton(p, Enum.UserInputType.MouseButton1, false, 0)
  return p
 end
 print("IR_UI_CLICK_INITIAL", state.BreakthroughStage, state.Gold, state.AvailableTrainingPower,
  state.TrainingFacilityTier, state.Inventory[1] and state.Inventory[1].ItemId)
 local bagActivated = 0
 nav.BagMenu.Activated:Connect(function() bagActivated += 1; print("IR_UI_CLICK_BAG_ACTIVATED", bagActivated) end)
 local bagPoint = nav.BagMenu.AbsolutePosition + nav.BagMenu.AbsoluteSize / 2 + guiService:GetGuiInset()
 local bagUnder = player.PlayerGui:GetGuiObjectsAtPosition(bagPoint.X, bagPoint.Y)
 print("IR_UI_CLICK_BAG_GEOMETRY", nav.BagMenu.AbsolutePosition, nav.BagMenu.AbsoluteSize, bagPoint,
  bagUnder[1] and bagUnder[1]:GetFullName(), nav.BagMenu.Visible, panel.Visible)
 click(nav.BagMenu)
 deadline = os.clock() + 8
 while not bag.Visible and os.clock() < deadline do task.wait(0.05) end
 print("IR_UI_CLICK_BAG_RESULT", bagActivated, bag.Visible, panel.Visible)
 assert(bag.Visible, "bag did not open")
 local scroll = bag.Inventory.Items
 local row = scroll:WaitForChild("TrainingSword", 8)
 assert(row, "item row missing")
 local activated, down, up, destroyed = 0, 0, 0, 0
 row.Activated:Connect(function() activated += 1; print("IR_UI_CLICK_EVENT activated", stateController.GetSnapshot().StateRevision) end)
 row.InputBegan:Connect(function(event)
  if event.UserInputType == Enum.UserInputType.MouseButton1 then down += 1; print("IR_UI_CLICK_EVENT down") end
 end)
 row.InputEnded:Connect(function(event)
  if event.UserInputType == Enum.UserInputType.MouseButton1 then up += 1; print("IR_UI_CLICK_EVENT up") end
 end)
 row.Destroying:Connect(function() destroyed += 1; print("IR_UI_CLICK_EVENT destroyed", stateController.GetSnapshot().StateRevision) end)
 local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize
 local inset = guiService:GetGuiInset()
 local point = row.AbsolutePosition + row.AbsoluteSize / 2 + inset
 local under = player.PlayerGui:GetGuiObjectsAtPosition(point.X, point.Y)
 print("IR_UI_CLICK_GEOMETRY", viewport, inset, row.AbsolutePosition, row.AbsoluteSize,
  scroll.AbsolutePosition, scroll.AbsoluteSize, scroll.CanvasPosition, point,
  under[1] and under[1]:GetFullName(), row.Visible, panel.Visible)
 click(row)
 task.wait(0.5)
 local nextState = stateController.GetSnapshot()
 print("IR_UI_CLICK_DIAGNOSTIC", activated, down, up, destroyed,
  bag.Inventory.Equip.Visible, row.Parent ~= nil,
  scroll:FindFirstChild("TrainingSword") == row, nextState.StateRevision,
  bag.Inventory.Selected.Text)
 assert(bag.Inventory.Equip.Visible, "equip button did not become visible")
end)
print("IR_UI_CLICK_CLIENT_RESULT", ok, err)
report:FireServer(ok, tostring(err))
]==]
client.Parent = game.StarterPlayer.StarterPlayerScripts

local runner = Instance.new("Script")
runner.Name = "ReviewUIClickServer"
runner.Source = [==[
local players = game:GetService("Players")
local test = game:GetService("StudioTestService")
local server = game.ServerScriptService:WaitForChild("Server")
local store = require(server.ProfileStore)
local schema = require(server.ProfileSchema)
local remote = game.ReplicatedStorage:WaitForChild("ReviewUIClickResult")
local player = players:GetPlayers()[1] or players.PlayerAdded:Wait()
local profile = schema.New(os.time())
profile.Inventory.TrainingSword = 1
store.TestSetMock(player.UserId, profile)
server.Main.Enabled = true
local received = false
remote.OnServerEvent:Connect(function(from, ok, err)
 if from ~= player or received then return end
 received = true
 print("IR_UI_CLICK_RESULT", ok, err)
 test:EndTest(if ok then "PASS" else "FAIL")
end)
task.delay(50, function()
 if not received then print("IR_UI_CLICK_RESULT false timeout"); test:EndTest("TIMEOUT") end
end)
]==]
runner.Parent = server
local ok, result = pcall(function() return test:ExecutePlayModeAsync("ReviewUIClick") end)
print("IR_UI_CLICK_LAUNCH", ok, result)
