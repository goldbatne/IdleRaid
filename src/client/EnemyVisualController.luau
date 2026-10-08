local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local EnemyVisualController = {}

function EnemyVisualController.Start()
	local folder = Workspace:WaitForChild("Enemies")
	local tracked = {}
	local serial = 0

	local function register(model: Instance)
		if not model:IsA("Model") or tracked[model] then return end
		local body = model.PrimaryPart
		if not body then return end
		local initialHealth = model:GetAttribute("Health")
		local state = {
			BasePivot = model:GetPivot(),
			BaseColor = body.Color,
			Health = initialHealth,
			Phase = #folder:GetChildren() * 0.7,
			Flash = 0,
		}
		tracked[model] = state
		local function updateHealth()
			local health = model:GetAttribute("Health")
			local maxHealth = model:GetAttribute("MaxHealth")
			local nameplate = model:FindFirstChild("Nameplate")
			local track = nameplate and nameplate:FindFirstChild("HealthTrack")
			local fill = track and track:FindFirstChild("Fill")
			if fill and fill:IsA("Frame") and typeof(health) == "number" and typeof(maxHealth) == "number" then
				fill.Size = UDim2.fromScale(math.clamp(health / math.max(1, maxHealth), 0, 1), 1)
			end
			if typeof(health) == "number" and typeof(state.Health) == "number" and health < state.Health and health > 0 then
				state.Flash += 1
				local flash = state.Flash
				body.Color = Color3.fromRGB(255, 246, 249)
				task.delay(0.12, function()
					if tracked[model] == state and state.Flash == flash and body.Parent then
						body.Color = state.BaseColor
					end
				end)
			end
			state.Health = health
		end
		state.HealthConnection = model:GetAttributeChangedSignal("Health"):Connect(updateHealth)
		state.DestroyConnection = model.Destroying:Connect(function()
			state.HealthConnection:Disconnect()
			state.DestroyConnection:Disconnect()
			tracked[model] = nil
		end)
		updateHealth()
	end

	for _, child in ipairs(folder:GetChildren()) do register(child) end
	folder.ChildAdded:Connect(register)

	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.05 then return end
		elapsed = 0
		local now = os.clock()
		for model, state in pairs(tracked) do
			if model.Parent == folder and model:GetAttribute("IsBoss") ~= true and model.PrimaryPart then
				model:PivotTo(state.BasePivot * CFrame.new(0, math.sin(now * 2.8 + state.Phase) * 0.16, 0))
			end
		end
	end)

	ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("RaidTelegraph").OnClientEvent:Connect(function(kind, _, _, third, duration)
		local boss = folder:FindFirstChild("SlimeKing")
		local highlight = boss and boss:FindFirstChild("VisualHighlight")
		if not highlight or not highlight:IsA("Highlight") then return end
		serial += 1
		local this = serial
		highlight.FillColor = if kind == "Slam" then Color3.fromRGB(255, 164, 75) else Color3.fromRGB(208, 112, 255)
		highlight.FillTransparency = 0.55
		local lifetime = if kind == "Slam" then third else duration
		task.delay(if typeof(lifetime) == "number" then lifetime else 1, function()
			if serial == this and highlight.Parent then
				highlight.FillTransparency = 1
			end
		end)
	end)
end

return EnemyVisualController
