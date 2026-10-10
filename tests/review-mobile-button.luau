-- Studio virtual mouse on the mobile-only button: wiring check, not touch hardware.
local test = game:GetService("StudioTestService")
local spawn = Instance.new("SpawnLocation")
spawn.Name = "ReviewMobilePlayerSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0, 0)
spawn.Parent = workspace
local points = Instance.new("Folder")
points.Name = "EnemySpawns"
points.Parent = workspace
local point = Instance.new("Part")
point.Name = "ReviewMobileSlimeSpawn"
point.Size = Vector3.new(2, 0.2, 2)
point.Anchored = true
point.CanCollide = false
point.CanQuery = false
point.Position = Vector3.new(0, 0, -6)
point:SetAttribute("EnemyId", "Slime")
point.Parent = points
local remote = Instance.new("RemoteEvent")
remote.Name = "ReviewMobileAttack"
remote.Parent = game:GetService("ReplicatedStorage")
local client = Instance.new("LocalScript")
client.Name = "ReviewMobileAttackClient"
client.Source = [==[
local players = game:GetService("Players")
local input = game:GetService("UserInputService")
local guiService = game:GetService("GuiService")
local remote = game.ReplicatedStorage:WaitForChild("ReviewMobileAttack")
local player = players.LocalPlayer
remote.OnClientEvent:Connect(function(target)
 local gui = player.PlayerGui:WaitForChild("IdleRaidUI", 20)
 local button = gui and gui:FindFirstChild("TouchAttack")
 if not button then remote:FireServer(false, "button missing") return end
 button.Visible = true -- test only: desktop virtual mouse can activate the mobile route.
 button.AnchorPoint = Vector2.zero
 button.Position = UDim2.fromOffset(350, 250) -- CLI Studio virtual pointer uses a fixed 800px surface.
 button.ZIndex = 30
 button.Activated:Connect(function()
  local current = workspace.CurrentCamera
  local p = RaycastParams.new()
  p.FilterType = Enum.RaycastFilterType.Exclude
  p.FilterDescendantsInstances = if player.Character then { player.Character } else {}
  local nowHit = workspace:Raycast(current.CFrame.Position, current.CFrame.LookVector * 500, p)
  print("IR_REVIEW_R09_UI_ACTIVATED", nowHit and nowHit.Instance:GetFullName(), current.CameraType)
 end)
 local body = target and target.PrimaryPart
 if not body then remote:FireServer(false, "enemy missing") return end
 local camera = workspace.CurrentCamera
 camera.CameraType = Enum.CameraType.Scriptable
 local params = RaycastParams.new()
 params.FilterType = Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
 local hit
 for _, offset in ipairs({ Vector3.new(0, 8, 0), Vector3.new(0, 4, 3), Vector3.new(0, 6, 8), Vector3.new(0, 1, 8) }) do
  params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
  camera = workspace.CurrentCamera
  camera.CameraType = Enum.CameraType.Scriptable
  camera.CFrame = CFrame.lookAt(body.Position + offset, body.Position)
  task.wait(0.02)
  hit = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 500, params)
  if hit and hit.Instance:IsDescendantOf(target) then break end
 end
 print("IR_REVIEW_R09_RAY", hit and hit.Instance:GetFullName(), body.Position, camera.CFrame.Position, hit and hit.Position, button.AbsolutePosition, button.AbsoluteSize)
 assert(hit and hit.Instance:IsDescendantOf(target), "camera center cannot see enemy")
 local point = button.AbsolutePosition + button.AbsoluteSize / 2 + guiService:GetGuiInset()
 local virtual = input:CreateVirtualInput()
 local under = player.PlayerGui:GetGuiObjectsAtPosition(point.X, point.Y)
 print("IR_REVIEW_R09_UI_TOP", under[1] and under[1]:GetFullName())
 for attempt = 1, 10 do
  camera = workspace.CurrentCamera
  camera.CameraType = Enum.CameraType.Scriptable
  camera.CFrame = CFrame.lookAt(body.Position + Vector3.new(0, 8, 0), body.Position)
  task.wait(0.02)
  params.FilterDescendantsInstances = if player.Character then { player.Character } else {}
  local aimed = workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 500, params)
  if aimed and aimed.Instance:IsDescendantOf(target) then
   virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, true, 0)
   task.wait(0.08)
   virtual:SendMouseButton(point, Enum.UserInputType.MouseButton1, false, 0)
  end
  task.wait(0.6)
  if (target:GetAttribute("Health") or 40) < 40 then break end
 end
 remote:FireServer(true, "button activated")
end)
]==]
client.Parent = game:GetService("StarterPlayer").StarterPlayerScripts.Client
local runner = Instance.new("Script")
runner.Name = "ReviewMobileAttackServer"
runner.Source = [==[
local players = game:GetService("Players")
local test = game:GetService("StudioTestService")
local remote = game.ReplicatedStorage:WaitForChild("ReviewMobileAttack")
local ok, err = pcall(function()
 local player = players:GetPlayers()[1] or players.PlayerAdded:Wait()
 local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root then
  local character = player.Character or player.CharacterAdded:Wait()
  root = character:WaitForChild("HumanoidRootPart")
 end
 local enemies = workspace:WaitForChild("Enemies", 20)
 local target
 local deadline = os.clock() + 20
 repeat
  for _, model in ipairs(enemies:GetChildren()) do
   if model:IsA("Model") and model:GetAttribute("EnemyId") == "Slime" then target = model break end
  end
  if not target then task.wait(0.1) end
 until target or os.clock() > deadline
 assert(target and target.PrimaryPart, "Slime missing")
 assert((root.Position - target.PrimaryPart.Position).Magnitude < 15, "test spawn outside attack range")
 local before = target:GetAttribute("Health")
 local attackRequests = 0
 local attackConnection = game.ReplicatedStorage.IdleRaidRemotes.BasicAttack.OnServerEvent:Connect(function(from, requested)
  if from == player then
   attackRequests += 1
   local liveRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
   local data = require(game.ServerScriptService.Server.PlayerDataService)
   local enemy = require(game.ServerScriptService.Server.EnemyService)
   local raid = require(game.ServerScriptService.Server.RaidService)
   print("IR_REVIEW_R09_REMOTE", requested and requested:GetFullName(),
    liveRoot and (liveRoot.Position - target.PrimaryPart.Position).Magnitude,
    data.GetProfile(player) and data.GetProfile(player).BreakthroughStage,
    data.GetFinalAttack(player), enemy.IsAliveEnemy(requested), raid.CanAttack(player, requested))
  end
 end)
 local received, detail
 local connection = remote.OnServerEvent:Connect(function(from, clicked, message)
  if from == player then received, detail = clicked, message end
 end)
 remote:FireClient(player, target)
 local limit = os.clock() + 10
 while received == nil and os.clock() < limit do task.wait(0.1) end
 connection:Disconnect()
 task.wait(0.5)
 attackConnection:Disconnect()
 local after = target:GetAttribute("Health")
 print("IR_REVIEW_R09_BUTTON", received, detail, before, after, attackRequests)
 assert(received and typeof(after) == "number" and after < before, "button did not damage enemy")
end)
print("IR_REVIEW_R09_RESULT", ok, err)
test:EndTest(if ok then "PASS" else "FAIL")
]==]
runner.Parent = game:GetService("ServerScriptService")
local ok, result = pcall(function() return test:ExecutePlayModeAsync("ReviewMobileButton") end)
print("IR_REVIEW_R09_LAUNCH", ok, result)
