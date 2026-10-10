-- Source-path audit only; this does not simulate mobile touch or movement.
local client = game:GetService("StarterPlayer").StarterPlayerScripts:WaitForChild("Client")
local auto = client.AutoCombatController.Source
local state = client.StateController.Source
local combat = client.CombatController.Source
local ui = client.UIController.Source
print("IR_REVIEW_R06_SOURCE_UNCONDITIONAL_CANCEL", auto:find("or not raidActive or raidDefeated", 1, true) ~= nil)
print("IR_REVIEW_R07_SOURCE_CLEAR_PROTOCOL", state:find("_ClearKeys", 1, true) ~= nil)
print("IR_REVIEW_R09_SOURCE_TOUCH_BUTTON", combat:find("AttackFocused", 1, true) ~= nil
 and ui:find("TouchAttack", 1, true) ~= nil)
