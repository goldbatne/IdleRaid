local GrowthConfig = require(script.Parent.GrowthConfig)

local SafeInteger = {}
local LIMIT = GrowthConfig.MaxSafePower

function SafeInteger.IsValid(value: any): boolean
	return typeof(value) == "number" and value == value and value >= 0 and value <= LIMIT and value % 1 == 0
end

function SafeInteger.PowerRoom(available: number, lifetime: number): number?
	if not SafeInteger.IsValid(available) or not SafeInteger.IsValid(lifetime) or available > lifetime then return nil end
	return math.min(LIMIT - available, LIMIT - lifetime)
end

function SafeInteger.Add(a: number, b: number): number?
	if not SafeInteger.IsValid(a) or not SafeInteger.IsValid(b) or a > LIMIT - b then return nil end
	return a + b
end

function SafeInteger.Subtract(a: number, b: number): number?
	if not SafeInteger.IsValid(a) or not SafeInteger.IsValid(b) or b > a then return nil end
	return a - b
end

function SafeInteger.Multiply(a: number, b: number): number?
	if not SafeInteger.IsValid(a) or not SafeInteger.IsValid(b) or (b > 0 and a > LIMIT / b) then return nil end
	return a * b
end

function SafeInteger.MultiplyRatioFloor(a: number, numerator: number, denominator: number): number?
	if not SafeInteger.IsValid(a) or not SafeInteger.IsValid(numerator)
		or not SafeInteger.IsValid(denominator) or denominator == 0 then return nil end
	local whole = math.floor(a / denominator)
	local remainder = a % denominator
	local first = SafeInteger.Multiply(whole, numerator)
	local second = SafeInteger.Multiply(remainder, numerator)
	if not first or not second then return nil end
	return SafeInteger.Add(first, math.floor(second / denominator))
end

return SafeInteger
