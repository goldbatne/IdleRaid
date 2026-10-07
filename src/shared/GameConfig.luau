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
	TrainingDummy = {
		MaxHealth = 50,
		KillExp = 40,
		RespawnTime = 3,
		SpawnDistanceFromPlayerSpawn = 10,
	},
}

return GameConfig
