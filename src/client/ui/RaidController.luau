local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local UiStyle = require(script.Parent.UiStyle)

local RaidController = {}

local function makeMarker(kind: string, first: Vector3, second, third, lifetime: number)
	local marker = Instance.new("Part")
	marker.Name = "RaidTelegraph"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanTouch = false
	marker.CanQuery = false
	marker.Material = Enum.Material.Neon
	marker.Transparency = 0.3
	if kind == "Slam" then
		local radius = second
		marker.Color = Color3.fromRGB(255, 155, 45)
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(0.16, radius * 2, radius * 2)
		marker.CFrame = CFrame.new(first + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	elseif kind == "Charge" then
		local destination = second
		local width = third
		local flatFirst = Vector3.new(first.X, GameConfig.Raid.ArenaCenter.Y + 0.12, first.Z)
		local flatEnd = Vector3.new(destination.X, GameConfig.Raid.ArenaCenter.Y + 0.12, destination.Z)
		marker.Color = Color3.fromRGB(200, 80, 250)
		marker.Size = Vector3.new(width, 0.16, (flatEnd - flatFirst).Magnitude)
		marker.CFrame = CFrame.lookAt((flatFirst + flatEnd) / 2, flatEnd)
	else
		marker:Destroy()
		return
	end
	marker.Parent = Workspace
	task.delay(math.max(0, lifetime - GameConfig.Raid.WarningFlashTime), function()
		if marker.Parent then
			marker.Color = Color3.fromRGB(255, 35, 35)
			marker.Transparency = 0.05
		end
	end)
	task.delay(lifetime, function() marker:Destroy() end)
end

local function makeBar(parent: Instance, name: string, position: UDim2, color: Color3)
	local bar = Instance.new("Frame")
	bar.Name = name
	bar.Size = UDim2.new(1, -20, 0, 12)
	bar.Position = position
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = UiStyle.Colors.Surface
	UiStyle.Corner(bar, 6)
	bar.Parent = parent
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = color
	UiStyle.Corner(fill, 6)
	fill.Parent = bar
	return fill
end

local function makeFeedback(gui: ScreenGui, name: string, position: UDim2, color: Color3)
	local label = UiStyle.Text(gui, name, "", UDim2.new(1, -24, 0, 42), position)
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 27
	label.TextColor3 = color
	label.Visible = false
	return label
end

function RaidController.Start(gui: ScreenGui, stateController, dashController)
	local remotes = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
	local join = remotes:WaitForChild("JoinRaid")
	local raidButton = UiStyle.Button(gui, "RaidButton", "RAID", UDim2.fromOffset(96, 44), UDim2.new(1, -12, 0, 116))
	raidButton.AnchorPoint = Vector2.new(1, 0)
	raidButton.Activated:Connect(function() join:FireServer() end)

	local dashButton = UiStyle.Button(gui, "DashButton", "DASH Q", UDim2.fromOffset(108, 56), UDim2.new(1, -12, 1, -80))
	dashButton.AnchorPoint = Vector2.new(1, 0)
	dashButton.Visible = false
	dashButton.Activated:Connect(dashController.Request)

	local panel = Instance.new("Frame")
	panel.Name = "RaidPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 204)
	panel.Size = UDim2.new(1, -24, 0, 160)
	panel.BackgroundColor3 = UiStyle.Colors.Panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	UiStyle.Corner(panel, 10)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 160)
	limit.Parent = panel
	panel.Parent = gui

	local title = UiStyle.Text(panel, "BossName", "Slime King", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 6))
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Center
	local bossHp = UiStyle.Text(panel, "BossHealth", "HP -- / --", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 30))
	bossHp.TextXAlignment = Enum.TextXAlignment.Center
	local bossFill = makeBar(panel, "BossBar", UDim2.fromOffset(10, 51), Color3.fromRGB(224, 78, 78))
	local health = UiStyle.Text(panel, "PlayerHealth", "Health: 100 / 100", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 72))
	local healthFill = makeBar(panel, "HealthBar", UDim2.fromOffset(10, 95), UiStyle.Colors.Accent)
	local status = UiStyle.Text(panel, "RaidStatus", "Gathering", UDim2.new(0.5, -10, 0, 24), UDim2.fromOffset(10, 120))
	local cooldown = UiStyle.Text(panel, "DashCooldown", "Dash: Ready", UDim2.new(0.5, -10, 0, 24), UDim2.new(0.5, 0, 0, 120))
	cooldown.TextXAlignment = Enum.TextXAlignment.Right

	local warning = makeFeedback(gui, "RaidWarning", UDim2.new(0.5, 0, 0, 166), Color3.fromRGB(255, 145, 65))
	local taken = makeFeedback(gui, "TakenDamage", UDim2.new(0.5, 0, 0.62, 0), Color3.fromRGB(255, 70, 70))
	local dealt = makeFeedback(gui, "BossDamage", UDim2.new(0.5, 0, 0, 366), Color3.fromRGB(255, 235, 120))
	local result = makeFeedback(gui, "RaidResult", UDim2.new(0.5, 0, 0.5, -30), UiStyle.Colors.Text)
	result.TextSize = 32
	result.Size = UDim2.new(1, -24, 0, 60)

	local lastMembership
	local dashReadyAt = 0
	local active = false
	local defeated = false
	stateController.Subscribe(function(state)
		local raid = state.Raid or {}
		raidButton.Visible = not raid.IsParticipant
		dashButton.Visible = raid.IsParticipant == true
		if lastMembership ~= raid.IsParticipant then
			lastMembership = raid.IsParticipant
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, not raid.IsParticipant)
			end)
		end
		panel.Visible = raid.IsParticipant == true
		result.Visible = raid.IsParticipant and (raid.Status == "Clear" or raid.Status == "Failed") or false
		active = raid.Status == "Active"
		defeated = raid.Defeated == true
		dashReadyAt = raid.DashReadyAt or 0
		if not raid.IsParticipant then
			warning.Visible = false
			return
		end
		title.Text = raid.BossName or "Slime King"
		local maxHp = raid.BossMaxHealth or 0
		local hp = raid.BossHealth or 0
		bossHp.Text = string.format("HP %d / %d", hp, maxHp)
		bossFill.Size = UDim2.fromScale(if maxHp > 0 then math.clamp(hp / maxHp, 0, 1) else 0, 1)
		local maxHealth = math.max(1, state.MaxHealth or 100)
		local currentHealth = state.Health or 0
		health.Text = string.format("Health: %d / %d", currentHealth, maxHealth)
		local ratio = math.clamp(currentHealth / maxHealth, 0, 1)
		healthFill.Size = UDim2.fromScale(ratio, 1)
		healthFill.BackgroundColor3 = if ratio <= 0.3 then Color3.fromRGB(230, 70, 70)
			elseif ratio <= 0.6 then Color3.fromRGB(235, 180, 55) else UiStyle.Colors.Accent
		status.Text = if defeated then "Defeated" elseif raid.Phase == "Recovery" then "Boss recovering"
			else raid.Phase or raid.Status
		if raid.Status == "Clear" then
			result.Text = "RAID CLEAR"
		elseif raid.Status == "Failed" then
			result.Text = "RAID FAILED"
		end
	end)

	task.spawn(function()
		while gui.Parent do
			local remaining = math.max(0, dashReadyAt - Workspace:GetServerTimeNow())
			local ready = active and not defeated and remaining <= 0
			dashButton.Active = ready
			dashButton.BackgroundColor3 = if ready then UiStyle.Colors.Accent else UiStyle.Colors.Surface
			dashButton.Text = if remaining > 0 then string.format("DASH %.1f", remaining) else "DASH Q"
			cooldown.Text = if remaining > 0 then string.format("Dash: %.1fs", remaining) else "Dash: Ready"
			task.wait(0.1)
		end
	end)

	local warningSerial = 0
	remotes:WaitForChild("RaidTelegraph").OnClientEvent:Connect(function(kind, first, second, third, duration)
		if typeof(kind) ~= "string" or typeof(first) ~= "Vector3" then return end
		local lifetime
		if kind == "Slam" and typeof(second) == "number" and typeof(third) == "number" then
			lifetime = third
			makeMarker(kind, first, second, nil, lifetime)
			warning.Text = "GROUND SLAM"
			warning.TextColor3 = Color3.fromRGB(255, 155, 45)
		elseif kind == "Charge" and typeof(second) == "Vector3" and typeof(third) == "number"
			and typeof(duration) == "number" then
			lifetime = duration
			makeMarker(kind, first, second, third, lifetime)
			warning.Text = "CHARGE"
			warning.TextColor3 = Color3.fromRGB(220, 105, 255)
		else
			return
		end
		warningSerial += 1
		local serial = warningSerial
		warning.Visible = true
		task.delay(math.max(0, lifetime - GameConfig.Raid.WarningFlashTime), function()
			if warningSerial == serial then
				warning.Text = "DODGE NOW!"
				warning.TextColor3 = Color3.fromRGB(255, 45, 45)
			end
		end)
		task.delay(lifetime, function()
			if warningSerial == serial then warning.Visible = false end
		end)
	end)

	local feedbackSerial = { Taken = 0, BossDamage = 0 }
	remotes:WaitForChild("RaidCombatFeedback").OnClientEvent:Connect(function(kind, amount)
		if typeof(amount) ~= "number" or amount <= 0 then return end
		local label = if kind == "Taken" then taken elseif kind == "BossDamage" then dealt else nil
		if not label then return end
		feedbackSerial[kind] += 1
		local serial = feedbackSerial[kind]
		label.Text = if kind == "Taken" then string.format("-%d", amount) else string.format("%d DAMAGE", amount)
		label.Visible = true
		task.delay(0.8, function()
			if feedbackSerial[kind] == serial then label.Visible = false end
		end)
	end)
end

return RaidController
