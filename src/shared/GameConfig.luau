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
			RespawnTime = 3,
			Attack = 0,
			Level = 1,
			Color = Color3.fromRGB(85, 205, 105),
		},
	},
}

return GameConfig
