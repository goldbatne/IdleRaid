local UiStyle = require(script.Parent.UiStyle)

local HUDController = {}

function HUDController.Start(gui: ScreenGui, stateController)
	local panel = Instance.new("Frame")
	panel.Name = "HUD"
	panel.BackgroundColor3 = UiStyle.Colors.Panel
	panel.BorderSizePixel = 0
	panel.Size = UDim2.fromOffset(196, 192)
	panel.Position = UDim2.fromOffset(12, 12)
	UiStyle.Panel(panel, 12)
	local stripe = Instance.new("Frame")
	stripe.Name = "AccentStripe"
	stripe.BorderSizePixel = 0
	stripe.BackgroundColor3 = UiStyle.Colors.Accent
	stripe.Size = UDim2.fromOffset(4, 162)
	stripe.Position = UDim2.fromOffset(0, 15)
	UiStyle.Corner(stripe, 2)
	stripe.Parent = panel
	panel.Parent = gui

	local level = UiStyle.Text(panel, "Level", "Level --", UDim2.new(1, -20, 0, 25), UDim2.fromOffset(10, 8))
	level.Font = Enum.Font.GothamBlack
	level.TextColor3 = UiStyle.Colors.Gold
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
	gold.TextColor3 = UiStyle.Colors.Gold
	local attack = UiStyle.Text(panel, "Attack", "Attack: --", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 105))
	local defense = UiStyle.Text(panel, "Defense", "Defense: --", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 131))
	local tokens = UiStyle.Text(panel, "RaidToken", "Raid Token: 0", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 157))
	tokens.TextColor3 = UiStyle.Colors.Muted

	stateController.Subscribe(function(state)
		local required = math.max(1, state.ExpRequired or 1)
		level.Text = string.format("Level %d", state.Level or 1)
		exp.Text = string.format("EXP %d / %d", state.Exp or 0, required)
		fill.Size = UDim2.fromScale(math.clamp((state.Exp or 0) / required, 0, 1), 1)
		gold.Text = string.format("Gold: %d", state.Gold or 0)
		attack.Text = string.format("Attack: %d", state.FinalAttack or 0)
		defense.Text = string.format("Defense: %d", state.FinalDefense or 0)
		tokens.Text = string.format("Raid Token: %d", state.RaidToken or 0)
	end)
end

return HUDController
