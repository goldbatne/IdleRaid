local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local CombatController = {}

function CombatController.Start()
	local mouse = Players.LocalPlayer:GetMouse()
	local attackRemote = ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("BasicAttack")

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
			return
		end

		local target = mouse.Target
		while target and target ~= workspace do
			if target:IsA("Model") and target:GetAttribute("EnemyId") then
				attackRemote:FireServer(target)
				return
			end
			target = target.Parent
		end
	end)
end

return CombatController
