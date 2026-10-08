local EnemyAppearance = {}

local function part(model: Model, body: BasePart, name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Shape = Enum.PartType.Ball
	piece.Size = size
	piece.Color = color
	piece.Material = material
	piece.Anchored = false
	piece.Massless = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CFrame = body.CFrame * CFrame.new(offset)
	piece.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = piece
	weld.Parent = piece
end

local function nameplate(model: Model, body: BasePart, definition, isBoss: boolean)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Adornee = body
	gui.AlwaysOnTop = true
	gui.MaxDistance = if isBoss then 100 else 55
	gui.Size = UDim2.fromOffset(if isBoss then 180 else 120, 42)
	gui.StudsOffsetWorldSpace = Vector3.new(0, body.Size.Y / 2 + 1.2, 0)
	gui.Parent = model
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 24)
	title.Font = Enum.Font.GothamBold
	title.TextSize = if isBoss then 18 else 14
	title.TextStrokeTransparency = 0.35
	title.TextColor3 = if isBoss then Color3.fromRGB(255, 222, 117) else Color3.fromRGB(255, 255, 255)
	title.Text = string.format("Lv.%d  %s", definition.Level, definition.Name or definition.Id)
	title.Parent = gui
	local track = Instance.new("Frame")
	track.Name = "HealthTrack"
	track.BorderSizePixel = 0
	track.BackgroundColor3 = Color3.fromRGB(22, 32, 45)
	track.Position = UDim2.new(0, 4, 0, 27)
	track.Size = UDim2.new(1, -8, 0, 8)
	track.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = if isBoss then Color3.fromRGB(255, 105, 113) else Color3.fromRGB(119, 238, 151)
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
end

function EnemyAppearance.Apply(model: Model, body: BasePart, definition)
	local isBoss = definition.IsBoss == true
	local scale = if isBoss then 2.3 else 1
	body.Material = Enum.Material.SmoothPlastic
	body.Color = if isBoss then Color3.fromRGB(84, 127, 238) else Color3.fromRGB(91, 215, 137)
	local white = Color3.fromRGB(248, 252, 255)
	local ink = Color3.fromRGB(25, 41, 65)
	for _, sign in ipairs({ -1, 1 }) do
		part(model, body, if sign < 0 then "LeftEye" else "RightEye",
			Vector3.new(0.4, 0.53, 0.2) * scale,
			Vector3.new(sign * 0.55, 0.27, -1.35) * scale, white, Enum.Material.SmoothPlastic)
		part(model, body, if sign < 0 then "LeftPupil" else "RightPupil",
			Vector3.new(0.2, 0.3, 0.12) * scale,
			Vector3.new(sign * 0.55, 0.24, -1.49) * scale, ink, Enum.Material.SmoothPlastic)
		part(model, body, if sign < 0 then "LeftCheek" else "RightCheek",
			Vector3.new(0.31, 0.14, 0.12) * scale,
			Vector3.new(sign * 0.98, -0.28, -1.15) * scale,
			Color3.fromRGB(250, 145, 170), Enum.Material.SmoothPlastic)
	end
	part(model, body, "Smile", Vector3.new(0.52, 0.12, 0.12) * scale,
		Vector3.new(0, -0.37, -1.43) * scale, ink, Enum.Material.SmoothPlastic)
	if isBoss then
		local gold = Color3.fromRGB(255, 204, 75)
		part(model, body, "CrownBand", Vector3.new(4.9, 0.42, 4.9), Vector3.new(0, 3.43, 0), gold, Enum.Material.Metal)
		for index, x in ipairs({ -1.55, 0, 1.55 }) do
			part(model, body, "CrownPoint" .. index, Vector3.new(0.8, if index == 2 then 1.35 else 1, 0.8),
				Vector3.new(x, 4.03, -1.1), gold, Enum.Material.Metal)
		end
		part(model, body, "CrownGem", Vector3.new(0.55, 0.65, 0.2),
			Vector3.new(0, 3.48, -2.42), Color3.fromRGB(255, 88, 129), Enum.Material.Neon)
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "VisualHighlight"
	highlight.Adornee = model
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.OutlineColor = if isBoss then Color3.fromRGB(255, 204, 92) else Color3.fromRGB(45, 119, 92)
	highlight.OutlineTransparency = if isBoss then 0.1 else 0.32
	highlight.FillTransparency = 1
	highlight.Parent = model
	nameplate(model, body, definition, isBoss)
end

return EnemyAppearance
