local NumberFormatter = {}
local suffixes = { "", "K", "M", "B", "T", "Qa" }

function NumberFormatter.Format(value: number): string
	if typeof(value) ~= "number" or value ~= value or value < 0 or value == math.huge then return "--" end
	if value < 1000 then return tostring(math.floor(value)) end
	local index = 1
	local scaled = value
	while scaled >= 1000 and index < #suffixes do
		scaled /= 1000
		index += 1
	end
	if scaled >= 999.995 and index < #suffixes then
		scaled /= 1000
		index += 1
	end
	return string.format("%.2f%s", scaled, suffixes[index])
end

return NumberFormatter
