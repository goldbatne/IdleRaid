local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local LevelService = require(script.Parent.LevelService)

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

	for _, name in ipairs({ "Level", "Exp", "Gold", "Attack" }) do
		local stat = leaderstats:FindFirstChild(name)
		if stat then
			stat.Value = data[name]
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
		Attack = GameConfig.Player.InitialAttack,
	}
	playerData[player] = data

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in ipairs({ "Level", "Exp", "Gold", "Attack" }) do
		makeStat(leaderstats, name, data[name])
	end
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

function PlayerDataService.GetAttack(player: Player): number?
	local data = playerData[player]
	return data and data.Attack or nil
end

function PlayerDataService.GetGold(player: Player): number?
	local data = playerData[player]
	return data and data.Gold or nil
end

function PlayerDataService.AddExp(player: Player, amount: number)
	local data = playerData[player]
	if not data or amount <= 0 then
		return
	end

	local oldLevel = data.Level
	LevelService.ApplyExp(data, amount)
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
