local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local UiStyle = require(script.Parent.UiStyle)

local NotificationController = {}

function NotificationController.Start(gui: ScreenGui, stateController)
	local toast = UiStyle.Text(gui, "ItemNotice", "", UDim2.new(1, -24, 0, 42), UDim2.new(0.5, 0, 0.28, 0))
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundTransparency = 0
	toast.BackgroundColor3 = UiStyle.Colors.Accent
	toast.Font = Enum.Font.GothamBold
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.Visible = false
	toast.ZIndex = 20
	UiStyle.Corner(toast, 8)

	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(360, 42)
	limit.Parent = toast

	local lastNotice = 0
	stateController.OnNotification(function(notification)
		if notification.Kind ~= "Item" then
			return
		end
		local definition = ItemConfig.Items[notification.ItemId]
		if not definition then
			return
		end
		lastNotice += 1
		local notice = lastNotice
		toast.Text = "Obtained: " .. definition.Name
		toast.Visible = true
		task.delay(3, function()
			if lastNotice == notice then
				toast.Visible = false
			end
		end)
	end)
end

return NotificationController
