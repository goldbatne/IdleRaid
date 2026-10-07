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

		local hitPart = mouse.Target
		local target = hitPart and hitPart:FindFirstAncestorOfClass("Model")
		if target and target.Name == "TrainingDummy" then
			attackRemote:FireServer(target)
		end
	end)
end

return CombatController
