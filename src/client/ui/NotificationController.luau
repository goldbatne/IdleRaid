local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local NumberFormatter = require(ReplicatedStorage.Shared.NumberFormatter)
local UiStyle = require(script.Parent.UiStyle)

local NotificationController = {}

function NotificationController.Start(gui: ScreenGui, stateController, openItem, openPage)
	local toast = UiStyle.Button(gui, "GrowthNotice", "", UDim2.new(1, -24, 0, 42), UDim2.new(0.5, 0, 0, 0))
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundColor3 = UiStyle.Colors.Accent
	toast.Font = Enum.Font.GothamBlack
	toast.TextSize = 13
	toast.Visible = false
	toast.ZIndex = 20
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(320, 42)
	limit.Parent = toast

	local queue = {}
	local displaying = false
	local currentAction
	local function pump()
		if displaying or #queue == 0 then return end
		displaying = true
		task.spawn(function()
			while #queue > 0 and gui.Parent do
				local entry = table.remove(queue, 1)
				currentAction = entry.Action
				toast.Active = entry.Action ~= nil
				toast.Text = entry.Text
				toast.BackgroundColor3 = entry.Color
				toast.Visible = true
				task.wait(entry.Duration or 2.4)
				toast.Visible = false
				currentAction = nil
			end
			displaying = false
		end)
	end
	local function enqueue(message, color, action, duration)
		if #queue >= 5 then
			local removable
			for index, entry in ipairs(queue) do
				if not entry.Action then removable = index break end
			end
			if not removable and not action then return end
			table.remove(queue, removable or 1)
		end
		table.insert(queue, { Text = message, Color = color, Action = action, Duration = duration })
		pump()
	end
	toast.Activated:Connect(function()
		if currentAction then currentAction() end
	end)

	local pendingPower = 0
	local pendingGold = 0
	local rewardScheduled = false
	local function flushRewards()
		if pendingPower > 0 or pendingGold > 0 then
			local parts = {}
			if pendingPower > 0 then table.insert(parts, "수련력 +" .. NumberFormatter.Format(pendingPower)) end
			if pendingGold > 0 then table.insert(parts, "Gold +" .. NumberFormatter.Format(pendingGold)) end
			enqueue(table.concat(parts, " · "), UiStyle.Colors.Accent)
		end
		pendingPower, pendingGold = 0, 0
		rewardScheduled = false
	end
	local function scheduleRewards()
		if rewardScheduled then return end
		rewardScheduled = true
		task.delay(2.5, flushRewards)
	end

	local offlinePanel = Instance.new("Frame")
	offlinePanel.Name = "OfflineSummary"
	offlinePanel.Size = UDim2.new(1, -24, 0, 210)
	offlinePanel.Position = UDim2.fromScale(0.5, 0.5)
	offlinePanel.AnchorPoint = Vector2.new(0.5, 0.5)
	offlinePanel.BackgroundColor3 = UiStyle.Colors.Panel
	offlinePanel.BorderSizePixel = 0
	offlinePanel.Visible = false
	offlinePanel.ZIndex = 30
	UiStyle.Panel(offlinePanel, 12)
	local offlineLimit = Instance.new("UISizeConstraint")
	offlineLimit.MaxSize = Vector2.new(400, 210)
	offlineLimit.Parent = offlinePanel
	offlinePanel.Parent = gui
	local offlineText = UiStyle.Text(offlinePanel, "Summary", "", UDim2.new(1, -20, 0, 146), UDim2.fromOffset(10, 9))
	offlineText.TextSize = 14
	offlineText.ZIndex = 31
	local dismiss = UiStyle.Button(offlinePanel, "Dismiss", "확인", UDim2.new(1, -20, 0, 42), UDim2.fromOffset(10, 159))
	dismiss.ZIndex = 31
	dismiss.Activated:Connect(function() offlinePanel.Visible = false end)

	stateController.OnNotification(function(notification)
		local kind = notification.Kind
		if kind == "Power" and notification.Source ~= "RaidClear" then
			pendingPower += notification.Amount or 0
			scheduleRewards()
		elseif kind == "Gold" and notification.Source ~= "RaidClear" then
			pendingGold += notification.Amount or 0
			scheduleRewards()
		elseif kind == "Item" then
			local definition = ItemConfig.Items[notification.ItemId]
			if definition then
				enqueue("획득: " .. definition.Name .. " · 눌러서 비교",
					UiStyle.Rarities[definition.Rarity] or UiStyle.Colors.Accent,
					function() openItem(notification.ItemId) end, 3.2)
			end
		elseif kind == "Equipment" then
			local definition = notification.ItemId and ItemConfig.Items[notification.ItemId]
			local label = if notification.Action == "Equip" and definition then definition.Name .. " 장착"
				else tostring(notification.Slot or "장비") .. " 해제"
			enqueue(label, UiStyle.Colors.Accent, function() openPage("Bag") end)
		elseif kind == "Offline" then
			local summary = notification.Summary
			if typeof(summary) == "table" and (summary.GrantedPower or 0) > 0 then
				offlineText.Text = string.format("오프라인 수련\n실제 경과 %d분 · 인정 %d분\n기준 수련 %s/초 · 효율 %d%%\n받은 수련력 +%s\n레벨 %d → %d",
					math.floor((summary.ElapsedSeconds or 0) / 60),
					math.floor((summary.AcceptedSeconds or 0) / 60),
					NumberFormatter.Format(summary.Rate or 0),
					math.floor(100 * (summary.EfficiencyNumerator or 0) / math.max(1, summary.EfficiencyDenominator or 1)),
					NumberFormatter.Format(summary.GrantedPower),
					summary.LevelBefore or 1, summary.LevelAfter or 1)
				offlinePanel.Visible = true
			end
		elseif kind == "Breakthrough" then
			enqueue(string.format("돌파 %d → %d · 수련 %s/초", notification.From or 1,
				notification.To or 1, NumberFormatter.Format(notification.AfterRate or 0)),
				UiStyle.Colors.Gold, function() openPage("Growth") end)
		elseif kind == "Facility" then
			enqueue(string.format("시설 %d등급 · 수련 %s → %s/초", notification.Tier or 1,
				NumberFormatter.Format(notification.BeforeRate or 0),
				NumberFormatter.Format(notification.AfterRate or 0)),
				UiStyle.Colors.Accent, function() openPage("Growth") end)
		elseif kind == "GateClear" then
			enqueue("관문 클리어: " .. tostring(notification.GateId or ""), UiStyle.Colors.Gold,
				function() openPage("Raid") end)
		elseif kind == "RaidReward" then
			enqueue(string.format("레이드 보상 · 수련력 +%s · Gold +%s · Token +%s",
				NumberFormatter.Format(notification.Power or 0),
				NumberFormatter.Format(notification.Gold or 0),
				NumberFormatter.Format(notification.Tokens or 0)),
				UiStyle.Colors.Gold, function() openPage("Raid") end, 4)
		elseif kind == "Voucher" then
			enqueue("수련권 사용 · 수련력 +" .. NumberFormatter.Format(notification.Amount or 0),
				UiStyle.Colors.Accent)
		end
	end)

	local lastLevel
	stateController.Subscribe(function(state)
		if not state.Ready then return end
		local level = state.Level or 1
		if lastLevel and level > lastLevel then
			enqueue(string.format("LEVEL UP!  Lv.%d", level), UiStyle.Colors.Gold, nil, 3)
		end
		lastLevel = level
	end)
end

return NotificationController
