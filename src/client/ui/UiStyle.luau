local UiStyle = {}

UiStyle.Colors = {
	Panel = Color3.fromRGB(24, 31, 43),
	Surface = Color3.fromRGB(37, 48, 63),
	Accent = Color3.fromRGB(63, 160, 116),
	Text = Color3.fromRGB(245, 248, 250),
	Muted = Color3.fromRGB(184, 196, 208),
}

function UiStyle.Corner(parent: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
	return corner
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
	UiStyle.Corner(button, 8)
	button.Parent = parent
	return button
end

return UiStyle
