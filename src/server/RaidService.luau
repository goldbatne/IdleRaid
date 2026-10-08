local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local EnemyService = require(script.Parent.EnemyService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local StateSyncService = require(script.Parent.StateSyncService)

local RaidService = {}
local current
local arena: Folder?
local bossSpawn: BasePart?
local joinRemote: RemoteEvent?
local telegraphRemote: RemoteEvent?
local nextId = 0
local finishRaid

local function alivePlayers(session)
	local result = {}
	for player in pairs(session.Participants) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if player.Parent == Players and (PlayerDataService.GetHealth(player) or 0) > 0
			and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			table.insert(result, player)
		end
	end
	return result
end

local function pushParticipants(session)
	for player in pairs(session.Participants) do
		StateSyncService.Push(player)
	end
end

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position))
	end
end

local function makeArena()
	local existing = Workspace:FindFirstChild("RaidArena")
	if existing and not existing:IsA("Folder") then
		warn("[IdleRaid] Workspace.RaidArena must be a Folder")
		return
	end
	arena = existing or Instance.new("Folder")
	arena.Name = "RaidArena"
	arena.Parent = Workspace

	local floor = arena:FindFirstChild("Floor")
	if not floor then
		floor = Instance.new("Part")
		floor.Name = "Floor"
		floor.Anchored = true
		floor.Size = GameConfig.Raid.ArenaSize
		floor.Position = GameConfig.Raid.ArenaCenter - Vector3.new(0, floor.Size.Y / 2, 0)
		floor.Color = Color3.fromRGB(53, 65, 77)
		floor.Parent = arena
	end
	local spawn = arena:FindFirstChild("BossSpawn")
	if not spawn then
		spawn = Instance.new("Part")
		spawn.Name = "BossSpawn"
		spawn.Anchored = true
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.Transparency = 1
		spawn.Size = Vector3.new(2, 0.2, 2)
		spawn.Position = GameConfig.Raid.ArenaCenter + Vector3.new(0, 0.2, 18)
		spawn.Parent = arena
	end
	bossSpawn = spawn
end

local function playerStart(index: number): Vector3
	return GameConfig.Raid.ArenaCenter + Vector3.new((index - 2.5) * 5, 4, -20)
end

local function exitPosition(): Vector3
	local spawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if spawn then
		return spawn.Position + Vector3.new(0, 5, 0)
	end
	return Vector3.new(0, 5, 0)
end

function RaidService.GetSnapshot(player: Player)
	local session = current
	if not session or not session.Participants[player] then
		return { IsParticipant = false, Status = "Idle" }
	end
	return {
		IsParticipant = true,
		Status = session.Status,
		Phase = session.Phase,
		BossHealth = session.BossHealth,
		BossMaxHealth = session.BossMaxHealth,
		BossName = GameConfig.Enemies.SlimeKing.Name,
		Defeated = (PlayerDataService.GetHealth(player) or 0) <= 0,
	}
end

function RaidService.CanAttack(player: Player, target: Instance): boolean
	local session = current
	local isBoss = target:GetAttribute("IsBoss") == true
	if isBoss then
		return session ~= nil and session.Status == "Active"
			and session.Participants[player] == true and target == session.Boss
			and (PlayerDataService.GetHealth(player) or 0) > 0
	end
	return not (session and session.Participants[player])
end

local function applyDamage(session, player: Player, amount: number)
	if current ~= session or session.Status ~= "Active" or not session.Participants[player] then return end
	local health = PlayerDataService.GetHealth(player)
	if not health or health <= 0 then return end
	local remaining = PlayerDataService.ApplyRaidDamage(player, amount)
	if remaining == 0 then
		print(string.format("[IdleRaid] %s defeated in raid", player.Name))
		StateSyncService.Push(player)
		if #alivePlayers(session) == 0 then finishRaid(session, false) end
	end
end

local function horizontalDistance(a: Vector3, b: Vector3): number
	return (Vector3.new(a.X, 0, a.Z) - Vector3.new(b.X, 0, b.Z)).Magnitude
end

local function groundSlam(session, targetPlayer: Player)
	local root = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local config = GameConfig.Raid.Slam
	local center = Vector3.new(root.Position.X, GameConfig.Raid.ArenaCenter.Y, root.Position.Z)
	session.Phase = "Telegraph"
	pushParticipants(session)
	for player in pairs(session.Participants) do
		telegraphRemote:FireClient(player, "Slam", center, config.Radius, config.TelegraphTime)
	end
	task.wait(config.TelegraphTime)
	if current ~= session or session.Status ~= "Active" then return end
	session.Phase = "Attack"
	for _, player in ipairs(alivePlayers(session)) do
		local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if playerRoot and horizontalDistance(playerRoot.Position, center) <= config.Radius then
			applyDamage(session, player, config.Damage)
		end
	end
	print("[IdleRaid] Slime King used Ground Slam")
end

local function distanceToSegment(point: Vector3, startPos: Vector3, endPos: Vector3): number
	local a = Vector2.new(startPos.X, startPos.Z)
	local b = Vector2.new(endPos.X, endPos.Z)
	local p = Vector2.new(point.X, point.Z)
	local delta = b - a
	local fraction = math.clamp((p - a):Dot(delta) / math.max(delta:Dot(delta), 0.001), 0, 1)
	return (p - (a + delta * fraction)).Magnitude
end

local function charge(session, targetPlayer: Player)
	local boss = session.Boss
	local body = boss and boss.PrimaryPart
	local root = targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not body or not root then return end
	local config = GameConfig.Raid.Charge
	local startPos = body.Position
	local horizontal = Vector3.new(root.Position.X - startPos.X, 0, root.Position.Z - startPos.Z)
	if horizontal.Magnitude < 1 then return end
	local endPos = startPos + horizontal.Unit * math.min(horizontal.Magnitude, config.MaxDistance)
	session.Phase = "Telegraph"
	pushParticipants(session)
	for player in pairs(session.Participants) do
		telegraphRemote:FireClient(player, "Charge", startPos, endPos, config.Width, config.TelegraphTime)
	end
	task.wait(config.TelegraphTime)
	if current ~= session or session.Status ~= "Active" then return end
	session.Phase = "Attack"
	local tween = TweenService:Create(body, TweenInfo.new(config.TravelTime, Enum.EasingStyle.Linear), { Position = endPos })
	tween:Play()
	task.wait(config.TravelTime)
	if current ~= session or session.Status ~= "Active" then return end
	for _, player in ipairs(alivePlayers(session)) do
		local playerRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if playerRoot and distanceToSegment(playerRoot.Position, startPos, endPos) <= config.Width / 2 then
			applyDamage(session, player, config.Damage)
		end
	end
	print("[IdleRaid] Slime King used Charge")
end

local function bossLoop(session)
	local attackIndex = 0
	while current == session and session.Status == "Active" do
		session.Phase = "Idle"
		pushParticipants(session)
		task.wait(GameConfig.Raid.BossAttackInterval)
		if current ~= session or session.Status ~= "Active" then break end
		local players = alivePlayers(session)
		if #players == 0 then
			finishRaid(session, false)
			break
		end
		attackIndex += 1
		local target = players[math.random(1, #players)]
		if attackIndex % 2 == 1 then
			groundSlam(session, target)
		else
			charge(session, target)
		end
		if current ~= session or session.Status ~= "Active" then break end
		session.Phase = "Recovery"
		pushParticipants(session)
		task.wait(GameConfig.Raid.RecoveryTime)
	end
end

finishRaid = function(session, success: boolean)
	if current ~= session or session.Status ~= "Active" then return end
	session.Status = if success then "Clear" else "Failed"
	session.Phase = "Finished"
	if not success and session.Boss then
		EnemyService.RemoveEnemy(session.Boss)
	end
	if success then
		session.BossHealth = 0
		for player in pairs(session.Participants) do
			if player.Parent == Players then
				PlayerDataService.AddExp(player, GameConfig.Raid.RewardExp)
				PlayerDataService.AddGold(player, GameConfig.Raid.RewardGold)
				PlayerDataService.AddRaidToken(player, GameConfig.Raid.RewardToken)
			end
		end
	end
	print(if success then "[IdleRaid] RAID CLEAR" else "[IdleRaid] RAID FAILED")
	pushParticipants(session)
	task.delay(GameConfig.Raid.ResultDuration, function()
		if current ~= session then return end
		current = nil
		for player in pairs(session.Participants) do
			if player.Parent == Players then
				PlayerDataService.ResetRaidHealth(player)
				teleport(player, exitPosition())
				StateSyncService.Push(player)
			end
		end
	end)
end

function RaidService.OnBossDamaged(target: Instance, killed: boolean)
	local session = current
	if not session or session.Status ~= "Active" or target ~= session.Boss then return end
	if killed then
		finishRaid(session, true)
	else
		local health = EnemyService.GetHealthSnapshot(target)
		if health then session.BossHealth = health.Health end
		pushParticipants(session)
	end
end

local function beginRaid(session)
	if current ~= session or session.Status ~= "Gathering" then return end
	local count = 0
	for player in pairs(session.Participants) do
		if player.Parent == Players then count += 1 else session.Participants[player] = nil end
	end
	if count == 0 then current = nil return end
	session.BossMaxHealth = GameConfig.Raid.BossHealthByPlayers[count]
	session.BossHealth = session.BossMaxHealth
	session.Boss = EnemyService.SpawnAt(bossSpawn, "SlimeKing", {
		MaxHealth = session.BossMaxHealth,
		NoRespawn = true,
	})
	if not session.Boss then
		warn("[IdleRaid] Slime King spawn failed")
		current = nil
		for player in pairs(session.Participants) do
			PlayerDataService.ResetRaidHealth(player)
			teleport(player, exitPosition())
			StateSyncService.Push(player)
		end
		return
	end
	session.Status = "Active"
	session.Phase = "Idle"
	pushParticipants(session)
	print(string.format("[IdleRaid] Raid started with %d player(s), boss HP %d", count, session.BossMaxHealth))
	task.spawn(bossLoop, session)
end

local function joinRaid(player: Player)
	if not arena or not bossSpawn or not PlayerDataService.GetHealth(player) then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return end
	if current and current.Status ~= "Gathering" then return end
	if not current then
		nextId += 1
		current = {
			Id = nextId, Status = "Gathering", Phase = "Gathering",
			Participants = {}, Boss = nil, BossHealth = 0, BossMaxHealth = 0,
		}
		local session = current
		task.delay(GameConfig.Raid.JoinWindow, function() beginRaid(session) end)
	end
	if current.Participants[player] then return end
	local count = 0
	for _ in pairs(current.Participants) do count += 1 end
	if count >= GameConfig.Raid.MaxPlayers then return end
	current.Participants[player] = true
	PlayerDataService.ResetRaidHealth(player)
	teleport(player, playerStart(count + 1))
	pushParticipants(current)
	print(string.format("[IdleRaid] %s joined raid", player.Name))
	if count + 1 >= GameConfig.Raid.MaxPlayers then beginRaid(current) end
end

function RaidService.Start()
	makeArena()
	local folder = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
	joinRemote = Instance.new("RemoteEvent")
	joinRemote.Name = "JoinRaid"
	joinRemote.Parent = folder
	joinRemote.OnServerEvent:Connect(joinRaid)
	telegraphRemote = Instance.new("RemoteEvent")
	telegraphRemote.Name = "RaidTelegraph"
	telegraphRemote.Parent = folder
	Players.PlayerRemoving:Connect(function(player)
		local session = current
		if not session or not session.Participants[player] then return end
		session.Participants[player] = nil
		if session.Status == "Active" and #alivePlayers(session) == 0 then
			finishRaid(session, false)
		end
	end)
	local function watchCharacter(player)
		player.CharacterRemoving:Connect(function()
			local session = current
			if not session or not session.Participants[player] or session.Status ~= "Active" then return end
			local health = PlayerDataService.GetHealth(player)
			if health and health > 0 then PlayerDataService.ApplyRaidDamage(player, health) end
			if #alivePlayers(session) == 0 then finishRaid(session, false) end
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in ipairs(Players:GetPlayers()) do watchCharacter(player) end
end

return RaidService
