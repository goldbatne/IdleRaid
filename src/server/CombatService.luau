local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local EnemyService = require(script.Parent.EnemyService)
local PlayerDataService = require(script.Parent.PlayerDataService)

local CombatService = {}
local lastAttackAt = {}

local function onAttackRequested(player: Player, target: any)
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return
	end

	local targetPosition = EnemyService.GetAttackPosition(target)
	if not targetPosition then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	if (root.Position - targetPosition).Magnitude > GameConfig.Combat.AttackRange then
		return
	end

	local now = os.clock()
	if now - (lastAttackAt[player] or -math.huge) < GameConfig.Combat.AttackCooldown then
		return
	end

	local attack = PlayerDataService.GetAttack(player)
	if not attack then
		return
	end

	lastAttackAt[player] = now
	local dealt, killed = EnemyService.ApplyDamage(target, attack)
	if dealt <= 0 then
		return
	end

	print(string.format("[IdleRaid] %s dealt %d damage", player.Name, dealt))
	if killed then
		print(string.format("[IdleRaid] %s killed TrainingDummy", player.Name))
		PlayerDataService.AddExp(player, GameConfig.TrainingDummy.KillExp)
	end
end

function CombatService.Start()
	local remoteFolder = ReplicatedStorage:FindFirstChild("IdleRaidRemotes")
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = "IdleRaidRemotes"
		remoteFolder.Parent = ReplicatedStorage
	end

	local attackRemote = remoteFolder:FindFirstChild("BasicAttack")
	if not attackRemote then
		attackRemote = Instance.new("RemoteEvent")
		attackRemote.Name = "BasicAttack"
		attackRemote.Parent = remoteFolder
	end

	attackRemote.OnServerEvent:Connect(onAttackRequested)
	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player] = nil
	end)
end

return CombatService
