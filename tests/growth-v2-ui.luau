local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spawn = Instance.new("SpawnLocation")
spawn.Name = "GrowthUITestSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0, 0)
spawn.Parent = workspace

local report = Instance.new("RemoteEvent")
report.Name = "GrowthUITestReport"
report.Parent = ReplicatedStorage

local client = Instance.new("LocalScript")
client.Name = "GrowthUITestClient"
client.Source = [==[
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local report = ReplicatedStorage:WaitForChild("GrowthUITestReport")
local clientFolder = script.Parent:WaitForChild("Client", 20)
assert(clientFolder, "Client folder missing")
local stateController = require(clientFolder.StateController)
local autoController = require(clientFolder.AutoCombatController)
local function waitFor(predicate, label)
	local deadline = os.clock() + 15
	repeat
		if predicate() then return end
		task.wait(0.1)
	until os.clock() > deadline
	error("Timeout: " .. label)
end
local function snapshot()
	return stateController.GetSnapshot()
end
local ok, err = pcall(function()
	waitFor(function() return snapshot() and snapshot().Ready end, "profile ready")
	local virtual = UserInputService:CreateVirtualInput()
	assert(virtual, "VirtualInput unavailable")
	local gui = player.PlayerGui:WaitForChild("IdleRaidUI", 20)
	assert(gui, "IdleRaidUI missing")
	local nav = gui:WaitForChild("MenuNavigation")
	local panel = gui:WaitForChild("MenuPanel")
	local function click(button)
		assert(button and button:IsA("GuiButton") and button.Visible and button.AbsoluteSize.X > 0
			and button.AbsoluteSize.Y > 0, "button not visible: " .. (button and button.Name or "nil"))
		local inset = GuiService:GetGuiInset()
		local position = button.AbsolutePosition + button.AbsoluteSize / 2 + inset

		virtual:SendMouseButton(position, Enum.UserInputType.MouseButton1, true, 0)
		task.wait()
		virtual:SendMouseButton(position, Enum.UserInputType.MouseButton1, false, 0)
		task.wait(0.25)
	end
	click(gui.AutoCombat)
	waitFor(function() return autoController.GetEnabled() end, "auto on")
	virtual:SendKey(true, Enum.KeyCode.T, false)
	task.wait()
	virtual:SendKey(false, Enum.KeyCode.T, false)
	waitFor(function() return not autoController.GetEnabled() end, "auto off by T")
	print("IR_UI_PASS auto_button")
	click(nav.DebugMenu)
	waitFor(function() return panel.Visible and panel.DebugPage.Visible end, "debug menu")
	click(panel.DebugPage.Grant1)
	waitFor(function() return snapshot().AvailableTrainingPower >= 10000 end, "debug power")
	print("IR_UI_PASS debug_grant")
	click(nav.GrowthMenu)
	waitFor(function() return panel.GrowthPage.Visible end, "growth menu")
	local growth = panel.GrowthPage
	click(growth.Growth1.Step1)
	waitFor(function() return growth.Growth1.ConfirmBreakthrough.Visible end, "free preview")
	growth.Growth1.CanvasPosition = Vector2.new(0, 160)
	task.wait(0.1)
	click(growth.Growth1.ConfirmBreakthrough)
	waitFor(function() return snapshot().BreakthroughStage == 2 end, "free breakthrough")
	print("IR_UI_PASS free_breakthrough")
	click(nav.DebugMenu)
	click(panel.DebugPage.Grant2)
	waitFor(function() return snapshot().Gold >= 1000 end, "debug gold")
	click(panel.DebugPage.GrantTrainingSword)
	waitFor(function()
		for _, stack in ipairs(snapshot().Inventory or {}) do
			if stack.ItemId == "TrainingSword" then return true end
		end
		return false
	end, "debug item")
	click(nav.GrowthMenu)
	click(growth.Tab2)
	click(growth.Growth2.FacilityBuy)
	waitFor(function() return snapshot().TrainingFacilityTier == 2 end, "facility")
	print("IR_UI_PASS facility_purchase")
	click(nav.BagMenu)
	local bag = panel.BagPage
	waitFor(function() return bag.Inventory.Items:FindFirstChild("TrainingSword") ~= nil end, "bag item")
	click(bag.Inventory.Items.TrainingSword)
	waitFor(function() return bag.Inventory.Equip.Visible end, "equip button")
	local attackBefore = snapshot().FinalAttack
	click(bag.Inventory.Equip)
	waitFor(function() return snapshot().Equipment.Weapon == "TrainingSword" end, "equipment")
	assert(snapshot().FinalAttack == attackBefore + 3, "equipment attack")
	print("IR_UI_PASS equip")
	click(bag.Equipment.UnequipWeapon)
	waitFor(function() return snapshot().Equipment.Weapon == nil end, "unequip")
	assert(snapshot().FinalAttack == attackBefore, "unequip attack")
	print("IR_UI_PASS unequip")
	click(nav.DebugMenu)
	click(panel.DebugPage.Grant5)
	waitFor(function() return snapshot().BreakthroughTickets["5"] >= 1 end, "ticket grant")
	click(nav.GrowthMenu)
	click(growth.Tab1)
	click(growth.Growth1.Step5)
	waitFor(function() return growth.Growth1.ConfirmBreakthrough.Visible end, "ticket preview")
	growth.Growth1.CanvasPosition = Vector2.new(0, 160)
	task.wait(0.1)
	click(growth.Growth1.ConfirmBreakthrough)
	waitFor(function() return snapshot().BreakthroughStage == 7 end, "ticket breakthrough")
	print("IR_UI_PASS ticket_breakthrough")
	click(nav.RaidMenu)
	click(panel.RaidPage.Gate10)
	waitFor(function() return snapshot().Raid and snapshot().Raid.IsParticipant end, "raid join")
	print("IR_UI_PASS raid_join")
end)
print("IR_UI_CLIENT_RESULT", ok, err)
report:FireServer(ok, tostring(err))
]==]
client.Parent = StarterPlayer.StarterPlayerScripts

local server = Instance.new("Script")
server.Name = "GrowthUITestServer"
server.Source = [==[
local Players = game:GetService("Players")
local StudioTestService = game:GetService("StudioTestService")
local report = game.ReplicatedStorage.GrowthUITestReport
local done = false
report.OnServerEvent:Connect(function(player, clientOk, clientError)
	if done then return end
	done = true
	local state = game.ServerScriptService.Server.DebugGetPlayerState:Invoke(player)
	local serverOk = state and state.Ready and state.BreakthroughStage == 7
		and state.TrainingFacilityTier == 2 and state.Equipment.Weapon == nil
	local ok = clientOk == true and serverOk == true
	print("IR_UI_SERVER_RESULT", ok, clientError, state and state.BreakthroughStage)
	StudioTestService:EndTest(if ok then "PASS" else "FAIL")
end)
task.delay(80, function()
	if not done then print("IR_UI_SERVER_RESULT false timeout") StudioTestService:EndTest("TIMEOUT") end
end)
]==]
server.Parent = ServerScriptService

local ok, result = pcall(function() return StudioTestService:ExecutePlayModeAsync("GrowthV2UI") end)
print("IR_UI_LAUNCH", ok, result)
