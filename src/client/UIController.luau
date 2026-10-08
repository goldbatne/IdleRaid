local Players = game:GetService("Players")

local AutoCombatController = require(script.Parent.AutoCombatController)
local StateController = require(script.Parent.StateController)
local EquipmentController = require(script.Parent.ui.EquipmentController)
local HUDController = require(script.Parent.ui.HUDController)
local InventoryController = require(script.Parent.ui.InventoryController)
local NotificationController = require(script.Parent.ui.NotificationController)
local UiStyle = require(script.Parent.ui.UiStyle)

local UIController = {}

function UIController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("IdleRaidUI")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "IdleRaidUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	HUDController.Start(gui, StateController)

	local autoButton = UiStyle.Button(gui, "AutoCombat", "AUTO: OFF", UDim2.fromOffset(96, 44), UDim2.new(1, -12, 0, 12))
	autoButton.AnchorPoint = Vector2.new(1, 0)
	autoButton.Activated:Connect(AutoCombatController.Toggle)
	AutoCombatController.OnChanged(function(enabled)
		autoButton.Text = if enabled then "AUTO: ON" else "AUTO: OFF"
		autoButton.BackgroundColor3 = if enabled then UiStyle.Colors.Accent else UiStyle.Colors.Surface
	end)

	local bagButton = UiStyle.Button(gui, "BagToggle", "BAG", UDim2.fromOffset(96, 44), UDim2.new(1, -12, 0, 64))
	bagButton.AnchorPoint = Vector2.new(1, 0)

	local panel = Instance.new("Frame")
	panel.Name = "BagPanel"
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -12, 1, -12)
	panel.Size = UDim2.new(1, -24, 0.65, 0)
	panel.BackgroundColor3 = UiStyle.Colors.Panel
	panel.BorderSizePixel = 0
	UiStyle.Corner(panel, 10)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(400, 540)
	limit.Parent = panel
	panel.Parent = gui

	bagButton.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	InventoryController.Start(panel, StateController)
	EquipmentController.Start(panel, StateController)
	NotificationController.Start(gui, StateController)
end

return UIController
