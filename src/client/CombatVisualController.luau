local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local CombatVisualController = {}

local function effectPart(folder: Folder, name: string, size: Vector3, cframe: CFrame, color: Color3)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	part.CFrame = cframe
	part.Parent = folder
	return part
end

local function burst(folder: Folder, position: Vector3, color: Color3, big: boolean)
	local count = if big then 8 else 4
	for index = 1, count do
		local angle = index * math.pi * 2 / count
		local start = position + Vector3.new(math.cos(angle), 0.3, math.sin(angle)) * 0.5
		local part = effectPart(folder, "Spark", Vector3.new(0.35, 0.35, 0.35), CFrame.new(start), color)
		part.Shape = Enum.PartType.Ball
		part.Transparency = 0.1
		TweenService:Create(part, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = start + Vector3.new(math.cos(angle) * 2.1, 1.4, math.sin(angle) * 2.1),
			Size = Vector3.new(0.08, 0.08, 0.08),
			Transparency = 1,
		}):Play()
		Debris:AddItem(part, 0.5)
	end
end

local function number(folder: Folder, position: Vector3, amount: number)
	local anchor = effectPart(folder, "DamageNumber", Vector3.new(0.1, 0.1, 0.1),
		CFrame.new(position + Vector3.new(0, 2.4, 0)), Color3.new(1, 1, 1))
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(96, 48)
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 24
	label.TextStrokeTransparency = 0.25
	label.TextColor3 = Color3.fromRGB(255, 230, 140)
	label.Text = tostring(amount)
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.65), {
		Position = anchor.Position + Vector3.new(0, 1.8, 0),
	}):Play()
	TweenService:Create(label, TweenInfo.new(0.65), {
		TextTransparency = 1, TextStrokeTransparency = 1,
	}):Play()
	Debris:AddItem(anchor, 0.7)
end

function CombatVisualController.Start()
	local folder = Instance.new("Folder")
	folder.Name = "IdleRaidClientEffects"
	folder.Parent = Workspace
	ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("CombatVisual").OnClientEvent:Connect(
		function(attacker, enemyId, position, dealt, killed)
			if typeof(position) ~= "Vector3" or typeof(dealt) ~= "number" or dealt <= 0
				or not GameConfig.Enemies[enemyId] or #folder:GetChildren() > 48 then
				return
			end
			local isBoss = enemyId == "SlimeKing"
			local color = if isBoss then Color3.fromRGB(255, 183, 97) else Color3.fromRGB(133, 255, 171)
			local root = attacker and attacker.Character and attacker.Character:FindFirstChild("HumanoidRootPart")
			if root then
				local center = root.Position:Lerp(position, 0.72)
				local slash = effectPart(folder, "AttackSlash", Vector3.new(0.18, if isBoss then 6 else 3.4, 0.55),
					CFrame.lookAt(center, position) * CFrame.Angles(0, 0, math.rad(55)), color)
				TweenService:Create(slash, TweenInfo.new(0.23), {
					Transparency = 1, Size = Vector3.new(0.08, 0.6, 0.2),
				}):Play()
				Debris:AddItem(slash, 0.28)
			end
			burst(folder, position, color, killed == true)
			if not isBoss then number(folder, position, dealt) end
			if killed == true then
				local flare = effectPart(folder, "DefeatFlare", Vector3.new(0.8, 0.8, 0.8),
					CFrame.new(position), color)
				flare.Shape = Enum.PartType.Ball
				TweenService:Create(flare, TweenInfo.new(0.5), {
					Size = Vector3.new(5, 5, 5), Transparency = 1,
				}):Play()
				Debris:AddItem(flare, 0.55)
			end
		end
	)
end

return CombatVisualController
