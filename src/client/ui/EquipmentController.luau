local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local UiStyle = require(script.Parent.UiStyle)

local EquipmentController = {}
local slots = { "Weapon", "Armor", "Accessory" }

function EquipmentController.Start(panel: Frame, stateController)
	local section = Instance.new("Frame")
	section.Name = "Equipment"
	section.BackgroundTransparency = 1
	section.Size = UDim2.new(1, -16, 0.42, -8)
	section.Position = UDim2.new(0, 8, 0.58, 0)
	section.Parent = panel

	local title = UiStyle.Text(section, "Title", "EQUIPMENT", UDim2.new(1, -16, 0, 25), UDim2.fromOffset(8, 0))
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = UiStyle.Colors.Gold

	local unequipRemote = ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("UnequipEquipment")
	local rows = {}

	for index, slot in ipairs(slots) do
		local slotName = slot
		local y = 27 + (index - 1) * 36
		local label = UiStyle.Text(section, slot, slot .. ": None", UDim2.new(1, -116, 0, 36), UDim2.fromOffset(8, y))
		label.TextSize = 14
		local button = UiStyle.Button(section, "Unequip" .. slot, "UNEQUIP", UDim2.fromOffset(98, 36), UDim2.new(1, -106, 0, y))
		button.TextSize = 12
		button.Activated:Connect(function()
			unequipRemote:FireServer(slotName)
		end)
		rows[slot] = { Label = label, Button = button }
	end

	stateController.Subscribe(function(state)
		local equipment = state.Equipment or {}
		for _, slot in ipairs(slots) do
			local itemId = equipment[slot]
			local definition = itemId and ItemConfig.Items[itemId]
			rows[slot].Label.Text = slot .. ": " .. (definition and definition.Name or "None")
			rows[slot].Label.TextColor3 = if definition then (UiStyle.Rarities[definition.Rarity] or UiStyle.Colors.Text)
				else UiStyle.Colors.Muted
			rows[slot].Button.Visible = definition ~= nil
		end
	end)
end

return EquipmentController
