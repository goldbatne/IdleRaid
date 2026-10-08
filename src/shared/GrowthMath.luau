local GrowthConfig = require(script.Parent.GrowthConfig)
local SafeInteger = require(script.Parent.SafeInteger)

local GrowthMath = {}

local function validStage(stage: number): boolean
	return SafeInteger.IsValid(stage) and stage >= 1 and stage <= GrowthConfig.MaxStage
end

function GrowthMath.StageMultiplier(stage: number): number?
	if not validStage(stage) then return nil end
	return GrowthConfig.StageMultiplierBase ^ (stage - 1)
end

function GrowthMath.ReferenceRate(stage: number): number?
	local multiplier = GrowthMath.StageMultiplier(stage)
	return multiplier and SafeInteger.Multiply(GrowthConfig.ReferenceRateAtStageOne, multiplier) or nil
end

function GrowthMath.FacilityMultiplier(tier: number): (number?, number?)
	local facility = GrowthConfig.Facilities[tier]
	if not facility or facility.Tier ~= tier then return nil, nil end
	return facility.Numerator, facility.Denominator
end

function GrowthMath.BaseRate(stage: number, tier: number): number?
	local reference = GrowthMath.ReferenceRate(stage)
	local numerator, denominator = GrowthMath.FacilityMultiplier(tier)
	if not reference or not numerator then return nil end
	return SafeInteger.MultiplyRatioFloor(reference, numerator, denominator)
end

function GrowthMath.TargetBaseSeconds(stage: number): number?
	if not validStage(stage) then return nil end
	return math.min(GrowthConfig.TargetBaseSecondsCap,
		GrowthConfig.TargetBaseSecondsStart + GrowthConfig.TargetBaseSecondsStep * (stage - 1))
end

function GrowthMath.BreakthroughCost(stage: number): number?
	local rate = GrowthMath.ReferenceRate(stage)
	local seconds = GrowthMath.TargetBaseSeconds(stage)
	if not rate or not seconds then return nil end
	return SafeInteger.Multiply(rate, seconds)
end

function GrowthMath.NextGate(stage: number, cleared): any
	for _, gate in ipairs(GrowthConfig.Gates) do
		if not cleared[gate.Id] and stage <= gate.Stage then return gate end
	end
	return nil
end

function GrowthMath.CanAdvance(stage: number, steps: number, cleared): (boolean, string?)
	if not validStage(stage) or not SafeInteger.IsValid(steps) or (steps ~= 1 and steps ~= 2 and steps ~= 3 and steps ~= 5) then
		return false, "InvalidRequest"
	end
	if stage >= GrowthConfig.MaxStage or stage + steps > GrowthConfig.MaxStage then return false, "MaxStage" end
	for _, gate in ipairs(GrowthConfig.Gates) do
		if not cleared[gate.Id] and stage <= gate.Stage and stage + steps > gate.Stage then
			return false, "Gate" .. tostring(gate.Stage)
		end
	end
	return true, nil
end

function GrowthMath.EnemyPower(stage: number, zoneId: string): number?
	for _, zone in ipairs(GrowthConfig.Zones) do
		if zone.Id == zoneId and stage >= zone.RequiredStage then
			local rewardStage = math.min(stage, zone.RewardStageCap)
			local rate = GrowthMath.ReferenceRate(rewardStage)
			return rate and SafeInteger.Multiply(rate, GrowthConfig.EnemyRewardSeconds) or nil
		end
	end
	return nil
end

local thresholds = { 0 }
local requirement = GrowthConfig.LevelBaseRequirement
for level = 1, GrowthConfig.MaxLevel - 1 do
	local nextThreshold = SafeInteger.Add(thresholds[level], requirement)
	assert(nextThreshold, "Level threshold exceeds exact integer range")
	thresholds[level + 1] = nextThreshold
	requirement = math.ceil(requirement * GrowthConfig.LevelRequirementNumerator
		/ GrowthConfig.LevelRequirementDenominator)
end

function GrowthMath.LevelProgress(lifetime: number): (number?, number?, number?)
	if not SafeInteger.IsValid(lifetime) then return nil, nil, nil end
	local low, high = 1, #thresholds
	while low < high do
		local middle = math.floor((low + high + 1) / 2)
		if thresholds[middle] <= lifetime then low = middle else high = middle - 1 end
	end
	local level = low
	if level == GrowthConfig.MaxLevel then return level, 0, 0 end
	return level, lifetime - thresholds[level], thresholds[level + 1] - thresholds[level]
end

function GrowthMath.LifetimeForLevel(level: number, progressNumerator: number?, progressDenominator: number?): number?
	if not SafeInteger.IsValid(level) or level < 1 or level > GrowthConfig.MaxLevel then return nil end
	local threshold = thresholds[level]
	if level == GrowthConfig.MaxLevel then return threshold end
	local numerator = progressNumerator or 0
	local denominator = progressDenominator or 1
	if not SafeInteger.IsValid(numerator) or not SafeInteger.IsValid(denominator)
		or denominator == 0 or numerator > denominator then return nil end
	return threshold + math.floor((thresholds[level + 1] - threshold) * numerator / denominator)
end

return GrowthMath
