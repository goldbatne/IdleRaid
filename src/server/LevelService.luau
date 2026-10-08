local GrowthMath = require(game:GetService("ReplicatedStorage").Shared.GrowthMath)
local LevelService = {}

function LevelService.GetExpRequired(level: number): number
	local current = GrowthMath.LifetimeForLevel(level)
	local nextThreshold = GrowthMath.LifetimeForLevel(level + 1)
	return if current and nextThreshold then nextThreshold - current else 0
end

return LevelService
