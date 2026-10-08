local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.ProfileStore)
local PlayerDataService = require(script.Parent.PlayerDataService)
local InventoryService = require(script.Parent.InventoryService)
local EquipmentService = require(script.Parent.EquipmentService)
local EnemyService = require(script.Parent.EnemyService)
local WorldVisualService = require(script.Parent.WorldVisualService)
local CombatService = require(script.Parent.CombatService)
local RaidService = require(script.Parent.RaidService)
local GrowthService = require(script.Parent.GrowthService)
local TrainingService = require(script.Parent.TrainingService)
local MonetizationService = require(script.Parent.MonetizationService)
local StateSyncService = require(script.Parent.StateSyncService)

PlayerDataService.Start()
InventoryService.Start()
EquipmentService.Start()
EnemyService.Start()
RaidService.Start()
GrowthService.SetRaidBusyCheck(function(player)
	local raid = RaidService.GetSnapshot(player)
	return raid and raid.IsParticipant == true or false
end)
GrowthService.Start()
TrainingService.Start()
MonetizationService.Start()
WorldVisualService.Start(RaidService.Join)
CombatService.Start()

local function getPlayerState(player: Player, kind: string?)
	local state = PlayerDataService.GetSnapshot(player)
	if not state then return nil end
	if kind == "Growth" or not state.Ready then return state end
	state.Inventory = InventoryService.GetSnapshot(player)
	state.Equipment = EquipmentService.GetSnapshot(player)
	state.Raid = RaidService.GetSnapshot(player)
	state.OfflineSummary = ProfileStore.GetOfflineSummary(player)
	return state
end

StateSyncService.Start(getPlayerState)

if RunService:IsStudio() then
	local debugState = Instance.new("BindableFunction")
	debugState.Name = "DebugGetPlayerState"
	debugState.OnInvoke = function(player)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return nil end
		return getPlayerState(player, "Full")
	end
	debugState.Parent = script.Parent

	local debugGrant = Instance.new("BindableFunction")
	debugGrant.Name = "DebugGrantItem"
	debugGrant.OnInvoke = function(player, itemId, quantity)
		if typeof(player) ~= "Instance" or not player:IsA("Player") then return false end
		return InventoryService.AddItem(player, itemId, quantity)
	end
	debugGrant.Parent = script.Parent

	local debugItemRemote = Instance.new("RemoteFunction")
	debugItemRemote.Name = "StudioInventoryGrant"
	debugItemRemote.OnServerInvoke = function(player, itemId)
		return InventoryService.AddItem(player, itemId, 1)
	end
	debugItemRemote.Parent = game:GetService("ReplicatedStorage"):WaitForChild("IdleRaidRemotes")
end

print("[IdleRaid] Server Started")
