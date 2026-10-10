-- Studio virtual-input regression. Isolated memory profile; production modules are unchanged by the test.
local test = game:GetService("StudioTestService")
local server = game:GetService("ServerScriptService"):WaitForChild("Server")
server.Main.Disabled = true

local result = Instance.new("RemoteEvent")
result.Name = "ReviewUIFixedResult"
result.Parent = game.ReplicatedStorage
local step = Instance.new("RemoteEvent")
step.Name = "ReviewUIFixedStep"
step.Parent = game.ReplicatedStorage
local ack = Instance.new("RemoteEvent")
ack.Name = "ReviewUIFixedAck"
ack.Parent = game.ReplicatedStorage

local client = Instance.new("LocalScript")
client.Name = "ReviewUIFixedClient"
client.Source = [==[
local players = game:GetService("Players")
local input = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")
local player = players.LocalPlayer
local result = game.ReplicatedStorage:WaitForChild("ReviewUIFixedResult")
local step = game.ReplicatedStorage:WaitForChild("ReviewUIFixedStep")
local ack = game.ReplicatedStorage:WaitForChild("ReviewUIFixedAck")
local stateController = require(script.Parent:WaitForChild("Client").StateController)
local ok, err = pcall(function()
 local deadline = os.clock() + 20
 while (not stateController.GetSnapshot() or not stateController.GetSnapshot().Ready) and os.clock() < deadline do task.wait(0.05) end
 local first = assert(stateController.GetSnapshot(), "no state")
 assert(first.Ready and first.Level == 1, "initial profile not ready/level 1")
 local gui = player.PlayerGui:WaitForChild("IdleRaidUI", 20)
 local panel = gui:WaitForChild("MenuPanel")
 local bag = panel:WaitForChild("BagPage")
 -- Open the page directly for this row-race test. BagMenu virtual input is tested separately.
 panel.Visible = true
 bag.Visible = true
 local scroll = bag.Inventory.Items
 local row = assert(scroll:WaitForChild("TrainingSword", 8), "missing TrainingSword")
 -- Studio sometimes resizes the Play viewport after the GUI first appears.
 local stableAt = os.clock()
 local lastPanel = panel.AbsolutePosition
 local layoutDeadline = os.clock() + 8
 while os.clock() - stableAt < 3 and os.clock() < layoutDeadline do
  task.wait(0.05)
  local nowPanel = panel.AbsolutePosition
  if (nowPanel - lastPanel).Magnitude > 1 then
   lastPanel = nowPanel
   stableAt = os.clock()
  end
 end
 assert(os.clock() - stableAt >= 3, "Studio Play viewport did not settle")
 print("IR_UI_FIXED_VIEWPORT_STABLE", panel.AbsolutePosition,
  workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize)
 local virtual = input:CreateVirtualInput()
 local destroyed, totalActivated, equipActivated = 0, 0, 0
 row.Destroying:Connect(function() destroyed += 1 end)
 row.Activated:Connect(function() totalActivated += 1 end)
 bag.Inventory.Equip.Activated:Connect(function() equipActivated += 1 end)
 local function point(button)
  return button.AbsolutePosition + button.AbsoluteSize / 2 + guiService:GetGuiInset()
 end
 local function press(button, down)
  virtual:SendMouseButton(point(button), Enum.UserInputType.MouseButton1, down, 0)
 end
 local function waitFor(predicate, label, seconds)
  local untilAt = os.clock() + seconds
  while not predicate() and os.clock() < untilAt do task.wait(0.02) end
  assert(predicate(), "timeout " .. label)
 end
 local scenarios = { "natural", "samefull", "quantity", "drop", "defense", "partial" }
 for index, scenario in ipairs(scenarios) do
  local before = stateController.GetSnapshot()
  local beforeRevision = before.StateRevision
  local beforeLevel = before.Level
  local previousActivated = totalActivated
  local beforePosition = row.AbsolutePosition
  local beforeLocalPosition = row.AbsolutePosition - scroll.AbsolutePosition
  local beforePanelPosition = panel.AbsolutePosition
  local heldPoint = point(row)
  local down = 0
  local downConnection = row.InputBegan:Connect(function(event)
   if event.UserInputType == Enum.UserInputType.MouseButton1 then down += 1 end
  end)
  virtual:SendMouseButton(heldPoint, Enum.UserInputType.MouseButton1, true, 0)
  waitFor(function() return down == 1 end, scenario .. " MouseDown", 2)
  step:FireServer(scenario)
  if scenario == "natural" then
   waitFor(function()
    local state = stateController.GetSnapshot()
    return state.StateRevision > beforeRevision and state.Level > beforeLevel
   end, "natural OnlineTraining levelup", 6)
  else
   waitFor(function() return stateController.GetSnapshot().StateRevision > beforeRevision end,
    scenario .. " state update", 4)
  end
  task.wait(0.04)
  assert(scroll:FindFirstChild("TrainingSword") == row and destroyed == 0,
   scenario .. " destroyed or replaced pressed row")
  local afterLocalPosition = row.AbsolutePosition - scroll.AbsolutePosition
  print("IR_UI_FIXED_POSITION", scenario, "row", beforePosition, row.AbsolutePosition,
   "panel", beforePanelPosition, panel.AbsolutePosition, "local", beforeLocalPosition, afterLocalPosition,
   "scroll", scroll.CanvasPosition)
  assert((afterLocalPosition - beforeLocalPosition).Magnitude <= 1,
   scenario .. " moved row within inventory list")
  virtual:SendMouseButton(heldPoint, Enum.UserInputType.MouseButton1, false, 0)
  waitFor(function() return totalActivated == previousActivated + 1 end, scenario .. " Activated", 2)
  downConnection:Disconnect()
  assert(bag.Inventory.Equip.Visible and bag.Inventory.Selected.Text:find("Training Sword", 1, true),
   scenario .. " selection or comparison missing")
  local state = stateController.GetSnapshot()
  if scenario == "quantity" then
   assert(row.Text:find("x2", 1, true), "quantity text did not update")
  elseif scenario == "drop" then
   assert(scroll:FindFirstChild("ClothArmor"), "new item row absent")
  elseif scenario == "defense" then
   assert(state.Equipment.Armor == "ClothArmor" and state.FinalDefense >= 2,
    "defense equip did not update")
  end
  local beforeEquip = equipActivated
  press(bag.Inventory.Equip, true)
  task.wait(0.04)
  press(bag.Inventory.Equip, false)
  waitFor(function() return equipActivated == beforeEquip + 1 end, scenario .. " Equip Activated", 2)
  waitFor(function() return stateController.GetSnapshot().Equipment.Weapon == "TrainingSword" end,
   scenario .. " server equip application", 3)
  local equippedRevision = stateController.GetSnapshot().StateRevision
  step:FireServer("unequip")
  waitFor(function()
   local latest = stateController.GetSnapshot()
   return latest.StateRevision > equippedRevision and latest.Equipment.Weapon == nil
  end, scenario .. " server unequip", 3)
  print("IR_UI_FIXED_SCENARIO", scenario, "rowSame", scroll:FindFirstChild("TrainingSword") == row,
   "destroyed", destroyed, "activated", totalActivated, "equipActivated", equipActivated,
   "revision", state.StateRevision, "level", state.Level, "quantity", row.Text,
   "selection", bag.Inventory.Selected.Text)
  if scenario == "natural" then
   local stopRevision = stateController.GetSnapshot().StateRevision
   step:FireServer("stoptraining")
   waitFor(function()
    local latest = stateController.GetSnapshot()
    return latest.StateRevision > stopRevision and latest.TrainingEnabled == false
   end, "stop natural training", 3)
  end
 end
 assert(totalActivated == #scenarios and equipActivated == #scenarios and destroyed == 0,
  "input/event count mismatch")
 local verification
 local connection = ack.OnClientEvent:Connect(function(value) verification = value end)
 step:FireServer("verify")
 waitFor(function() return verification ~= nil end, "server equip verification", 3)
 connection:Disconnect()
 assert(verification.Requests == #scenarios and verification.Weapon == nil,
  "server equip request/equipment mismatch")
 print("IR_UI_FIXED_EQUIP_SERVER", verification.Requests, verification.Weapon)
 -- Real removal during a press must invalidate selection and prevent the equip request.
 local beforeRequests = verification.Requests
 local down = 0
 local downConnection = row.InputBegan:Connect(function(event)
  if event.UserInputType == Enum.UserInputType.MouseButton1 then down += 1 end
 end)
 press(row, true)
 waitFor(function() return down == 1 end, "removal MouseDown", 2)
 local revision = stateController.GetSnapshot().StateRevision
 step:FireServer("remove")
 waitFor(function() return stateController.GetSnapshot().StateRevision > revision end, "item removal", 4)
 assert(scroll:FindFirstChild("TrainingSword") == nil and not bag.Inventory.Equip.Visible,
  "removed item still selectable")
 press(row, false)
 downConnection:Disconnect()
 task.wait(0.15)
 verification = nil
 connection = ack.OnClientEvent:Connect(function(value) verification = value end)
 step:FireServer("verify")
 waitFor(function() return verification ~= nil end, "server removal verification", 3)
 connection:Disconnect()
 assert(verification.Requests == beforeRequests, "removed item sent equip request")
 print("IR_UI_FIXED_REMOVAL", destroyed, verification.Requests, bag.Inventory.Equip.Visible)
end)
print("IR_UI_FIXED_CLIENT_RESULT", ok, err)
result:FireServer(ok, tostring(err))
]==]
client.Parent = game.StarterPlayer.StarterPlayerScripts

local runner = Instance.new("Script")
runner.Name = "ReviewUIFixedServer"
runner.Source = [==[
local players = game:GetService("Players")
local test = game:GetService("StudioTestService")
local server = game.ServerScriptService:WaitForChild("Server")
local store = require(server.ProfileStore)
local schema = require(server.ProfileSchema)
local result = game.ReplicatedStorage:WaitForChild("ReviewUIFixedResult")
local step = game.ReplicatedStorage:WaitForChild("ReviewUIFixedStep")
local ack = game.ReplicatedStorage:WaitForChild("ReviewUIFixedAck")
local player = players:GetPlayers()[1] or players.PlayerAdded:Wait()
local profile = schema.New(os.time())
profile.Inventory.TrainingSword = 1
profile.LifetimeTrainingPower = 99
profile.AvailableTrainingPower = 99
profile.TrainingEnabled = false
store.TestSetMock(player.UserId, profile)
server.Main.Enabled = true
local requests = 0
local equip = game.ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("EquipItem")
equip.OnServerEvent:Connect(function(from, itemId)
 if from == player then requests += 1; print("IR_UI_FIXED_SERVER_EQUIP", requests, itemId) end
end)
step.OnServerEvent:Connect(function(from, scenario)
 if from ~= player then return end
 local sync = require(server.StateSyncService)
 local inventory = require(server.InventoryService)
 local equipment = require(server.EquipmentService)
 local training = require(server.TrainingService)
 local profileNow = store.Get(from)
 if scenario == "natural" then
  training.SetEnabled(from, true)
  training.ResetClock(from)
 elseif scenario == "stoptraining" then training.SetEnabled(from, false)
 elseif scenario == "samefull" then sync.Push(from)
 elseif scenario == "quantity" then inventory.AddItem(from, "TrainingSword", 1)
 elseif scenario == "drop" then inventory.AddItem(from, "ClothArmor", 1)
 elseif scenario == "defense" then
  assert(equipment.EquipItem(from, "ClothArmor"))
 elseif scenario == "partial" then sync.PushGrowth(from)
 elseif scenario == "unequip" then
  assert(equipment.Unequip(from, "Weapon"))
 elseif scenario == "remove" then
  profileNow.Inventory.TrainingSword = nil
  profileNow.Equipment.Weapon = nil
  require(server.PlayerDataService).RecalculateStats(from)
 elseif scenario == "verify" then
  ack:FireClient(from, { Requests = requests, Weapon = profileNow.Equipment.Weapon })
 end
end)
local done = false
result.OnServerEvent:Connect(function(from, ok, err)
 if from ~= player or done then return end
 done = true
 print("IR_UI_FIXED_RESULT", ok, err)
 test:EndTest(if ok then "PASS" else "FAIL")
end)
task.delay(80, function()
 if not done then print("IR_UI_FIXED_RESULT false timeout"); test:EndTest("TIMEOUT") end
end)
]==]
runner.Parent = server
local ok, launchResult = pcall(function() return test:ExecutePlayModeAsync("ReviewUIFixed") end)
print("IR_UI_FIXED_LAUNCH", ok, launchResult)
