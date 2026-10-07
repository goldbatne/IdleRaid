local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)

local StatService = {}

function StatService.GetEquipmentBonuses(equipment): (number, number)
	local attack = 0
	local defense = 0
	for _, itemId in pairs(equipment) do
		local definition = ItemConfig.Items[itemId]
		if definition then
			attack += definition.Attack or 0
			defense += definition.Defense or 0
		end
	end
	return attack, defense
end

function StatService.Calculate(data): (number, number)
	local levelAttackBonus = (data.Level - 1) * GameConfig.Level.AttackIncreasePerLevel
	return data.BaseAttack + levelAttackBonus + data.EquipmentAttackBonus,
		data.BaseDefense + data.EquipmentDefenseBonus
end

return StatService
