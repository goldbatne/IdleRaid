local RunService = game:GetService("RunService")

local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local EnemyService = require(script.Parent.EnemyService)
local CombatService = require(script.Parent.CombatService)

PlayerDataService.Start()
InventoryService.Start()
EnemyService.Start()
CombatService.Start()

if RunService:IsStudio() then
	local debugState = Instance.new("BindableFunction")
	debugState.Name = "DebugGetPlayerState"
	debugState.OnInvoke = function(player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return nil
		end
		return {
			Gold = PlayerDataService.GetGold(player),
			Inventory = InventoryService.GetSnapshot(player),
		}
	end
	debugState.Parent = script.Parent
end

print("[IdleRaid] Server Started")
