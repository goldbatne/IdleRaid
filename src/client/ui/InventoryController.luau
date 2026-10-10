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
	local rowsByItemId = {}
	local quantitiesByItemId = {}
	local nextLayoutOrder = 0
	local updateSelection

	-- Keep a row and its Activated connection alive across full and partial state updates.
	-- New items are appended so a pressed row does not move before MouseButton1 is released.
	local function render(state)
		currentState = state
		local present = {}
		for _, stack in ipairs(state.Inventory or {}) do
			local itemId = stack.ItemId
			local definition = ItemConfig.Items[itemId]
			if definition and typeof(stack.Quantity) == "number" and stack.Quantity > 0 then
				present[itemId] = true
				local entry = rowsByItemId[itemId]
				if not entry then
					local row = UiStyle.Button(scroll, itemId, "", UDim2.new(1, -10, 0, 56), UDim2.fromOffset(4, 0))
					row.TextXAlignment = Enum.TextXAlignment.Left
					row.TextSize = 14
					local rarityColor = UiStyle.Rarities[definition.Rarity] or UiStyle.Colors.Text
					row.TextColor3 = rarityColor
					local outline = row:FindFirstChild("Outline")
					if outline and outline:IsA("UIStroke") then
						outline.Color = rarityColor
						outline.Transparency = 0.55
					end
					nextLayoutOrder += 1
					row.LayoutOrder = nextLayoutOrder
					entry = { Button = row }
					rowsByItemId[itemId] = entry
					entry.Connection = row.Activated:Connect(function()
						if not quantitiesByItemId[itemId] then return end
						selectedItemId = itemId
						updateSelection()
					end)
				end
				quantitiesByItemId[itemId] = stack.Quantity
			end
		end
		for itemId, entry in pairs(rowsByItemId) do
			if not present[itemId] then
				entry.Connection:Disconnect()
				entry.Button:Destroy()
				rowsByItemId[itemId] = nil
				quantitiesByItemId[itemId] = nil
			end
		end
		if selectedItemId and not present[selectedItemId] then selectedItemId = nil end
		updateSelection()
	end

	updateSelection = function()
		if not currentState then return end
		for itemId, entry in pairs(rowsByItemId) do
			local selected = selectedItemId == itemId
			local definition = ItemConfig.Items[itemId]
			local label = string.format("%s%s  x%d\n%s · %s",
				if selected then "● " else "", definition.Name, quantitiesByItemId[itemId],
				typeNames[definition.Type] or definition.Type, rarityNames[definition.Rarity] or definition.Rarity)
			if entry.Button.Text ~= label then entry.Button.Text = label end
			entry.Button.BackgroundColor3 = if selected then Color3.fromRGB(54, 82, 113) else UiStyle.Colors.Surface
		end

		if selectedItemId and quantitiesByItemId[selectedItemId] then
			equipButton.Visible = true
			local selected = ItemConfig.Items[selectedItemId]
			local wornId = (currentState.Equipment or {})[selected.Type]
			local worn = wornId and ItemConfig.Items[wornId]
			local beforeAttack = currentState.FinalAttack or 0
			local beforeDefense = currentState.FinalDefense or 0
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
			selectedLabel.Text = if next(rowsByItemId) == nil then "아직 아이템 없음" else "아이템을 선택하세요"
			equipButton.Active = false
			equipButton.AutoButtonColor = false
			equipButton.BackgroundColor3 = UiStyle.Colors.Surface
		end
	end

	equipButton.Activated:Connect(function()
		if selectedItemId and quantitiesByItemId[selectedItemId] then
			equipRemote:FireServer(selectedItemId)
		end
	end)
	local subscription = stateController.Subscribe(render)
	section.Destroying:Connect(function()
		subscription:Disconnect()
		for _, entry in pairs(rowsByItemId) do entry.Connection:Disconnect() end
	end)

	return function(itemId: string): boolean
		if not currentState or not quantitiesByItemId[itemId] then return false end
		selectedItemId = itemId
		updateSelection()
		task.defer(function()
			local entry = rowsByItemId[itemId]
			local row = entry and entry.Button
			if row and row.Parent then
				scroll.CanvasPosition = Vector2.new(0, math.max(0,
					row.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y))
			end
		end)
		return true
	end
end

return InventoryController
