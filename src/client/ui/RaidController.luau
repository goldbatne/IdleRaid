local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")
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
	marker.Color = Color3.fromRGB(255, 65, 65)
	marker.Transparency = 0.45
	if kind == "Slam" then
		local radius = second
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(0.16, radius * 2, radius * 2)
		marker.CFrame = CFrame.new(first + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	elseif kind == "Charge" then
		local destination = second
		local width = third
		local flatFirst = Vector3.new(first.X, 0.12, first.Z)
		local flatEnd = Vector3.new(destination.X, 0.12, destination.Z)
		marker.Size = Vector3.new(width, 0.16, (flatEnd - flatFirst).Magnitude)
		marker.CFrame = CFrame.lookAt((flatFirst + flatEnd) / 2, flatEnd)
	else
		marker:Destroy()
		return
	end
	marker.Parent = Workspace
	task.delay(lifetime, function() marker:Destroy() end)
end

function RaidController.Start(gui: ScreenGui, stateController)
	local remotes = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
	local join = remotes:WaitForChild("JoinRaid")
	local raidButton = UiStyle.Button(gui, "RaidButton", "RAID", UDim2.fromOffset(96, 44), UDim2.new(1, -12, 0, 116))
	raidButton.AnchorPoint = Vector2.new(1, 0)
	raidButton.Activated:Connect(function() join:FireServer() end)

	local panel = Instance.new("Frame")
	panel.Name = "RaidPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 204)
	panel.Size = UDim2.new(1, -24, 0, 106)
	panel.BackgroundColor3 = UiStyle.Colors.Panel
	panel.BorderSizePixel = 0
	panel.Visible = false
	UiStyle.Corner(panel, 10)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(420, 106)
	limit.Parent = panel
	panel.Parent = gui

	local title = UiStyle.Text(panel, "BossName", "Slime King", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 6))
	title.Font = Enum.Font.GothamBold
	title.TextXAlignment = Enum.TextXAlignment.Center
	local bossHp = UiStyle.Text(panel, "BossHealth", "HP -- / --", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 30))
	bossHp.TextXAlignment = Enum.TextXAlignment.Center
	local bar = Instance.new("Frame")
	bar.Name = "BossBar"
	bar.Size = UDim2.new(1, -20, 0, 12)
	bar.Position = UDim2.fromOffset(10, 51)
	bar.BorderSizePixel = 0
	bar.BackgroundColor3 = UiStyle.Colors.Surface
	UiStyle.Corner(bar, 6)
	bar.Parent = panel
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = Color3.fromRGB(224, 78, 78)
	UiStyle.Corner(fill, 6)
	fill.Parent = bar
	local health = UiStyle.Text(panel, "PlayerHealth", "Health: 100 / 100", UDim2.new(0.5, -10, 0, 24), UDim2.fromOffset(10, 72))
	local status = UiStyle.Text(panel, "RaidStatus", "Gathering", UDim2.new(0.5, -10, 0, 24), UDim2.new(0.5, 0, 0, 72))
	status.TextXAlignment = Enum.TextXAlignment.Right

	local result = UiStyle.Text(gui, "RaidResult", "", UDim2.new(1, -24, 0, 60), UDim2.new(0.5, 0, 0.5, -30))
	result.AnchorPoint = Vector2.new(0.5, 0)
	result.Font = Enum.Font.GothamBlack
	result.TextSize = 30
	result.TextXAlignment = Enum.TextXAlignment.Center
	result.Visible = false

	local lastMembership
	stateController.Subscribe(function(state)
		local raid = state.Raid or {}
		raidButton.Visible = not raid.IsParticipant
		if lastMembership ~= raid.IsParticipant then
			lastMembership = raid.IsParticipant
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, not raid.IsParticipant)
			end)
		end
		panel.Visible = raid.IsParticipant == true
		result.Visible = raid.IsParticipant and (raid.Status == "Clear" or raid.Status == "Failed") or false
		if not raid.IsParticipant then return end
		title.Text = raid.BossName or "Slime King"
		local maxHp = raid.BossMaxHealth or 0
		local hp = raid.BossHealth or 0
		bossHp.Text = string.format("HP %d / %d", hp, maxHp)
		fill.Size = UDim2.fromScale(if maxHp > 0 then math.clamp(hp / maxHp, 0, 1) else 0, 1)
		health.Text = string.format("Health: %d / %d", state.Health or 0, state.MaxHealth or 100)
		status.Text = if raid.Defeated then "Defeated" else raid.Phase or raid.Status
		if raid.Status == "Clear" then
			result.Text = "RAID CLEAR"
		elseif raid.Status == "Failed" then
			result.Text = "RAID FAILED"
		end
	end)

	remotes:WaitForChild("RaidTelegraph").OnClientEvent:Connect(function(kind, first, second, third, duration)
		if typeof(kind) ~= "string" or typeof(first) ~= "Vector3" then return end
		if kind == "Slam" and typeof(second) == "number" and typeof(third) == "number" then
			makeMarker(kind, first, second, nil, third)
		elseif kind == "Charge" and typeof(second) == "Vector3" and typeof(third) == "number"
			and typeof(duration) == "number" then
			makeMarker(kind, first, second, third, duration)
		end
	end)
end

return RaidController
