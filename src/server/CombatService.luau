local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GrowthMath = require(ReplicatedStorage.Shared.GrowthMath)
local EnemyService = require(script.Parent.EnemyService)
local InventoryService = require(script.Parent.InventoryService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RaidService = require(script.Parent.RaidService)

local CombatService = {}
local lastAttackAt = {}
local rewardRandom = Random.new()
local visualRemote: RemoteEvent?

local function grantKillRewards(player: Player, enemyId: string)
	local definition = GameConfig.Enemies[enemyId]
	if not definition then
		warn(string.format("[IdleRaid] Missing rewards for EnemyId %s", enemyId))
		return
	end

	local profile = PlayerDataService.GetProfile(player)
	if not profile or not definition.ZoneId then return end
	local power = GrowthMath.EnemyPower(profile.BreakthroughStage, definition.ZoneId)
	if power then PlayerDataService.AddPowerFinal(player, power, "EnemyKill") end
	PlayerDataService.AddGold(player, rewardRandom:NextInteger(definition.GoldMin, definition.GoldMax))
	for _, drop in ipairs(definition.DropTable) do
		if typeof(drop.Chance) == "number" and drop.Chance >= 0 and drop.Chance <= 1 then
			if rewardRandom:NextNumber() < drop.Chance then
				InventoryService.AddItem(player, drop.ItemId, 1)
			end
		else
			warn(string.format("[IdleRaid] Invalid drop chance for %s", tostring(drop.ItemId)))
		end
	end
end

local function onAttackRequested(player: Player, target: any)
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return
	end

	if not EnemyService.IsAliveEnemy(target) or not RaidService.CanAttack(player, target) then
		return
	end
	local profile = PlayerDataService.GetProfile(player)
	local requiredStage = EnemyService.GetRequiredStage(target)
	if not profile or not requiredStage or profile.BreakthroughStage < requiredStage then return end

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

	local attack = PlayerDataService.GetFinalAttack(player)
	if not attack then
		return
	end

	local isBoss = target:GetAttribute("IsBoss") == true
	local dealt, killed, enemyId = EnemyService.ApplyDamage(target, attack)
	if dealt <= 0 then
		return
	end

	lastAttackAt[player] = now
	if visualRemote then
		visualRemote:FireAllClients(player, enemyId, targetPosition, dealt, killed)
	end
	print(string.format("[IdleRaid] %s dealt %d damage to %s", player.Name, dealt, enemyId))
	if isBoss then
		RaidService.OnBossDamaged(player, target, dealt, killed)
	elseif killed then
		print(string.format("[IdleRaid] %s killed %s", player.Name, enemyId))
		grantKillRewards(player, enemyId)
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

	visualRemote = Instance.new("RemoteEvent")
	visualRemote.Name = "CombatVisual"
	visualRemote.Parent = remoteFolder

	attackRemote.OnServerEvent:Connect(onAttackRequested)
	Players.PlayerRemoving:Connect(function(player)
		lastAttackAt[player] = nil
	end)
end

return CombatService
