local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LevelService = require(script.Parent.LevelService)
local StatService = require(script.Parent.StatService)

local PlayerDataService = {}
local playerData = {}

local function makeStat(parent: Instance, name: string, value: number)
	local stat = Instance.new("IntValue")
	stat.Name = name
	stat.Value = value
	stat.Parent = parent
	return stat
end

local function updateLeaderstats(player: Player, data)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local displayed = {
		Level = data.Level,
		Exp = data.Exp,
		Gold = data.Gold,
		Attack = data.FinalAttack,
		Defense = data.FinalDefense,
	}
	for name, value in pairs(displayed) do
		local stat = leaderstats:FindFirstChild(name)
		if stat then
			stat.Value = value
		end
	end
end

local function onPlayerAdded(player: Player)
	if playerData[player] then
		return
	end

	local data = {
		Level = GameConfig.Player.InitialLevel,
		Exp = GameConfig.Player.InitialExp,
		Gold = GameConfig.Player.InitialGold,
		BaseAttack = GameConfig.Player.InitialBaseAttack,
		BaseDefense = GameConfig.Player.InitialBaseDefense,
		EquipmentAttackBonus = 0,
		EquipmentDefenseBonus = 0,
	}
	data.FinalAttack, data.FinalDefense = StatService.Calculate(data)
	playerData[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	makeStat(leaderstats, "Level", data.Level)
	makeStat(leaderstats, "Exp", data.Exp)
	makeStat(leaderstats, "Gold", data.Gold)
	makeStat(leaderstats, "Attack", data.FinalAttack)
	makeStat(leaderstats, "Defense", data.FinalDefense)
	leaderstats.Parent = player
end

function PlayerDataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		playerData[player] = nil
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end
end

function PlayerDataService.GetFinalAttack(player: Player): number?
	local data = playerData[player]
	return data and data.FinalAttack or nil
end

function PlayerDataService.GetGold(player: Player): number?
	local data = playerData[player]
	return data and data.Gold or nil
end

function PlayerDataService.GetSnapshot(player: Player)
	local data = playerData[player]
	if not data then
		return nil
	end
	return {
		Level = data.Level,
		Exp = data.Exp,
		Gold = data.Gold,
		BaseAttack = data.BaseAttack,
		FinalAttack = data.FinalAttack,
		BaseDefense = data.BaseDefense,
		FinalDefense = data.FinalDefense,
	}
end

function PlayerDataService.SetEquipmentBonuses(player: Player, attack: number, defense: number): boolean
	local data = playerData[player]
	if not data then
		return false
	end
	data.EquipmentAttackBonus = attack
	data.EquipmentDefenseBonus = defense
	data.FinalAttack, data.FinalDefense = StatService.Calculate(data)
	updateLeaderstats(player, data)
	return true
end

function PlayerDataService.AddExp(player: Player, amount: number)
	local data = playerData[player]
	if not data or amount <= 0 then
		return
	end

	local oldLevel = data.Level
	LevelService.ApplyExp(data, amount)
	data.FinalAttack, data.FinalDefense = StatService.Calculate(data)
	updateLeaderstats(player, data)
	print(string.format("[IdleRaid] %s gained %d EXP", player.Name, amount))
	for level = oldLevel + 1, data.Level do
		print(string.format("[IdleRaid] %s reached Level %d", player.Name, level))
	end
end

function PlayerDataService.AddGold(player: Player, amount: number): boolean
	local data = playerData[player]
	if not data or typeof(amount) ~= "number" or amount < 1 or amount % 1 ~= 0 then
		return false
	end

	data.Gold += amount
	updateLeaderstats(player, data)
	print(string.format("[IdleRaid] %s gained %d Gold", player.Name, amount))
	return true
end

return PlayerDataService
