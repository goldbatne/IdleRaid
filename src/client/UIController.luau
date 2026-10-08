local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local AutoCombatController = require(script.Parent.AutoCombatController)
local StateController = require(script.Parent.StateController)
local EquipmentController = require(script.Parent.ui.EquipmentController)
local DashController = require(script.Parent.DashController)
local HUDController = require(script.Parent.ui.HUDController)
local InventoryController = require(script.Parent.ui.InventoryController)
local NotificationController = require(script.Parent.ui.NotificationController)
local RaidController = require(script.Parent.ui.RaidController)
local GrowthController = require(script.Parent.ui.GrowthController)
local CharacterController = require(script.Parent.ui.CharacterController)
local RaidMenuController = require(script.Parent.ui.RaidMenuController)
local StudioDebugController = require(script.Parent.ui.StudioDebugController)
local UiStyle = require(script.Parent.ui.UiStyle)

local UIController = {}

function UIController.Start()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = playerGui:FindFirstChild("IdleRaidUI")
	if old then old:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "IdleRaidUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false) end)

	HUDController.Start(gui, StateController)

	local autoButton = UiStyle.Button(gui, "AutoCombat", "AUTO 꺼짐",
		UDim2.fromOffset(100, 44), UDim2.new(1, -12, 0, 12))
	autoButton.AnchorPoint = Vector2.new(1, 0)
	autoButton.Activated:Connect(AutoCombatController.Toggle)
	AutoCombatController.OnChanged(function(enabled)
		autoButton.Text = if enabled then "AUTO 켜짐" else "AUTO 꺼짐"
		autoButton.BackgroundColor3 = if enabled then UiStyle.Colors.Accent else UiStyle.Colors.Surface
	end)

	local nav = Instance.new("Frame")
	nav.Name = "MenuNavigation"
	nav.BackgroundTransparency = 1
	nav.Size = UDim2.fromOffset(102, 216)
	nav.Position = UDim2.new(1, -114, 0, 64)
	nav.Parent = gui

	local container = Instance.new("Frame")
	container.Name = "MenuPanel"
	container.AnchorPoint = Vector2.new(0.5, 0.5)
	container.Position = UDim2.fromScale(0.5, 0.5)
	container.Size = UDim2.new(1, -24, 1, -72)
	container.BackgroundColor3 = UiStyle.Colors.Panel
	container.BorderSizePixel = 0
	container.Visible = false
	container.ZIndex = 10
	UiStyle.Panel(container, 12)
	local sizeLimit = Instance.new("UISizeConstraint")
	sizeLimit.MaxSize = Vector2.new(520, 620)
	sizeLimit.MinSize = Vector2.new(280, 270)
	sizeLimit.Parent = container
	container.Parent = gui

	local pages = {}
	local pageDefs = {
		{ Key = "Character", Label = "캐릭터", Scrolling = true },
		{ Key = "Bag", Label = "가방", Scrolling = false },
		{ Key = "Growth", Label = "성장", Scrolling = false },
		{ Key = "Raid", Label = "레이드", Scrolling = true },
	}
	if RunService:IsStudio() then
		table.insert(pageDefs, { Key = "Debug", Label = "DEV", Scrolling = true })
	end
	for index, definition in ipairs(pageDefs) do
		local page = if definition.Scrolling then Instance.new("ScrollingFrame") else Instance.new("Frame")
		page.Name = definition.Key .. "Page"
		page.Size = UDim2.fromScale(1, 1)
		page.BackgroundTransparency = 1
		page.BorderSizePixel = 0
		page.Visible = false
		page.ZIndex = 11
		if page:IsA("ScrollingFrame") then
			page.CanvasSize = UDim2.fromOffset(0, 590)
			page.ScrollBarThickness = 5
		end
		page.Parent = container
		pages[definition.Key] = page

		local button = UiStyle.Button(nav, definition.Key .. "Menu", definition.Label,
			UDim2.fromOffset(102, 48), UDim2.fromOffset(0, (index - 1) * 54))
		button.TextSize = 14
		button.Activated:Connect(function()
			local willOpen = not container.Visible or not page.Visible
			container.Visible = willOpen
			for key, item in pairs(pages) do item.Visible = willOpen and key == definition.Key end
		end)
	end

	local close = UiStyle.Button(container, "CloseMenu", "×", UDim2.fromOffset(42, 42),
		UDim2.new(1, -46, 0, 5))
	close.ZIndex = 15
	close.TextSize = 24
	close.Activated:Connect(function() container.Visible = false end)

	CharacterController.Start(pages.Character, StateController)
	InventoryController.Start(pages.Bag, StateController)
	EquipmentController.Start(pages.Bag, StateController)
	GrowthController.Start(pages.Growth, StateController)
	RaidMenuController.Start(pages.Raid, StateController)
	if RunService:IsStudio() then StudioDebugController.Start(pages.Debug) end
	NotificationController.Start(gui, StateController)
	RaidController.Start(gui, StateController, DashController)

	local function resizeNavigation()
		local camera = Workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)
		if viewport.Y < 480 then
			nav.Position = UDim2.new(1, -114, 0, 64)
			container.Size = UDim2.new(1, -24, 1, -35)
		else
			nav.Position = UDim2.new(1, -114, 0, 64)
			container.Size = UDim2.new(1, -24, 1, -72)
		end
	end
	resizeNavigation()
	if Workspace.CurrentCamera then
		Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resizeNavigation)
	end
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(resizeNavigation)

	ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("OpenGrowthMenu").OnClientEvent:Connect(function()
		container.Visible = true
		for key, page in pairs(pages) do page.Visible = key == "Growth" end
	end)
	StateController.Subscribe(function(state)
		local inRaid = state.Raid and state.Raid.IsParticipant == true
		if inRaid then container.Visible = false end
		nav.Visible = not inRaid
		autoButton.Visible = not inRaid
		local hud = gui:FindFirstChild("HUD")
		if hud then hud.Visible = not inRaid end
	end)
end

return UIController
