local UiStyle = require(script.Parent.UiStyle)

local HUDController = {}

function HUDController.Start(gui: ScreenGui, stateController)
	local panel = Instance.new("Frame")
	panel.Name = "HUD"
	panel.BackgroundColor3 = UiStyle.Colors.Panel
	panel.BorderSizePixel = 0
	panel.Size = UDim2.fromOffset(196, 166)
	panel.Position = UDim2.fromOffset(12, 12)
	UiStyle.Corner(panel, 10)
	panel.Parent = gui

	local level = UiStyle.Text(panel, "Level", "Level --", UDim2.new(1, -20, 0, 25), UDim2.fromOffset(10, 8))
	level.Font = Enum.Font.GothamBold
	level.TextSize = 19
	local exp = UiStyle.Text(panel, "Exp", "EXP -- / --", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 35))
	exp.TextSize = 14

	local bar = Instance.new("Frame")
	bar.Name = "ExpBar"
	bar.BackgroundColor3 = UiStyle.Colors.Surface
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, -20, 0, 12)
	bar.Position = UDim2.fromOffset(10, 59)
	UiStyle.Corner(bar, 6)
	bar.Parent = panel

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = UiStyle.Colors.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	UiStyle.Corner(fill, 6)
	fill.Parent = bar

	local gold = UiStyle.Text(panel, "Gold", "Gold: --", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 79))
	local attack = UiStyle.Text(panel, "Attack", "Attack: --", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 105))
	local defense = UiStyle.Text(panel, "Defense", "Defense: --", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 131))

	stateController.Subscribe(function(state)
		local required = math.max(1, state.ExpRequired or 1)
		level.Text = string.format("Level %d", state.Level or 1)
		exp.Text = string.format("EXP %d / %d", state.Exp or 0, required)
		fill.Size = UDim2.fromScale(math.clamp((state.Exp or 0) / required, 0, 1), 1)
		gold.Text = string.format("Gold: %d", state.Gold or 0)
		attack.Text = string.format("Attack: %d", state.FinalAttack or 0)
		defense.Text = string.format("Defense: %d", state.FinalDefense or 0)
	end)
end

return HUDController
