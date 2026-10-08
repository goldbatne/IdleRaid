local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local NumberFormatter = require(ReplicatedStorage.Shared.NumberFormatter)
local UiStyle = require(script.Parent.UiStyle)

local NotificationController = {}

function NotificationController.Start(gui: ScreenGui, stateController)
	local toast = UiStyle.Text(gui, "ItemNotice", "", UDim2.new(1, -24, 0, 48), UDim2.new(0.5, 0, 0.28, 0))
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundTransparency = 0.08
	toast.BackgroundColor3 = UiStyle.Colors.Accent
	toast.Font = Enum.Font.GothamBlack
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.Visible = false
	toast.ZIndex = 20
	UiStyle.Corner(toast, 10)
	UiStyle.Outline(toast, UiStyle.Colors.Gold, 0.2)

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(360, 48)
	limit.Parent = toast

	local serial = 0
	local function show(message: string, color: Color3, duration: number)
		serial += 1
		local this = serial
		toast.Text = message
		toast.BackgroundColor3 = color
		toast.Visible = true
		task.delay(duration, function()
			if serial == this then toast.Visible = false end
		end)
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
		if notification.Kind == "Item" then
			local definition = ItemConfig.Items[notification.ItemId]
			if definition then
				show("획득: " .. definition.Name,
					UiStyle.Rarities[definition.Rarity] or UiStyle.Colors.Accent, 3)
			end
		elseif notification.Kind == "Offline" then
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
		elseif notification.Kind == "Breakthrough" then
			show("돌파 성공", UiStyle.Colors.Gold, 2)
		elseif notification.Kind == "GateClear" then
			show("관문 클리어!", UiStyle.Colors.Gold, 3)
		end
	end)

	local lastLevel
	stateController.Subscribe(function(state)
		local level = state.Level or 1
		if lastLevel and level > lastLevel then
			show(string.format("LEVEL UP!  Lv.%d", level), UiStyle.Colors.Gold, 3.5)
		end
		lastLevel = level
	end)
end

return NotificationController
