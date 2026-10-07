local PlayerDataService = require(script.Parent.PlayerDataService)
local EnemyService = require(script.Parent.EnemyService)
local CombatService = require(script.Parent.CombatService)

PlayerDataService.Start()
EnemyService.Start()
CombatService.Start()

print("[IdleRaid] Server Started")
