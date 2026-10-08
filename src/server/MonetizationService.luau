local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GrowthConfig = require(ReplicatedStorage.Shared.GrowthConfig)
local SafeInteger = require(ReplicatedStorage.Shared.SafeInteger)
local GrowthService = require(script.Parent.GrowthService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProfileStore = require(script.Parent.ProfileStore)

local MonetizationService = {}
local byProductId = {}
local receiptBusy = {}

local function contractForId(productId: any)
	if not SafeInteger.IsValid(productId) or productId < 1 then return nil, nil end
	return byProductId[productId]
end

local function grantFixedOwnership(profile, productKey: string, contract): boolean
	local bucket, key
	if contract.Kind == "Ticket" then
		bucket, key = profile.BreakthroughTickets, tostring(contract.Value)
	elseif contract.Kind == "Voucher" then
		bucket, key = profile.TrainingVouchers, contract.Value
	else return false end
	local nextCount = SafeInteger.Add(bucket[key] or 0, 1)
	if not nextCount then return false end
	bucket[key] = nextCount
	return true
end

function MonetizationService.ProcessSynthetic(player: Player, purchaseId: string, productKey: string)
	if typeof(purchaseId) ~= "string" or #purchaseId < 1 or #purchaseId > 128 then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local contract = GrowthConfig.Products[productKey]
	if not contract or contract.ContractVersion ~= 1 then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = ProfileStore.Get(player)
	if not profile then return Enum.ProductPurchaseDecision.NotProcessedYet end
	if receiptBusy[player] then return Enum.ProductPurchaseDecision.NotProcessedYet end
	receiptBusy[player] = true
	ProfileStore.SetReceiptPending(player, true)
	local recorded = profile.ProcessedPurchases[purchaseId]
	local expectedRecord = productKey .. ":v" .. tostring(contract.ContractVersion)
	if recorded and recorded ~= expectedRecord then
		receiptBusy[player] = nil
		ProfileStore.SetReceiptPending(player, false)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not recorded then
		if not grantFixedOwnership(profile, productKey, contract) then
			receiptBusy[player] = nil
			ProfileStore.SetReceiptPending(player, false)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		profile.ProcessedPurchases[purchaseId] = expectedRecord
		PlayerDataService.AfterGrowthChange(player, nil, { Kind = "Ownership", Item = productKey, Count = 1 })
	end
	local saved = ProfileStore.SaveReceipt(player, purchaseId)
	receiptBusy[player] = nil
	if saved then
		ProfileStore.SetReceiptPending(player, false)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

local function processReceipt(receiptInfo)
	if typeof(receiptInfo) ~= "table" then return Enum.ProductPurchaseDecision.NotProcessedYet end
	local productKey = contractForId(receiptInfo.ProductId)
	if not productKey or typeof(receiptInfo.PurchaseId) ~= "string" then
		warn("[IdleRaid] Unconfigured product receipt retained for retry")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if not SafeInteger.IsValid(receiptInfo.PlayerId) or receiptInfo.PlayerId < 1 then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then return Enum.ProductPurchaseDecision.NotProcessedYet end
	return MonetizationService.ProcessSynthetic(player, receiptInfo.PurchaseId, productKey)
end

function MonetizationService.Start()
	for productKey, contract in pairs(GrowthConfig.Products) do
		local productId = contract.ProductId
		if productId ~= nil then
			assert(SafeInteger.IsValid(productId) and productId > 0 and not byProductId[productId],
				"Invalid or duplicate developer ProductId")
			byProductId[productId] = productKey
		end
	end
	-- A valid earlier receipt is processed even when new purchase prompts are disabled.
	MarketplaceService.ProcessReceipt = processReceipt
	Players.PlayerRemoving:Connect(function(player) receiptBusy[player] = nil end)
	if RunService:IsStudio() then
		local debugReceipt = Instance.new("BindableFunction")
		debugReceipt.Name = "DebugProcessSyntheticReceipt"
		debugReceipt.OnInvoke = function(player, purchaseId, productKey)
			if typeof(player) ~= "Instance" or not player:IsA("Player") then return nil end
			return MonetizationService.ProcessSynthetic(player, purchaseId, productKey)
		end
		debugReceipt.Parent = script.Parent
		local debugRemote = Instance.new("RemoteFunction")
		debugRemote.Name = "StudioSyntheticReceipt"
		debugRemote.Parent = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
		debugRemote.OnServerInvoke = function(player, purchaseId, productKey)
			return MonetizationService.ProcessSynthetic(player, purchaseId, productKey)
		end
	end
end

return MonetizationService
