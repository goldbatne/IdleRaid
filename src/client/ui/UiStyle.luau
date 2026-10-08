local UiStyle = {}

UiStyle.Colors = {
	Panel = Color3.fromRGB(25, 35, 66),
	Surface = Color3.fromRGB(42, 58, 95),
	Accent = Color3.fromRGB(82, 210, 191),
	Gold = Color3.fromRGB(255, 205, 116),
	Text = Color3.fromRGB(247, 249, 255),
	Muted = Color3.fromRGB(182, 199, 221),
}

UiStyle.Rarities = {
	Common = Color3.fromRGB(229, 235, 244),
	Uncommon = Color3.fromRGB(116, 237, 174),
	Rare = Color3.fromRGB(115, 190, 255),
	Epic = Color3.fromRGB(199, 139, 255),
	Legendary = Color3.fromRGB(255, 197, 91),
}

function UiStyle.Corner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
end

function UiStyle.Outline(parent: Instance, color: Color3, transparency: number)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Outline"
	stroke.Color = color
	stroke.Transparency = transparency
	stroke.Thickness = 1.5
	stroke.Parent = parent
	return stroke
end

function UiStyle.Panel(parent: Frame, radius: number)
	UiStyle.Corner(parent, radius)
	UiStyle.Outline(parent, UiStyle.Colors.Accent, 0.54)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(39, 58, 100)),
		ColorSequenceKeypoint.new(1, UiStyle.Colors.Panel),
	})
	gradient.Rotation = 90
	gradient.Parent = parent
end

function UiStyle.Text(parent: Instance, name: string, value: string, size: UDim2, position: UDim2)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Text = value
	label.TextColor3 = UiStyle.Colors.Text
	label.TextSize = 16
	label.Font = Enum.Font.Gotham
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Size = size
	label.Position = position
	label.Parent = parent
	return label
end

function UiStyle.Button(parent: Instance, name: string, value: string, size: UDim2, position: UDim2)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = true
	button.BackgroundColor3 = UiStyle.Colors.Surface
	button.BorderSizePixel = 0
	button.Text = value
	button.TextColor3 = UiStyle.Colors.Text
	button.TextSize = 15
	button.Font = Enum.Font.GothamBold
	button.TextWrapped = true
	button.Size = size
	button.Position = position
	UiStyle.Corner(button, 9)
	UiStyle.Outline(button, UiStyle.Colors.Muted, 0.72)
	button.Parent = parent
	return button
end

return UiStyle
