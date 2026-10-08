local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
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

	stateController.OnNotification(function(notification)
		if notification.Kind ~= "Item" then return end
		local definition = ItemConfig.Items[notification.ItemId]
		if definition then
			show("Obtained: " .. definition.Name,
				UiStyle.Rarities[definition.Rarity] or UiStyle.Colors.Accent, 3)
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
