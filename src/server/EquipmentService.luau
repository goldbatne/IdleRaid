local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local InventoryService = require(script.Parent.InventoryService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProfileStore = require(script.Parent.ProfileStore)

local EquipmentService = {}
local validSlots = { Weapon = true, Armor = true, Accessory = true }

function EquipmentService.GetSnapshot(player: Player)
	local profile = ProfileStore.Get(player)
	if not profile then return nil end
	return {
		Weapon = profile.Equipment.Weapon,
		Armor = profile.Equipment.Armor,
		Accessory = profile.Equipment.Accessory,
	}
end

function EquipmentService.EquipItem(player: Player, itemId: any): boolean
	if typeof(itemId) ~= "string" then return false end
	local definition = ItemConfig.Items[itemId]
	if not definition or definition.Id ~= itemId or not validSlots[definition.Type] then return false end
	if InventoryService.GetQuantity(player, itemId) < 1 then return false end
	local profile = ProfileStore.Get(player)
	if not profile then return false end
	local slot = definition.Type
	if profile.Equipment[slot] == itemId then return true end
	profile.Equipment[slot] = itemId
	PlayerDataService.RecalculateStats(player)
	print(string.format("[IdleRaid] %s equipped %s (%s)", player.Name, definition.Name, slot))
	return true
end

function EquipmentService.Unequip(player: Player, slot: any): boolean
	if typeof(slot) ~= "string" or not validSlots[slot] then return false end
	local profile = ProfileStore.Get(player)
	if not profile or not profile.Equipment[slot] then return false end
	profile.Equipment[slot] = nil
	PlayerDataService.RecalculateStats(player)
	return true
end

function EquipmentService.Start()
	local remoteFolder = ReplicatedStorage:FindFirstChild("IdleRaidRemotes")
	if not remoteFolder then
		remoteFolder = Instance.new("Folder")
		remoteFolder.Name = "IdleRaidRemotes"
		remoteFolder.Parent = ReplicatedStorage
	end
	local equipRemote = Instance.new("RemoteEvent")
	equipRemote.Name = "EquipItem"
	equipRemote.Parent = remoteFolder
	equipRemote.OnServerEvent:Connect(function(player, itemId) EquipmentService.EquipItem(player, itemId) end)
	local unequipRemote = Instance.new("RemoteEvent")
	unequipRemote.Name = "UnequipEquipment"
	unequipRemote.Parent = remoteFolder
	unequipRemote.OnServerEvent:Connect(function(player, slot) EquipmentService.Unequip(player, slot) end)
end

return EquipmentService
