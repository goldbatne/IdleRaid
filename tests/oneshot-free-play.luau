-- UI-driven Studio Play test. No debug grants or profile mutation.
local StudioTestService = game:GetService("StudioTestService")
local StarterPlayer = game:GetService("StarterPlayer")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spawn = Instance.new("SpawnLocation")
spawn.Name = "OneShotFreePlaySpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0, 0)
spawn.Parent = workspace

local report = Instance.new("RemoteEvent")
report.Name = "OneShotFreePlayReport"
report.Parent = ReplicatedStorage

local client = Instance.new("LocalScript")
client.Name = "OneShotFreePlayClient"
client.Source = [==[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local report = ReplicatedStorage:WaitForChild("OneShotFreePlayReport")
local stateController = require(script.Parent:WaitForChild("Client").StateController)
local autoController = require(script.Parent.Client.AutoCombatController)
local growthConfig = require(ReplicatedStorage.Shared.GrowthConfig)
local itemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local virtual = UserInputService:CreateVirtualInput()
local gui = player.PlayerGui:WaitForChild("IdleRaidUI", 20)
local nav = gui:WaitForChild("MenuNavigation")
local panel = gui:WaitForChild("MenuPanel")
local started = os.clock()
local patterns, dashes = 0, 0
local gameConfig = require(ReplicatedStorage.Shared.GameConfig)
local function snapshot() return stateController.GetSnapshot() end
local function waitFor(predicate, seconds, label)
 local deadline = os.clock() + seconds
 repeat
  if predicate() then return end
  task.wait(0.1)
 until os.clock() > deadline
 error("Timeout: " .. label)
end
local function click(button)
 assert(button and button:IsA("GuiButton") and button.Visible, "button unavailable")
 local inset = GuiService:GetGuiInset()
 local position = button.AbsolutePosition + button.AbsoluteSize / 2 + inset
 virtual:SendMouseButton(position, Enum.UserInputType.MouseButton1, true, 0)
 task.wait()
 virtual:SendMouseButton(position, Enum.UserInputType.MouseButton1, false, 0)
 task.wait(0.18)
end
local function openPage(name)
 local page = panel:FindFirstChild(name .. "Page")
 if not panel.Visible or not page or not page.Visible then click(nav[name .. "Menu"]) end
end
local function closePage()
 if panel.Visible then click(panel.CloseMenu) end
end
local function tapKey(key)
 virtual:SendKey(true, key, false)
 task.wait()
 virtual:SendKey(false, key, false)
end
local function dodge(kind, first, second)
 patterns += 1
 local state = snapshot()
 if not state or not state.Raid or state.Raid.Status ~= "Active" then return end
 local character = player.Character
 local root = character and character:FindFirstChild("HumanoidRootPart")
 local camera = workspace.CurrentCamera
 if not root or not camera then return end
 local center = gameConfig.Raid.ArenaCenter
 local desired
 if kind == "Charge" and typeof(first) == "Vector3" and typeof(second) == "Vector3" then
  local line = Vector3.new(second.X - first.X, 0, second.Z - first.Z)
  if line.Magnitude < 1 then return end
  local perpendicular = Vector3.new(-line.Z, 0, line.X).Unit
  local leftGoal = root.Position + perpendicular * 22
  local rightGoal = root.Position - perpendicular * 22
  desired = if (leftGoal - center).Magnitude < (rightGoal - center).Magnitude
   then perpendicular else -perpendicular
 else
  local offset = Vector3.new(root.Position.X - center.X, 0, root.Position.Z - center.Z)
  desired = if offset.Magnitude > 24 then -offset.Unit
   else Vector3.new(math.cos(patterns * 2), 0, math.sin(patterns * 2))
 end
 local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z).Unit
 local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z).Unit
 local options = {
  { Key = Enum.KeyCode.W, Vector = forward },
  { Key = Enum.KeyCode.S, Vector = -forward },
  { Key = Enum.KeyCode.D, Vector = right },
  { Key = Enum.KeyCode.A, Vector = -right },
 }
 local choice, score
 for _, option in ipairs(options) do
  local dot = option.Vector:Dot(desired)
  if not score or dot > score then choice, score = option.Key, dot end
 end
 local key = choice
 task.spawn(function()
  virtual:SendKey(true, key, false)
  task.wait(if kind == "Slam" then 0.55 else 0.32)
  tapKey(Enum.KeyCode.Q)
  dashes += 1
  task.wait(0.18)
  local raid = snapshot().Raid or {}
  print("IR_FREE_DASH", kind, raid.DashReadyAt or 0, workspace:GetServerTimeNow())
  task.wait(if kind == "Slam" then 0.48 else 0.62)
  virtual:SendKey(false, key, false)
 end)
end
ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("RaidTelegraph").OnClientEvent:Connect(dodge)
local ok, err = pcall(function()
 waitFor(function() return snapshot() and snapshot().Ready end, 20, "ready")
 local initial = snapshot()
 assert(not initial.StudioSandbox and initial.BreakthroughStage == 1 and initial.Gold == 0
  and #(initial.Inventory or {}) == 0, "not a normal new profile")
 print("IR_FREE_PASS normal_profile")
 waitFor(function()
  local character = player.Character
  local root = character and character:FindFirstChild("HumanoidRootPart")
  local humanoid = character and character:FindFirstChildOfClass("Humanoid")
  return root and humanoid and humanoid.Health > 0
 end, 20, "spawned character")
 task.wait(1)
 click(gui.AutoCombat)
 task.wait(0.4)
 if not autoController.GetEnabled() then
  print("IR_FREE_NOTE auto_button_not_activated_retry_key")
  tapKey(Enum.KeyCode.T)
 end
 waitFor(function() return autoController.GetEnabled() end, 5, "auto enabled")
 task.wait(2)
 if not autoController.GetEnabled() then tapKey(Enum.KeyCode.T) end
 waitFor(function() return snapshot().Gold > 0 end, 120, "first actual kill and Gold")
 print("IR_FREE_PASS actual_hunt_reward", snapshot().Gold, snapshot().LifetimeTrainingPower)
 local equipped = false
 local facility = false
 local deadline = os.clock() + 900
 while os.clock() < deadline and (snapshot().BreakthroughStage or 1) < 10 do
  local state = snapshot()
  if not equipped then
   local stack = (state.Inventory or {})[1]
   if stack then
    openPage("Bag")
    local bag = panel.BagPage
    local row = bag.Inventory.Items:FindFirstChild(stack.ItemId)
    if row then
     click(row)
     assert(string.find(bag.Inventory.Selected.Text, "→", 1, true), "missing equipment compare")
     local before = snapshot().FinalAttack
     click(bag.Inventory.Equip)
     waitFor(function() return (snapshot().Equipment or {})[itemConfig.Items[stack.ItemId].Type] == stack.ItemId end, 8, "equip")
     equipped = true
     print("IR_FREE_PASS actual_drop_compare_equip", stack.ItemId, snapshot().FinalAttack)
    end
    closePage()
   end
  end
  state = snapshot()
  if not facility and (state.Gold or 0) >= growthConfig.Facilities[2].GoldCost then
   openPage("Growth")
   click(panel.GrowthPage.Tab2)
   click(panel.GrowthPage.Growth2.FacilityBuy)
   waitFor(function() return snapshot().TrainingFacilityTier == 2 end, 8, "facility")
   facility = true
   print("IR_FREE_PASS actual_gold_facility", snapshot().BaseTrainingRate)
   closePage()
  end
  state = snapshot()
  if (state.AvailableTrainingPower or 0) >= (state.BreakthroughCost or math.huge) then
   local before = state.BreakthroughStage
   openPage("Growth")
   local growth = panel.GrowthPage
   click(growth.Tab1)
   growth.Growth1.CanvasPosition = Vector2.new(0, 0)
   task.wait(0.1)
   click(growth.Growth1.Step1)
   waitFor(function() return growth.Growth1.ConfirmBreakthrough.Visible end, 8, "breakthrough preview")
   growth.Growth1.CanvasPosition = Vector2.new(0, 160)
   task.wait(0.1)
   click(growth.Growth1.ConfirmBreakthrough)
   waitFor(function() return snapshot().BreakthroughStage == before + 1 end, 8, "breakthrough")
   print("IR_FREE_STAGE", snapshot().BreakthroughStage, snapshot().Level, math.floor(os.clock() - started))
   closePage()
  end
  task.wait(0.4)
 end
 assert(snapshot().BreakthroughStage == 10, "did not reach first gate")
 assert(equipped, "no item equipped during free path")
 assert(facility, "facility not purchased during free path")
 print("IR_FREE_PASS gate_reached", math.floor(os.clock() - started))
 openPage("Raid")
 click(panel.RaidPage.Gate10)
 waitFor(function() return snapshot().Raid and snapshot().Raid.IsParticipant end, 12, "raid join")
 waitFor(function() return snapshot().Raid.Status == "Active" end, 15, "raid active")
 print("IR_FREE_PASS raid_active")
 waitFor(function()
  local status = snapshot().Raid and snapshot().Raid.Status
  return status == "Clear" or status == "Failed"
 end, 180, "raid result")
 local result = snapshot().Raid.Status
 print("IR_FREE_RAID_RESULT", result, "patterns", patterns, "dash_inputs", dashes,
  "boss_hp", (snapshot().Raid or {}).BossHealth or -1, "player_hp", snapshot().Health or -1,
  "elapsed", math.floor(os.clock() - started))
 assert(result == "Clear", "actual boss not defeated")
 assert((snapshot().ClearedRaidGates or {}).Gate10, "server gate record missing")
 print("IR_FREE_PASS gate_clear", math.floor(os.clock() - started))
end)
print("IR_FREE_CLIENT_RESULT", ok, err)
report:FireServer(ok, tostring(err))
]==]
client.Parent = StarterPlayer.StarterPlayerScripts

local server = Instance.new("Script")
server.Name = "OneShotFreePlayServer"
server.Source = [==[
local report = game.ReplicatedStorage.OneShotFreePlayReport
local done = false
report.OnServerEvent:Connect(function(player, clientOk, clientError)
 if done then return end
 done = true
 local state = game.ServerScriptService.Server.DebugGetPlayerState:Invoke(player)
 local serverOk = state and state.Ready and state.StudioSandbox == false
  and state.BreakthroughStage == 10 and state.TrainingFacilityTier == 2
  and (state.ClearedRaidGates or {}).Gate10 == true
 local ok = clientOk == true and serverOk == true
 print("IR_FREE_SERVER_RESULT", ok, clientError, state and state.BreakthroughStage)
 game:GetService("StudioTestService"):EndTest(if ok then "PASS" else "FAIL")
end)
task.delay(1100, function()
 if not done then
  print("IR_FREE_SERVER_RESULT false timeout")
  game:GetService("StudioTestService"):EndTest("TIMEOUT")
 end
end)
]==]
server.Parent = ServerScriptService
local ok, result = pcall(function() return StudioTestService:ExecutePlayModeAsync("OneShotFreePlay") end)
print("IR_FREE_LAUNCH", ok, result)
