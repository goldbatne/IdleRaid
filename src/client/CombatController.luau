local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CombatController = {}
local attackRemote

local function requestEnemy(hit: Instance?)
	while hit and hit ~= Workspace do
		if hit:IsA("Model") and hit:GetAttribute("EnemyId") then
			attackRemote:FireServer(hit)
			return
		end
		hit = hit.Parent
	end
end

function CombatController.AttackFocused()
	if not attackRemote then return end
	local camera = Workspace.CurrentCamera
	if not camera then return end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local character = Players.LocalPlayer.Character
	params.FilterDescendantsInstances = if character then { character } else {}
	local hit = Workspace:Raycast(camera.CFrame.Position, camera.CFrame.LookVector * 500, params)
	if hit then requestEnemy(hit.Instance) end
end

function CombatController.Start()
	local mouse = Players.LocalPlayer:GetMouse()
	attackRemote = ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("BasicAttack")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		requestEnemy(mouse.Target)
	end)
end

return CombatController
