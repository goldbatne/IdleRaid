local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local StateSyncService = require(script.Parent.StateSyncService)

local InventoryService = {}
local itemsByPlayer = {}

local function onPlayerAdded(player: Player)
	if not itemsByPlayer[player] then
		itemsByPlayer[player] = {}
	end
end

function InventoryService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		itemsByPlayer[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

function InventoryService.AddItem(player: Player, itemId: string, quantity: number): boolean
	local definition = ItemConfig.Items[itemId]
	if not definition or definition.Id ~= itemId then
		warn(string.format("[IdleRaid] Unknown ItemId: %s", tostring(itemId)))
		return false
	end
	if typeof(quantity) ~= "number" or quantity < 1 or quantity % 1 ~= 0 then
		warn(string.format("[IdleRaid] Invalid quantity for %s", itemId))
		return false
	end

	local items = itemsByPlayer[player]
	if not items then
		return false
	end

	local stack = items[itemId]
	if stack then
		stack.Quantity += quantity
	else
		stack = { ItemId = itemId, Quantity = quantity }
		items[itemId] = stack
	end
	print(string.format("[IdleRaid] %s obtained %s x%d", player.Name, definition.Name, stack.Quantity))
	StateSyncService.Push(player, { Kind = "Item", ItemId = itemId, Quantity = quantity })
	return true
end

function InventoryService.GetQuantity(player: Player, itemId: string): number
	local items = itemsByPlayer[player]
	local stack = items and items[itemId]
	return if stack then stack.Quantity else 0
end

function InventoryService.GetSnapshot(player: Player): { { ItemId: string, Quantity: number } }
	local snapshot = {}
	local items = itemsByPlayer[player]
	if not items then
		return snapshot
	end

	for _, stack in pairs(items) do
		table.insert(snapshot, { ItemId = stack.ItemId, Quantity = stack.Quantity })
	end
	table.sort(snapshot, function(a, b)
		return a.ItemId < b.ItemId
	end)
	return snapshot
end

-- Useful when called by server scripts; Studio's Command Bar uses DebugGetPlayerState for live data.
function InventoryService.PrintInventory(player: Player)
	local entries = {}
	for _, stack in ipairs(InventoryService.GetSnapshot(player)) do
		table.insert(entries, string.format("%s x%d", stack.ItemId, stack.Quantity))
	end
	print(string.format("[IdleRaid] Inventory %s: %s", player.Name, if #entries > 0 then table.concat(entries, ", ") else "(empty)"))
end

return InventoryService
