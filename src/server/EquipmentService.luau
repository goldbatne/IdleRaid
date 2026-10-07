local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local InventoryService = require(script.Parent.InventoryService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StatService = require(script.Parent.StatService)

local EquipmentService = {}
local equipmentByPlayer = {}
local validSlots = { Weapon = true, Armor = true, Accessory = true }

local function onPlayerAdded(player: Player)
	if not equipmentByPlayer[player] then
		equipmentByPlayer[player] = {}
	end
end

local function recalculate(player: Player)
	local attack, defense = StatService.GetEquipmentBonuses(equipmentByPlayer[player])
	PlayerDataService.SetEquipmentBonuses(player, attack, defense)
end

function EquipmentService.GetSnapshot(player: Player)
	local equipment = equipmentByPlayer[player]
	if not equipment then
		return nil
	end
	return {
		Weapon = equipment.Weapon,
		Armor = equipment.Armor,
		Accessory = equipment.Accessory,
	}
end

function EquipmentService.EquipItem(player: Player, itemId: any): boolean
	if typeof(itemId) ~= "string" then
		return false
	end
	local definition = ItemConfig.Items[itemId]
	if not definition or definition.Id ~= itemId or not validSlots[definition.Type] then
		return false
	end
	if InventoryService.GetQuantity(player, itemId) < 1 then
		return false
	end

	local equipment = equipmentByPlayer[player]
	if not equipment or not PlayerDataService.GetSnapshot(player) then
		return false
	end

	local slot = definition.Type
	if equipment[slot] == itemId then
		return true
	end
	equipment[slot] = itemId
	recalculate(player)
	print(string.format("[IdleRaid] %s equipped %s (%s)", player.Name, definition.Name, slot))
	return true
end

function EquipmentService.Unequip(player: Player, slot: any): boolean
	if typeof(slot) ~= "string" or not validSlots[slot] then
		return false
	end
	local equipment = equipmentByPlayer[player]
	if not equipment or not equipment[slot] then
		return false
	end
	equipment[slot] = nil
	recalculate(player)
	print(string.format("[IdleRaid] %s unequipped %s", player.Name, slot))
	return true
end

function EquipmentService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		equipmentByPlayer[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	local remoteFolder = ReplicatedStorage:FindFirstChild("IdleRaidRemotes")
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = "IdleRaidRemotes"
		remoteFolder.Parent = ReplicatedStorage
	end

	local equipRemote = Instance.new("RemoteEvent")
	equipRemote.Name = "EquipItem"
	equipRemote.Parent = remoteFolder
	equipRemote.OnServerEvent:Connect(function(player, itemId)
		EquipmentService.EquipItem(player, itemId)
	end)

	local unequipRemote = Instance.new("RemoteEvent")
	unequipRemote.Name = "UnequipEquipment"
	unequipRemote.Parent = remoteFolder
	unequipRemote.OnServerEvent:Connect(function(player, slot)
		EquipmentService.Unequip(player, slot)
	end)
end

return EquipmentService
