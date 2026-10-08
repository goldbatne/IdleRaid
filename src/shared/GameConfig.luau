local GrowthConfig = require(script.Parent.GrowthConfig)

local GameConfig = {
	Player = {
		InitialGold = 0,
		InitialBaseAttack = 10,
		InitialBaseDefense = 0,
		InitialMaxHealth = 100,
	},
	Level = {
		AttackIncreasePerLevel = 2,
	},
	Combat = {
		AttackRange = 15,
		AttackCooldown = 0.6,
	},
	AutoCombat = {
		TargetScanInterval = 0.25,
		AttackRequestInterval = 0.65,
		ApproachDistance = 12,
		MoveRefreshInterval = 1,
	},
	EnemySpawns = {
		DefaultEnemyId = "Slime",
		DefaultCount = 5,
		DistanceFromPlayerSpawn = 10,
		Spacing = 6,
	},
	Raid = {
		MaxPlayers = 4,
		JoinWindow = 5,
		ResultDuration = 4,
		Dash = { Distance = 12, Cooldown = 3, InvulnerableTime = 0.3, ManualPauseTime = 0.55 },
		ArenaInset = 4,
		BoundaryCheckInterval = 0.2,
		WarningFlashTime = 0.25,
		ArenaCenter = Vector3.new(0, 0, 250),
		ArenaSize = Vector3.new(100, 1, 100),
		BossHealthByPlayers = { 5000, 8500, 11500, 14000 },
		DifficultyByGate = {
			Gate10 = { HpMultiplier = 1, DamageMultiplier = 1, Gold = 100, Tokens = 1 },
			Gate20 = { HpMultiplier = 2, DamageMultiplier = 1.2, Gold = 1000, Tokens = 3 },
			Gate30 = { HpMultiplier = 4, DamageMultiplier = 1.4, Gold = 10000, Tokens = 6 },
		},
		RewardTrainingSeconds = 10,
		BossAttackInterval = 2,
		RecoveryTime = 1.5,
		Slam = { Damage = 25, Radius = 10, TelegraphTime = 1 },
		Charge = { Damage = 20, Width = 6, TelegraphTime = 0.8, TravelTime = 0.4, MaxDistance = 55 },
	},
	Enemies = {
		SlimeKing = {
			Id = "SlimeKing", Name = "Slime King", IsBoss = true,
			MaxHealth = 5000, Attack = 20, Level = 5,
			Size = Vector3.new(8, 8, 8), Color = Color3.fromRGB(90, 150, 225),
		},
		Slime = {
			Id = "Slime", ZoneId = "Field", RequiredStage = 1,
			MaxHealth = GrowthConfig.Zones[1].Health,
			GoldMin = GrowthConfig.Zones[1].GoldMin, GoldMax = GrowthConfig.Zones[1].GoldMax,
			DropTable = {
				{ ItemId = "TrainingSword", Chance = 0.15 },
				{ ItemId = "ClothArmor", Chance = 0.20 },
				{ ItemId = "SlimeCharm", Chance = 0.05 },
			},
			RespawnTime = 3, Attack = 0, Level = 1,
			Color = Color3.fromRGB(85, 205, 105),
		},
		SlimeVeteran = {
			Id = "SlimeVeteran", Name = "Veteran Slime", ZoneId = "Foothill", RequiredStage = 10,
			MaxHealth = GrowthConfig.Zones[2].Health,
			GoldMin = GrowthConfig.Zones[2].GoldMin, GoldMax = GrowthConfig.Zones[2].GoldMax,
			DropTable = { { ItemId = "IronSword", Chance = 0.08 }, { ItemId = "LeatherArmor", Chance = 0.12 } },
			RespawnTime = 3, Attack = 0, Level = 10,
			Color = Color3.fromRGB(85, 205, 105),
		},
		SlimeElder = {
			Id = "SlimeElder", Name = "Elder Slime", ZoneId = "Citadel", RequiredStage = 20,
			MaxHealth = GrowthConfig.Zones[3].Health,
			GoldMin = GrowthConfig.Zones[3].GoldMin, GoldMax = GrowthConfig.Zones[3].GoldMax,
			DropTable = { { ItemId = "IronSword", Chance = 0.12 }, { ItemId = "IronArmor", Chance = 0.12 } },
			RespawnTime = 3, Attack = 0, Level = 20,
			Color = Color3.fromRGB(85, 205, 105),
		},
	},
}

return GameConfig
