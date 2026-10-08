local Workspace = game:GetService("Workspace")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.GameConfig)

local WorldVisualService = {}

local function piece(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, collide: boolean?)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = collide == true
	part.CanTouch = false
	part.CanQuery = collide == true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Parent = parent
	return part
end

local function sphere(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material)
	local part = piece(parent, name, size, CFrame.new(position), color, material)
	part.Shape = Enum.PartType.Ball
	return part
end

local function tree(parent: Instance, position: Vector3, index: number)
	local wood = Color3.fromRGB(115, 79, 62)
	local leaves = Color3.fromRGB(55, 149, 117)
	piece(parent, "TreeTrunk" .. index, Vector3.new(1.4, 8, 1.4), CFrame.new(position + Vector3.new(0, 4, 0)),
		wood, Enum.Material.Wood)
	sphere(parent, "TreeCrown" .. index, Vector3.new(7, 6, 7), position + Vector3.new(0, 9, 0), leaves, Enum.Material.Grass)
	sphere(parent, "TreeCrownTop" .. index, Vector3.new(5.5, 4.5, 5.5),
		position + Vector3.new(0, 12.2, 0), Color3.fromRGB(77, 182, 132), Enum.Material.Grass)
end

local function field(folder: Folder, onPortalTriggered)
	local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local origin = spawn and spawn.Position or Vector3.new(0, 0, 0)
	local y = origin.Y - 0.05
	piece(folder, "GrassField", Vector3.new(96, 0.4, 80),
		CFrame.new(origin.X, y - 0.2, origin.Z - 5),
		Color3.fromRGB(95, 174, 105), Enum.Material.Grass, true)
	piece(folder, "VillagePath", Vector3.new(12, 0.08, 38),
		CFrame.new(origin.X, y + 0.02, origin.Z - 9),
		Color3.fromRGB(205, 183, 140), Enum.Material.Sand)
	piece(folder, "HuntClearing", Vector3.new(43, 0.09, 21),
		CFrame.new(origin.X, y + 0.04, origin.Z - 17),
		Color3.fromRGB(116, 186, 112), Enum.Material.Grass)

	local spawns = Workspace:FindFirstChild("EnemySpawns")
	if spawns then
		for _, spawnPoint in ipairs(spawns:GetChildren()) do
			if spawnPoint:IsA("BasePart") then
				local pad = piece(folder, "HuntPad_" .. spawnPoint.Name,
					Vector3.new(0.08, 4.5, 4.5),
					CFrame.new(spawnPoint.Position.X, y + 0.07, spawnPoint.Position.Z) * CFrame.Angles(0, 0, math.pi / 2),
					Color3.fromRGB(158, 237, 143), Enum.Material.Neon)
				pad.Shape = Enum.PartType.Cylinder
				pad.Transparency = 0.65
			end
		end
	end

	local trees = {
		Vector3.new(-34, 0, -30), Vector3.new(-25, 0, 21), Vector3.new(34, 0, -27),
		Vector3.new(36, 0, 17), Vector3.new(-40, 0, 7), Vector3.new(19, 0, -35),
	}
	for index, offset in ipairs(trees) do
		tree(folder, Vector3.new(origin.X + offset.X, y, origin.Z + offset.Z), index)
	end
	for index, offset in ipairs({
		Vector3.new(-28, 0, -14), Vector3.new(30, 0, -9), Vector3.new(-16, 0, 17),
		Vector3.new(13, 0, 23), Vector3.new(-38, 0, -20), Vector3.new(39, 0, -17),
	}) do
		sphere(folder, "FieldRock" .. index, Vector3.new(3.5, 2.1, 2.8),
			Vector3.new(origin.X + offset.X, y + 0.7, origin.Z + offset.Z),
			Color3.fromRGB(111, 133, 127), Enum.Material.Slate)
	end

	local portalAt = Vector3.new(origin.X + 23, y, origin.Z + 13)
	local base = piece(folder, "RaidPortalBase", Vector3.new(0.25, 11, 11),
		CFrame.new(portalAt + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(62, 72, 115), Enum.Material.Slate)
	base.Shape = Enum.PartType.Cylinder
	for _, x in ipairs({ -3.1, 3.1 }) do
		piece(folder, "PortalPillar", Vector3.new(1, 7, 1), CFrame.new(portalAt + Vector3.new(x, 3.5, 0)),
			Color3.fromRGB(92, 100, 151), Enum.Material.Slate)
	end
	local crystal = sphere(folder, "RaidPortal", Vector3.new(3.2, 4.5, 3.2),
		portalAt + Vector3.new(0, 4.2, 0), Color3.fromRGB(119, 175, 255), Enum.Material.Neon)
	crystal.Transparency = 0.16
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Enter Raid"
	prompt.ObjectText = "Slime King"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.Parent = crystal
	prompt.Triggered:Connect(onPortalTriggered)
end

local function arenaVisuals(arena: Folder)
	if arena:FindFirstChild("GeneratedVisuals") then return end
	local visuals = Instance.new("Folder")
	visuals.Name = "GeneratedVisuals"
	visuals.Parent = arena
	local center = GameConfig.Raid.ArenaCenter
	local floor = arena:FindFirstChild("Floor")
	local floorTop = if floor and floor:IsA("BasePart") then floor.Position.Y + floor.Size.Y / 2 else center.Y
	local disk = piece(visuals, "MoonstoneCircle", Vector3.new(0.09, 88, 88),
		CFrame.new(center.X, floorTop + 0.04, center.Z) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(43, 53, 82), Enum.Material.Slate)
	disk.Shape = Enum.PartType.Cylinder
	for index = 1, 20 do
		local angle = index * math.pi * 2 / 20
		local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local at = center + radial * 44
		piece(visuals, "ArenaRune" .. index, Vector3.new(3, 0.1, 0.45),
			CFrame.new(at.X, floorTop + 0.12, at.Z) * CFrame.Angles(0, -angle, 0),
			Color3.fromRGB(113, 190, 243), Enum.Material.Neon)
	end
	for index, offset in ipairs({
		Vector3.new(-46, 0, -46), Vector3.new(46, 0, -46),
		Vector3.new(-46, 0, 46), Vector3.new(46, 0, 46),
	}) do
		piece(visuals, "ArenaObelisk" .. index, Vector3.new(2, 12, 2),
			CFrame.new(center + offset + Vector3.new(0, 6, 0)),
			Color3.fromRGB(74, 89, 136), Enum.Material.Slate)
		sphere(visuals, "ArenaCrystal" .. index, Vector3.new(2.2, 3, 2.2),
			center + offset + Vector3.new(0, 13, 0), Color3.fromRGB(130, 178, 255), Enum.Material.Neon)
	end
end

function WorldVisualService.Start(onPortalTriggered)
	local root = Workspace:FindFirstChild("IdleRaidVisuals")
	if root and not root:IsA("Folder") then
		warn("[IdleRaid] Workspace.IdleRaidVisuals must be a Folder")
		return
	end
	if not root then
		root = Instance.new("Folder")
		root.Name = "IdleRaidVisuals"
		root.Parent = Workspace
	end
	if not root:FindFirstChild("GeneratedField") then
		local generated = Instance.new("Folder")
		generated.Name = "GeneratedField"
		generated.Parent = root
		field(generated, onPortalTriggered)
	end
	local raidArena = Workspace:FindFirstChild("RaidArena")
	if raidArena and raidArena:IsA("Folder") then
		arenaVisuals(raidArena)
	end
end

return WorldVisualService
