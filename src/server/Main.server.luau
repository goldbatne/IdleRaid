local RunService = game:GetService("RunService")

local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local EquipmentService = require(script.Parent.EquipmentService)
local EnemyService = require(script.Parent.EnemyService)
local CombatService = require(script.Parent.CombatService)

PlayerDataService.Start()
InventoryService.Start()
EquipmentService.Start()
EnemyService.Start()
CombatService.Start()

if RunService:IsStudio() then
	local debugState = Instance.new("BindableFunction")
	debugState.Name = "DebugGetPlayerState"
	debugState.OnInvoke = function(player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return nil
		end
		local state = PlayerDataService.GetSnapshot(player)
		if not state then
			return nil
		end
		state.Inventory = InventoryService.GetSnapshot(player)
		state.Equipment = EquipmentService.GetSnapshot(player)
		return state
	end
	debugState.Parent = script.Parent

	local debugGrant = Instance.new("BindableFunction")
	debugGrant.Name = "DebugGrantItem"
	debugGrant.OnInvoke = function(player, itemId, quantity)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then
			return false
		end
		return InventoryService.AddItem(player, itemId, quantity)
	end
	debugGrant.Parent = script.Parent
end

print("[IdleRaid] Server Started")
