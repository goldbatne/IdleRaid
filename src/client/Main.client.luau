local CombatController = require(script.Parent.CombatController)
local AutoCombatController = require(script.Parent.AutoCombatController)
local StateController = require(script.Parent.StateController)
local UIController = require(script.Parent.UIController)

CombatController.Start()
AutoCombatController.Start()
UIController.Start()
StateController.Start()

print("[IdleRaid] Client Started")
