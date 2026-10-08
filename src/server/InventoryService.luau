local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local SafeInteger = require(ReplicatedStorage.Shared.SafeInteger)
local ProfileStore = require(script.Parent.ProfileStore)
local StateSyncService = require(script.Parent.StateSyncService)

local InventoryService = {}

function InventoryService.Start() end

function InventoryService.AddItem(player: Player, itemId: any, quantity: any): boolean
	if typeof(itemId) ~= "string" then return false end
	local definition = ItemConfig.Items[itemId]
	if not definition or definition.Id ~= itemId then
		warn(string.format("[IdleRaid] Unknown ItemId: %s", tostring(itemId)))
		return false
	end
	if not SafeInteger.IsValid(quantity) or quantity < 1 then return false end
	local profile = ProfileStore.Get(player)
	if not profile then return false end
	local nextQuantity = SafeInteger.Add(profile.Inventory[itemId] or 0, quantity)
	if not nextQuantity then return false end
	profile.Inventory[itemId] = nextQuantity
	ProfileStore.Touch(player)
	StateSyncService.Push(player, { Kind = "Item", ItemId = itemId, Quantity = quantity })
	print(string.format("[IdleRaid] %s obtained %s x%d", player.Name, definition.Name, nextQuantity))
	return true
end

function InventoryService.GetQuantity(player: Player, itemId: string): number
	local profile = ProfileStore.Get(player)
	return if profile then profile.Inventory[itemId] or 0 else 0
end

function InventoryService.GetSnapshot(player: Player): { { ItemId: string, Quantity: number } }
	local snapshot = {}
	local profile = ProfileStore.Get(player)
	if not profile then return snapshot end
	for itemId, quantity in pairs(profile.Inventory) do
		table.insert(snapshot, { ItemId = itemId, Quantity = quantity })
	end
	table.sort(snapshot, function(a, b) return a.ItemId < b.ItemId end)
	return snapshot
end

function InventoryService.PrintInventory(player: Player)
	local entries = {}
	for _, stack in ipairs(InventoryService.GetSnapshot(player)) do
		table.insert(entries, string.format("%s x%d", stack.ItemId, stack.Quantity))
	end
	print(string.format("[IdleRaid] Inventory %s: %s", player.Name,
		if #entries > 0 then table.concat(entries, ", ") else "(empty)"))
end

return InventoryService
