local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NumberFormatter = require(ReplicatedStorage.Shared.NumberFormatter)
local UiStyle = require(script.Parent.UiStyle)
local UiText = require(script.Parent.UiText)

local HUDController = {}

function HUDController.Start(gui: ScreenGui, stateController)
	local panel = Instance.new("Frame")
	panel.Name = "HUD"
	panel.BackgroundColor3 = UiStyle.Colors.Panel
	panel.BorderSizePixel = 0
	panel.Size = UDim2.new(0.58, 0, 0, 178)
	panel.Position = UDim2.fromOffset(12, 12)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(260, 178)
	limit.MinSize = Vector2.new(178, 178)
	limit.Parent = panel
	UiStyle.Panel(panel, 12)
	panel.Parent = gui

	local lifetimeCaption = UiStyle.Text(panel, "LifetimeCaption", UiText.Lifetime, UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 7))
	lifetimeCaption.TextSize = 13
	lifetimeCaption.TextColor3 = UiStyle.Colors.Muted
	local lifetime = UiStyle.Text(panel, "LifetimePower", "--", UDim2.new(1, -20, 0, 32), UDim2.fromOffset(12, 26))
	lifetime.TextSize = 26
	lifetime.Font = Enum.Font.GothamBlack
	lifetime.TextColor3 = UiStyle.Colors.Gold

	local level = UiStyle.Text(panel, "Level", "레벨 1", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 63))
	level.TextSize = 15
	local exp = UiStyle.Text(panel, "Exp", "0 / 100", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(12, 83))
	exp.TextSize = 12
	exp.TextColor3 = UiStyle.Colors.Muted
	local bar = Instance.new("Frame")
	bar.Name = "ExpBar"
	bar.BackgroundColor3 = UiStyle.Colors.Surface
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, -24, 0, 9)
	bar.Position = UDim2.fromOffset(12, 105)
	UiStyle.Corner(bar, 5)
	bar.Parent = panel
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = UiStyle.Colors.Accent
	fill.BorderSizePixel = 0
	UiStyle.Corner(fill, 5)
	fill.Parent = bar

	local stage = UiStyle.Text(panel, "Stage", "돌파 1단계", UDim2.new(1, -20, 0, 20), UDim2.fromOffset(12, 119))
	stage.TextSize = 14
	local rate = UiStyle.Text(panel, "Rate", "x1 · 10/초", UDim2.new(1, -20, 0, 19), UDim2.fromOffset(12, 138))
	rate.TextSize = 13
	rate.TextColor3 = UiStyle.Colors.Accent
	local gold = UiStyle.Text(panel, "Gold", "Gold 0", UDim2.new(1, -20, 0, 16), UDim2.fromOffset(12, 157))
	gold.TextSize = 12
	gold.TextColor3 = UiStyle.Colors.Muted

	stateController.Subscribe(function(state)
		if not state.Ready then
			lifetime.Text = "--"
			level.Text = UiText.Loading
			return
		end
		lifetime.Text = NumberFormatter.Format(state.LifetimeTrainingPower or 0)
		level.Text = string.format("레벨 %d", state.Level or 1)
		local required = state.ExpRequired or 0
		exp.Text = if required > 0 then string.format("%s / %s", NumberFormatter.Format(state.Exp or 0),
			NumberFormatter.Format(required)) else "최고 레벨"
		fill.Size = UDim2.fromScale(if required > 0 then math.clamp((state.Exp or 0) / required, 0, 1) else 1, 1)
		stage.Text = string.format("돌파 %d단계", state.BreakthroughStage or 1)
		rate.Text = string.format("x%s · %s/초", NumberFormatter.Format(state.StageMultiplier or 1),
			NumberFormatter.Format(state.BaseTrainingRate or 0))
		gold.Text = "Gold " .. NumberFormatter.Format(state.Gold or 0)
	end)
end

return HUDController
