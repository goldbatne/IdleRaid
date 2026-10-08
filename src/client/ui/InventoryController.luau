local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local UiStyle = require(script.Parent.UiStyle)

local InventoryController = {}

function InventoryController.Start(panel: Frame, stateController)
	local section = Instance.new("Frame")
	section.Name = "Inventory"
	section.BackgroundTransparency = 1
	section.Size = UDim2.new(1, -16, 0.56, -8)
	section.Position = UDim2.fromOffset(8, 8)
	section.Parent = panel

	local title = UiStyle.Text(section, "Title", "INVENTORY", UDim2.new(1, -16, 0, 25), UDim2.fromOffset(8, 0))
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = UiStyle.Colors.Gold

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.BackgroundColor3 = UiStyle.Colors.Surface
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Size = UDim2.new(1, -16, 1, -107)
	scroll.Position = UDim2.fromOffset(8, 29)
	UiStyle.Corner(scroll, 8)
	scroll.Parent = section

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll
	layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
		scroll.CanvasSize = UDim2.fromOffset(0, layout.AbsoluteContentSize.Y + 8)
	end)

	local selectedLabel = UiStyle.Text(section, "Selected", "Select an item", UDim2.new(1, -16, 0, 22), UDim2.new(0, 8, 1, -72))
	selectedLabel.TextSize = 14
	local equipButton = UiStyle.Button(section, "Equip", "EQUIP", UDim2.new(1, -16, 0, 42), UDim2.new(0, 8, 1, -46))
	equipButton.Visible = false

	local equipRemote = ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("EquipItem")
	local selectedItemId
	local currentState

	local function render(state)
		currentState = state
		local selectedStack
		for _, child in ipairs(scroll:GetChildren()) do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end

		local items = state.Inventory or {}
		for _, stack in ipairs(items) do
			local itemId = stack.ItemId
			local definition = ItemConfig.Items[itemId]
			if definition then
				if selectedItemId == stack.ItemId then
					selectedStack = stack
				end
				local prefix = if selectedItemId == stack.ItemId then "● " else ""
				local row = UiStyle.Button(
					scroll,
					stack.ItemId,
					string.format("%s%s  x%d\n%s · %s", prefix, definition.Name, stack.Quantity, definition.Type, definition.Rarity),
					UDim2.new(1, -10, 0, 56),
					UDim2.fromOffset(4, 0)
				)
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.TextSize = 14
				local rarityColor = UiStyle.Rarities[definition.Rarity] or UiStyle.Colors.Text
				row.TextColor3 = rarityColor
				row.BackgroundColor3 = if selectedItemId == itemId then Color3.fromRGB(54, 82, 113)
					else UiStyle.Colors.Surface
				local outline = row:FindFirstChild("Outline")
				if outline and outline:IsA("UIStroke") then
					outline.Color = rarityColor
					outline.Transparency = 0.55
				end
				row.LayoutOrder = #scroll:GetChildren()
				row.Activated:Connect(function()
					selectedItemId = itemId
					render(currentState)
				end)
			end
		end

		if selectedStack then
			equipButton.Visible = true
			selectedLabel.Text = "Selected: " .. ItemConfig.Items[selectedItemId].Name
			equipButton.Active = true
			equipButton.AutoButtonColor = true
			equipButton.BackgroundColor3 = UiStyle.Colors.Accent
		else
			equipButton.Visible = false
			selectedItemId = nil
			selectedLabel.Text = if #items == 0 then "No items yet" else "Select an item"
			equipButton.Active = false
			equipButton.AutoButtonColor = false
			equipButton.BackgroundColor3 = UiStyle.Colors.Surface
		end
	end

	equipButton.Activated:Connect(function()
		if selectedItemId then
			equipRemote:FireServer(selectedItemId)
		end
	end)
	stateController.Subscribe(render)
end

return InventoryController
