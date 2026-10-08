local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local NumberFormatter = require(ReplicatedStorage.Shared.NumberFormatter)
local UiStyle = require(script.Parent.UiStyle)

local CharacterController = {}
local slots = { "Weapon", "Armor", "Accessory" }
local names = { Weapon = "무기", Armor = "방어구", Accessory = "장신구" }

function CharacterController.Start(panel: Frame, stateController)
	local title = UiStyle.Text(panel, "CharacterTitle", "캐릭터", UDim2.new(1, -20, 0, 32), UDim2.fromOffset(10, 10))
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 21
	title.TextColor3 = UiStyle.Colors.Gold
	local stats = UiStyle.Text(panel, "CharacterStats", "", UDim2.new(1, -20, 0, 150), UDim2.fromOffset(10, 50))
	stats.TextSize = 16
	stats.TextYAlignment = Enum.TextYAlignment.Top
	local gearTitle = UiStyle.Text(panel, "GearTitle", "착용 장비", UDim2.new(1, -20, 0, 28), UDim2.fromOffset(10, 220))
	gearTitle.Font = Enum.Font.GothamBold
	gearTitle.TextColor3 = UiStyle.Colors.Gold
	local gear = {}
	for index, slot in ipairs(slots) do
		gear[slot] = UiStyle.Text(panel, "Gear" .. slot, "", UDim2.new(1, -20, 0, 45),
			UDim2.fromOffset(10, 256 + (index - 1) * 51))
		gear[slot].TextSize = 15
	end
	local note = UiStyle.Text(panel, "CharacterNote", "가방 메뉴에서 장비를 장착·해제할 수 있습니다.",
		UDim2.new(1, -20, 0, 54), UDim2.fromOffset(10, 421))
	note.TextSize = 12
	note.TextColor3 = UiStyle.Colors.Muted

	stateController.Subscribe(function(state)
		stats.Text = string.format("레벨  %d\n기본 공격력  %s\n최종 공격력  %s\n최종 방어력  %s\n현재 수련 단계  %d",
			state.Level or 1, NumberFormatter.Format(state.BaseAttack or 0),
			NumberFormatter.Format(state.FinalAttack or 0), NumberFormatter.Format(state.FinalDefense or 0),
			state.BreakthroughStage or 1)
		for _, slot in ipairs(slots) do
			local itemId = (state.Equipment or {})[slot]
			local definition = itemId and ItemConfig.Items[itemId]
			gear[slot].Text = names[slot] .. "  " .. (definition and definition.Name or "없음")
			gear[slot].TextColor3 = if definition then UiStyle.Rarities[definition.Rarity] or UiStyle.Colors.Text
				else UiStyle.Colors.Muted
		end
	end)
end

return CharacterController
