local GameConfig = {
	Player = {
		InitialLevel = 1,
		InitialExp = 0,
		InitialGold = 0,
		InitialAttack = 10,
	},
	Level = {
		BaseExpRequired = 100,
		ExpIncreasePerLevel = 50,
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
		Spacing = 3,
	},
	Enemies = {
		Slime = {
			Id = "Slime",
			MaxHealth = 40,
			KillExp = 20,
			GoldMin = 3,
			GoldMax = 7,
			DropTable = {
				{ ItemId = "TrainingSword", Chance = 0.15 },
				{ ItemId = "ClothArmor", Chance = 0.20 },
				{ ItemId = "SlimeCharm", Chance = 0.05 },
			},
			RespawnTime = 3,
			Attack = 0,
			Level = 1,
			Color = Color3.fromRGB(85, 205, 105),
		},
	},
}

return GameConfig
