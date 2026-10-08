local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local AutoCombatController = require(script.Parent.AutoCombatController)
local StateController = require(script.Parent.StateController)

local DashController = {}

local player = Players.LocalPlayer
local raidActive = false
local defeated = false
local lastRequestAt = -math.huge

local function inputDirection(root: BasePart, humanoid: Humanoid): Vector3
	local camera = Workspace.CurrentCamera
	local forward = camera and camera.CFrame.LookVector or root.CFrame.LookVector
	local right = camera and camera.CFrame.RightVector or root.CFrame.RightVector
	local direction = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		direction += forward
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		direction -= forward
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
		direction += right
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
		direction -= right
	end
	if direction.Magnitude < 0.01 and UserInputService.TouchEnabled then
		direction = humanoid.MoveDirection
	end
	if direction.Magnitude < 0.01 then
		direction = root.CFrame.LookVector
	end
	return Vector3.new(direction.X, 0, direction.Z)
end

function DashController.Request()
	if not raidActive or defeated or os.clock() - lastRequestAt < 0.1 then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return end
	local direction = inputDirection(root, humanoid)
	if direction.Magnitude < 0.01 then return end
	lastRequestAt = os.clock()
	AutoCombatController.PauseForDash()
	ReplicatedStorage.IdleRaidRemotes.RaidDash:FireServer(direction)
end

function DashController.Start()
	StateController.Subscribe(function(state)
		local raid = state.Raid or {}
		raidActive = raid.IsParticipant == true and raid.Status == "Active"
		defeated = raid.Defeated == true
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Q then
			DashController.Request()
		end
	end)
end

return DashController
