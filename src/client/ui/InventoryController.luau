local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local NumberFormatter = require(ReplicatedStorage.Shared.NumberFormatter)
local UiStyle = require(script.Parent.UiStyle)

local InventoryController = {}
local typeNames = { Weapon = "무기", Armor = "방어구", Accessory = "장신구" }
local rarityNames = { Common = "일반", Uncommon = "고급", Rare = "희귀", Epic = "영웅", Legendary = "전설" }

function InventoryController.Start(panel: Frame, stateController)
	local section = Instance.new("Frame")
	section.Name = "Inventory"
	section.BackgroundTransparency = 1
	section.Size = UDim2.new(1, -16, 0, 350)
	section.Position = UDim2.fromOffset(8, 8)
	section.Parent = panel

	local title = UiStyle.Text(section, "Title", "가방", UDim2.new(1, -16, 0, 25), UDim2.fromOffset(8, 0))
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = UiStyle.Colors.Gold

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Items"
	scroll.BackgroundColor3 = UiStyle.Colors.Surface
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.Size = UDim2.new(1, -16, 1, -140)
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

	local selectedLabel = UiStyle.Text(section, "Selected", "아이템을 선택하세요", UDim2.new(1, -16, 0, 58), UDim2.new(0, 8, 1, -108))
	selectedLabel.TextSize = 12
	local equipButton = UiStyle.Button(section, "Equip", "장착", UDim2.new(1, -16, 0, 42), UDim2.new(0, 8, 1, -46))
	equipButton.Visible = false

	local equipRemote = ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("EquipItem")
	local selectedItemId
	local currentState
	local lastInventory
	local lastEquipment
	local lastAttack
	local lastDefense
	local hasRendered = false

	local function render(state, force)
		currentState = state
		if hasRendered and not force and state.Inventory == lastInventory and state.Equipment == lastEquipment
		and state.FinalAttack == lastAttack and state.FinalDefense == lastDefense then return end
		hasRendered = true
		lastInventory = state.Inventory
		lastEquipment = state.Equipment
		lastAttack = state.FinalAttack
		lastDefense = state.FinalDefense
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
					string.format("%s%s  x%d\n%s · %s", prefix, definition.Name, stack.Quantity, typeNames[definition.Type] or definition.Type, rarityNames[definition.Rarity] or definition.Rarity),
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
					render(currentState, true)
				end)
			end
		end

		if selectedStack then
			equipButton.Visible = true
			local selected = ItemConfig.Items[selectedItemId]
			local wornId = (state.Equipment or {})[selected.Type]
			local worn = wornId and ItemConfig.Items[wornId]
			local beforeAttack = state.FinalAttack or 0
			local beforeDefense = state.FinalDefense or 0
			local afterAttack = beforeAttack - (worn and worn.Attack or 0) + (selected.Attack or 0)
			local afterDefense = beforeDefense - (worn and worn.Defense or 0) + (selected.Defense or 0)
			selectedLabel.Text = string.format("%s → %s\n공격 %s → %s  ·  방어 %s → %s",
				worn and worn.Name or "미착용", selected.Name,
				NumberFormatter.Format(beforeAttack), NumberFormatter.Format(afterAttack),
				NumberFormatter.Format(beforeDefense), NumberFormatter.Format(afterDefense))
			equipButton.Active = true
			equipButton.AutoButtonColor = true
			equipButton.BackgroundColor3 = UiStyle.Colors.Accent
		else
			equipButton.Visible = false
			selectedItemId = nil
			selectedLabel.Text = if #items == 0 then "아직 아이템 없음" else "아이템을 선택하세요"
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
	return function(itemId: string): boolean
		if not currentState then return false end
		for _, stack in ipairs(currentState.Inventory or {}) do
			if stack.ItemId == itemId then
				selectedItemId = itemId
				render(currentState, true)
				task.defer(function()
					local row = scroll:FindFirstChild(itemId)
					if row then
						scroll.CanvasPosition = Vector2.new(0, math.max(0,
							row.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y))
					end
				end)
				return true
			end
		end
		return false
	end
end

return InventoryController
