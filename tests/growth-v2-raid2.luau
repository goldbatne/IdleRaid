local StudioTestService = game:GetService("StudioTestService")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local spawn = Instance.new("SpawnLocation")
spawn.Name = "GrowthRaidTestSpawn"
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0, 0)
spawn.Parent = workspace

local testScript = Instance.new("Script")
testScript.Name = "GrowthV2RaidTwoPlayerServer"
testScript.Source = [==[
local Players = game:GetService("Players")
local StudioTestService = game:GetService("StudioTestService")
local GameConfig = require(game.ReplicatedStorage.Shared.GameConfig)
local server = game.ServerScriptService:WaitForChild("Server")
local raid = require(server.RaidService)
local growth = require(server.GrowthService)
local training = require(server.TrainingService)
local data = require(server.PlayerDataService)
local enemies = require(server.EnemyService)
local debugState = server:WaitForChild("DebugGetPlayerState", 20)
local function waitFor(predicate, label)
	local deadline = os.clock() + 90
	repeat
		local result = predicate()
		if result then return result end
		task.wait(0.1)
	until os.clock() > deadline
	error("Timeout: " .. label)
end
local function check(name, condition)
	assert(condition, name)
	print("IR_RAID2_PASS", name)
end
local ok, err = pcall(function()
	local players = waitFor(function()
		local list = Players:GetPlayers()
		if #list == 2 then return list end
	end, "two players")
	for _, player in ipairs(players) do
		waitFor(function()
			local state = debugState:Invoke(player)
			local character = player.Character
			return state and state.Ready and character and character:FindFirstChild("HumanoidRootPart")
		end, "player ready")
		check("training_off_" .. player.Name, training.SetEnabled(player, false))
		check("power_" .. player.Name, data.AddPowerFinal(player, 2000000, "RaidTest"))
		for stage = 1, 9 do
			local result = growth.TryBreakthrough(player, 1, stage)
			check("stage_" .. stage .. "_" .. player.Name, result.Ok and result.Stage == stage + 1)
		end
	end
	local before = {}
	for _, player in ipairs(players) do before[player] = debugState:Invoke(player) end
	raid.Join(players[1], "Gate10")
	raid.Join(players[2], "Gate10")
	waitFor(function()
		return raid.GetSnapshot(players[1]).Status == "Active"
			and raid.GetSnapshot(players[2]).Status == "Active"
	end, "raid active")
	local first = raid.GetSnapshot(players[1])
	check("two_player_scaling", first.BossMaxHealth == GameConfig.Raid.BossHealthByPlayers[2])
	local boss = waitFor(function()
		for _, model in ipairs(workspace.Enemies:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("IsBoss") then return model end
		end
	end, "boss")
	check("both_can_attack_boss", raid.CanAttack(players[1], boss) and raid.CanAttack(players[2], boss))
	local dealtA, killedA = enemies.ApplyDamage(boss, first.BossMaxHealth - 1)
	raid.OnBossDamaged(players[1], boss, dealtA, killedA)
	check("first_hit_not_kill", dealtA == first.BossMaxHealth - 1 and not killedA)
	local dealtB, killedB = enemies.ApplyDamage(boss, 1)
	raid.OnBossDamaged(players[2], boss, dealtB, killedB)
	check("second_hit_kills", dealtB == 1 and killedB)
	local again = enemies.ApplyDamage(boss, 1)
	raid.OnBossDamaged(players[2], boss, 1, true)
	check("no_duplicate_damage", again == 0)
	local afterA = debugState:Invoke(players[1])
	local afterB = debugState:Invoke(players[2])
	check("team_gate_clear", afterA.ClearedRaidGates.Gate10 and afterB.ClearedRaidGates.Gate10)
	check("team_reward_once", afterA.RaidToken == before[players[1]].RaidToken + 1
		and afterB.RaidToken == before[players[2]].RaidToken + 1
		and afterA.Gold == before[players[1]].Gold + 100
		and afterB.Gold == before[players[2]].Gold + 100)
	check("raid_metrics", raid.GetLastMetrics() and raid.GetLastMetrics().Result == "Clear")
end)
print("IR_RAID2_RESULT", ok, err)
StudioTestService:EndTest(if ok then "PASS" else "FAIL")
]==]
testScript.Parent = ServerScriptService

local ok, result = pcall(function()
	return StudioTestService:ExecuteMultiplayerTestAsync(2, "GrowthV2RaidTwoPlayer")
end)
print("IR_RAID2_LAUNCH", ok, result)
