local CombatController = require(script.Parent.CombatController)
local AutoCombatController = require(script.Parent.AutoCombatController)
local StateController = require(script.Parent.StateController)
local DashController = require(script.Parent.DashController)
local UIController = require(script.Parent.UIController)

CombatController.Start()
AutoCombatController.Start()
DashController.Start()
UIController.Start()
StateController.Start()

print("[IdleRaid] Client Started")
