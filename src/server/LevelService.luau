local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local LevelService = {}

function LevelService.GetExpRequired(level: number): number
	return GameConfig.Level.BaseExpRequired
		+ (level - 1) * GameConfig.Level.ExpIncreasePerLevel
end

function LevelService.ApplyExp(data, amount: number): number
	data.Exp += amount

	local levelsGained = 0
	while data.Exp >= LevelService.GetExpRequired(data.Level) do
		data.Exp -= LevelService.GetExpRequired(data.Level)
		data.Level += 1
		data.Attack += GameConfig.Level.AttackIncreasePerLevel
		levelsGained += 1
	end

	return levelsGained
end

return LevelService
