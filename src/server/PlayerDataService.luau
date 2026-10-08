local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GrowthConfig = require(ReplicatedStorage.Shared.GrowthConfig)
local GrowthMath = require(ReplicatedStorage.Shared.GrowthMath)
local SafeInteger = require(ReplicatedStorage.Shared.SafeInteger)
local ProfileStore = require(script.Parent.ProfileStore)
local StatService = require(script.Parent.StatService)
local StateSyncService = require(script.Parent.StateSyncService)

local PlayerDataService = {}
local runtime = {}

local function makeStat(parent: Instance, name: string, value: number)
	local stat = Instance.new("IntValue")
	stat.Name = name
	stat.Value = value
	stat.Parent = parent
end

local function recalculate(player: Player)
	local profile = ProfileStore.Get(player)
	local data = runtime[player]
	if not profile or not data then return end
	local level = GrowthMath.LevelProgress(profile.LifetimeTrainingPower)
	local attackBonus, defenseBonus = StatService.GetEquipmentBonuses(profile.Equipment)
	data.FinalAttack, data.FinalDefense = StatService.Calculate({
		Level = level,
		BaseAttack = GameConfig.Player.InitialBaseAttack,
		BaseDefense = GameConfig.Player.InitialBaseDefense,
		EquipmentAttackBonus = attackBonus,
		EquipmentDefenseBonus = defenseBonus,
	})
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local _, exp = GrowthMath.LevelProgress(profile.LifetimeTrainingPower)
		for name, value in pairs({ Level = level, Exp = exp, Gold = profile.Gold,
			Attack = data.FinalAttack, Defense = data.FinalDefense }) do
			local stat = leaderstats:FindFirstChild(name)
			if stat then stat.Value = value end
		end
	end
end

local function onProfileReady(player: Player, ready: boolean)
	if not ready then StateSyncService.Push(player) return end
	runtime[player] = {
		MaxHealth = GameConfig.Player.InitialMaxHealth,
		Health = GameConfig.Player.InitialMaxHealth,
	}
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		for _, name in ipairs({ "Level", "Exp", "Gold", "Attack", "Defense" }) do
			makeStat(leaderstats, name, 0)
		end
		leaderstats.Parent = player
	end
	recalculate(player)
	StateSyncService.Push(player)
end

function PlayerDataService.Start()
	ProfileStore.Start(onProfileReady)
	Players.PlayerRemoving:Connect(function(player) runtime[player] = nil end)
end

function PlayerDataService.GetProfile(player: Player)
	return ProfileStore.Get(player)
end

function PlayerDataService.IsReady(player: Player): boolean
	return ProfileStore.Get(player) ~= nil
end

function PlayerDataService.GetGrowthSnapshot(player: Player)
	local profile = ProfileStore.Get(player)
	if not profile then return { Ready = false, LoadStatus = ProfileStore.GetStatus(player), StateRevision = 0 } end
	local data = runtime[player]
	local level, exp, required = GrowthMath.LevelProgress(profile.LifetimeTrainingPower)
	local multiplier = GrowthMath.StageMultiplier(profile.BreakthroughStage)
	return {
		Ready = true,
		StateRevision = profile.StateRevision,
		Level = level,
		Exp = exp,
		ExpRequired = required,
		Gold = profile.Gold,
		RaidToken = profile.RaidToken,
		BaseAttack = GameConfig.Player.InitialBaseAttack,
		FinalAttack = data and data.FinalAttack or 0,
		BaseDefense = GameConfig.Player.InitialBaseDefense,
		FinalDefense = data and data.FinalDefense or 0,
		Health = data and data.Health or 0,
		MaxHealth = data and data.MaxHealth or GameConfig.Player.InitialMaxHealth,
		AvailableTrainingPower = profile.AvailableTrainingPower,
		LifetimeTrainingPower = profile.LifetimeTrainingPower,
		BreakthroughStage = profile.BreakthroughStage,
		TrainingFacilityTier = profile.TrainingFacilityTier,
		TrainingEnabled = profile.TrainingEnabled,
		StageMultiplier = multiplier,
		BaseTrainingRate = GrowthMath.BaseRate(profile.BreakthroughStage, profile.TrainingFacilityTier),
		BreakthroughCost = if profile.BreakthroughStage < GrowthConfig.MaxStage
			then GrowthMath.BreakthroughCost(profile.BreakthroughStage) else nil,
		BreakthroughTickets = table.clone(profile.BreakthroughTickets),
		TrainingVouchers = table.clone(profile.TrainingVouchers),
		ClearedRaidGates = table.clone(profile.ClearedRaidGates),
	}
end

function PlayerDataService.GetSnapshot(player: Player)
	return PlayerDataService.GetGrowthSnapshot(player)
end

function PlayerDataService.GetFinalAttack(player: Player): number?
	local data = runtime[player]
	return if ProfileStore.Get(player) and data then data.FinalAttack else nil
end

function PlayerDataService.GetGold(player: Player): number?
	local profile = ProfileStore.Get(player)
	return profile and profile.Gold or nil
end

function PlayerDataService.GetHealth(player: Player): number?
	local data = runtime[player]
	return if ProfileStore.Get(player) and data then data.Health else nil
end

function PlayerDataService.RecalculateStats(player: Player)
	if not ProfileStore.Get(player) then return end
	ProfileStore.Touch(player)
	recalculate(player)
	StateSyncService.Push(player)
end

function PlayerDataService.AfterGrowthChange(player: Player, oldLifetime: number?, notification)
	local profile = ProfileStore.Get(player)
	if not profile then return end
	ProfileStore.Touch(player)
	recalculate(player)
	StateSyncService.PushGrowth(player, notification)
	if oldLifetime then
		local oldLevel = GrowthMath.LevelProgress(oldLifetime)
		local newLevel = GrowthMath.LevelProgress(profile.LifetimeTrainingPower)
		for level = oldLevel + 1, newLevel do
			print(string.format("[IdleRaid] %s reached Level %d", player.Name, level))
		end
	end
end

function PlayerDataService.AddPowerFinal(player: Player, amount: number, source: string?): boolean
	local profile = ProfileStore.Get(player)
	if not profile or not SafeInteger.IsValid(amount) or amount < 1 then return false end
	local available = SafeInteger.Add(profile.AvailableTrainingPower, amount)
	local lifetime = SafeInteger.Add(profile.LifetimeTrainingPower, amount)
	if not available or not lifetime then return false end
	local oldLifetime = profile.LifetimeTrainingPower
	profile.AvailableTrainingPower = available
	profile.LifetimeTrainingPower = lifetime
	PlayerDataService.AfterGrowthChange(player, oldLifetime)
	if source and source ~= "OnlineTraining" then
		print(string.format("[IdleRaid] %s gained %d Training Power from %s", player.Name, amount, source))
	end
	return true
end

-- Legacy server callers receive a final award, never an extra stage/facility multiplier.
function PlayerDataService.AddExp(player: Player, amount: number)
	return PlayerDataService.AddPowerFinal(player, amount, "LegacyReward")
end

function PlayerDataService.AddGold(player: Player, amount: number): boolean
	local profile = ProfileStore.Get(player)
	if not profile or not SafeInteger.IsValid(amount) or amount < 1 then return false end
	local nextGold = SafeInteger.Add(profile.Gold, amount)
	if not nextGold then return false end
	profile.Gold = nextGold
	PlayerDataService.AfterGrowthChange(player)
	return true
end

function PlayerDataService.SpendGold(player: Player, amount: number): boolean
	local profile = ProfileStore.Get(player)
	if not profile or not SafeInteger.IsValid(amount) or amount < 1 or amount > profile.Gold then return false end
	profile.Gold -= amount
	PlayerDataService.AfterGrowthChange(player)
	return true
end

function PlayerDataService.AddRaidToken(player: Player, amount: number): boolean
	local profile = ProfileStore.Get(player)
	if not profile or not SafeInteger.IsValid(amount) or amount < 1 then return false end
	local nextToken = SafeInteger.Add(profile.RaidToken, amount)
	if not nextToken then return false end
	profile.RaidToken = nextToken
	PlayerDataService.AfterGrowthChange(player)
	return true
end

function PlayerDataService.ResetRaidHealth(player: Player): boolean
	local data = runtime[player]
	if not data or not ProfileStore.Get(player) then return false end
	data.Health = data.MaxHealth
	PlayerDataService.AfterGrowthChange(player)
	return true
end

function PlayerDataService.ApplyRaidDamage(player: Player, amount: number): number?
	local data = runtime[player]
	if not data or not ProfileStore.Get(player) or not SafeInteger.IsValid(amount) or amount < 1 then return nil end
	data.Health = math.max(0, data.Health - amount)
	PlayerDataService.AfterGrowthChange(player)
	return data.Health
end

-- Kept for compatibility with equipment calls; final bonuses are derived from the unified profile.
function PlayerDataService.SetEquipmentBonuses(player: Player, _attack: number, _defense: number): boolean
	if not ProfileStore.Get(player) then return false end
	PlayerDataService.RecalculateStats(player)
	return true
end

return PlayerDataService
