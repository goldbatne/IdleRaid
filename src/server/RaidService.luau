local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GrowthConfig = require(ReplicatedStorage.Shared.GrowthConfig)
local GrowthMath = require(ReplicatedStorage.Shared.GrowthMath)
local EnemyService = require(script.Parent.EnemyService)
local EquipmentService = require(script.Parent.EquipmentService)
local PlayerDataService = require(script.Parent.PlayerDataService)
local GrowthService = require(script.Parent.GrowthService)
local StateSyncService = require(script.Parent.StateSyncService)

local RaidService = {}
local current
local arena: Folder?
local bossSpawn: BasePart?
local joinRemote: RemoteEvent?
local telegraphRemote: RemoteEvent?
local feedbackRemote: RemoteEvent?
local nextId = 0
local lastMetrics
local finishRaid

local function gateDefinition(gateId: string)
	for _, gate in ipairs(GrowthConfig.Gates) do
		if gate.Id == gateId then return gate end
	end
	return nil
end

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
	if not floor:IsA("BasePart") then
		warn("[IdleRaid] Workspace.RaidArena.Floor must be a BasePart")
		arena = nil
		return
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
	if not spawn:IsA("BasePart") then
		warn("[IdleRaid] Workspace.RaidArena.BossSpawn must be a BasePart")
		arena = nil
		return
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
		BossName = GameConfig.Enemies.SlimeKing.Name .. " · " .. (gateDefinition(session.GateId).Difficulty),
		GateId = session.GateId,
		Defeated = (PlayerDataService.GetHealth(player) or 0) <= 0,
		DashReadyAt = session.Dash[player] and session.Dash[player].ReadyAt or 0,
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

function RaidService.IsInvulnerable(player: Player): boolean
	local session = current
	local dash = session and session.Dash[player]
	return session ~= nil and session.Status == "Active" and dash ~= nil
		and Workspace:GetServerTimeNow() < dash.InvulnerableUntil
end

function RaidService.TryDash(player: Player, direction): boolean
	local session = current
	if not session or session.Status ~= "Active" or not session.Participants[player]
		or (PlayerDataService.GetHealth(player) or 0) <= 0 then
		return false
	end
	if typeof(direction) ~= "Vector3" or direction.X ~= direction.X or direction.Z ~= direction.Z
		or math.abs(direction.X) > 1000000 or math.abs(direction.Z) > 1000000 then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then return false end
	local now = Workspace:GetServerTimeNow()
	local previous = session.Dash[player]
	if previous and now < previous.ReadyAt then return false end
	local horizontal = Vector3.new(direction.X, 0, direction.Z)
	if horizontal.Magnitude < 0.01 then return false end
	local center = GameConfig.Raid.ArenaCenter
	local half = GameConfig.Raid.ArenaSize / 2
	local inset = GameConfig.Raid.ArenaInset
	if math.abs(root.Position.X - center.X) > half.X - inset
		or math.abs(root.Position.Z - center.Z) > half.Z - inset then
		return false
	end
	local desired = root.Position + horizontal.Unit * GameConfig.Raid.Dash.Distance
	local destination = Vector3.new(
		math.clamp(desired.X, center.X - half.X + inset, center.X + half.X - inset),
		root.Position.Y,
		math.clamp(desired.Z, center.Z - half.Z + inset, center.Z + half.Z - inset)
	)
	local displacement = destination - root.Position
	if displacement.Magnitude < 0.1 then return false end
	session.Dash[player] = {
		ReadyAt = now + GameConfig.Raid.Dash.Cooldown,
		InvulnerableUntil = now + GameConfig.Raid.Dash.InvulnerableTime,
	}
	character:PivotTo(character:GetPivot() + displacement)
	root.AssemblyLinearVelocity = Vector3.zero
	StateSyncService.Push(player)
	return true
end

function RaidService.GetLastMetrics()
	return lastMetrics
end

local function applyDamage(session, player: Player, amount: number)
	if current ~= session or session.Status ~= "Active" or not session.Participants[player] then return end
	local health = PlayerDataService.GetHealth(player)
	if not health or health <= 0 or RaidService.IsInvulnerable(player) then return end
	local remaining = PlayerDataService.ApplyRaidDamage(player, amount)
	if not remaining then return end
	session.Metrics.Hits += 1
	session.Metrics.HitsByPlayer[player] = (session.Metrics.HitsByPlayer[player] or 0) + 1
	if feedbackRemote then feedbackRemote:FireClient(player, "Taken", health - remaining) end
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
	session.Metrics.Slam += 1
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
			applyDamage(session, player, math.round(config.Damage * session.Difficulty.DamageMultiplier))
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
	session.Metrics.Charge += 1
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
			applyDamage(session, player, math.round(config.Damage * session.Difficulty.DamageMultiplier))
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
	if session.Boss then EnemyService.RemoveEnemy(session.Boss) end
	local metrics = session.Metrics
	metrics.Result = if success then "Clear" else "Failed"
	metrics.Duration = math.round((os.clock() - metrics.StartedAt) * 10) / 10
	metrics.Participants = {}
	for player in pairs(session.Participants) do
		local initial = metrics.Initial[player]
		if initial then
			table.insert(metrics.Participants, {
			Name = player.Name,
			Level = initial.Level,
			Equipment = initial.Equipment,
			FinalAttack = initial.FinalAttack,
			Hits = metrics.HitsByPlayer[player] or 0,
			DamageDealt = metrics.DamageByPlayer[player] or 0,
			Defeated = (PlayerDataService.GetHealth(player) or 0) <= 0,
			})
		end
	end
	lastMetrics = {
		Result = metrics.Result, Duration = metrics.Duration,
		Slam = metrics.Slam, Charge = metrics.Charge, Hits = metrics.Hits,
		BossHealthRemaining = if success then 0 else session.BossHealth,
		GateId = session.GateId,
		Participants = metrics.Participants,
	}
	print(string.format("[IdleRaid] RaidMetrics %s %.1fs Slam=%d Charge=%d Hits=%d",
		metrics.Result, metrics.Duration, metrics.Slam, metrics.Charge, metrics.Hits))
	if success then
		session.BossHealth = 0
		local gate = gateDefinition(session.GateId)
		for player in pairs(session.Participants) do
			if player.Parent == Players then
				local profile = PlayerDataService.GetProfile(player)
				if profile then
					local rewardStage = math.min(profile.BreakthroughStage, gate.Stage)
					local rewardPower = GrowthMath.ReferenceRate(rewardStage) * GameConfig.Raid.RewardTrainingSeconds
					PlayerDataService.AddPowerFinal(player, rewardPower, "RaidClear")
					PlayerDataService.AddGold(player, session.Difficulty.Gold)
					PlayerDataService.AddRaidToken(player, session.Difficulty.Tokens)
					if session.GateEligible[player] and (metrics.DamageByPlayer[player] or 0) > 0 then
						GrowthService.RecordGateClear(player, session.GateId)
					end
				end
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

function RaidService.OnBossDamaged(player: Player, target: Instance, dealt: number, killed: boolean)
	local session = current
	if not session or session.Status ~= "Active" or target ~= session.Boss then return end
	session.Metrics.DamageByPlayer[player] = (session.Metrics.DamageByPlayer[player] or 0) + dealt
	if feedbackRemote then feedbackRemote:FireClient(player, "BossDamage", dealt) end
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
	session.BossMaxHealth = GameConfig.Raid.BossHealthByPlayers[count] * session.Difficulty.HpMultiplier
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
	session.Metrics.StartedAt = os.clock()
	for player in pairs(session.Participants) do
		local snapshot = PlayerDataService.GetSnapshot(player)
		session.Metrics.Initial[player] = {
			Level = snapshot and snapshot.Level or 0,
			FinalAttack = snapshot and snapshot.FinalAttack or 0,
			Equipment = EquipmentService.GetSnapshot(player),
		}
	end
	pushParticipants(session)
	print(string.format("[IdleRaid] Raid started with %d player(s), boss HP %d", count, session.BossMaxHealth))
	task.spawn(bossLoop, session)
end

local function joinRaid(player: Player, requestedGate: any)
	local gateId = if requestedGate == nil then "Gate10" else requestedGate
	if typeof(gateId) ~= "string" or not gateDefinition(gateId) then return end
	if gateId ~= "Gate10" and not GrowthService.CanClearGate(player, gateId) then return end
	if not arena or not bossSpawn or not PlayerDataService.GetHealth(player) then return end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then return end
	if current and (current.Status ~= "Gathering" or current.GateId ~= gateId) then return end
	if not current then
		nextId += 1
		current = {
			Id = nextId, Status = "Gathering", Phase = "Gathering",
			Participants = {}, GateEligible = {}, GateId = gateId,
			Difficulty = GameConfig.Raid.DifficultyByGate[gateId],
			Boss = nil, BossHealth = 0, BossMaxHealth = 0,
			Dash = {},
			Metrics = {
				Slam = 0, Charge = 0, Hits = 0,
				HitsByPlayer = {}, DamageByPlayer = {}, Initial = {},
			},
		}
		local session = current
		task.delay(GameConfig.Raid.JoinWindow, function() beginRaid(session) end)
	end
	if current.Participants[player] then return end
	local count = 0
	for _ in pairs(current.Participants) do count += 1 end
	if count >= GameConfig.Raid.MaxPlayers then return end
	current.Participants[player] = true
	current.GateEligible[player] = GrowthService.CanClearGate(player, gateId)
	PlayerDataService.ResetRaidHealth(player)
	teleport(player, playerStart(count + 1))
	pushParticipants(current)
	print(string.format("[IdleRaid] %s joined raid", player.Name))
	if count + 1 >= GameConfig.Raid.MaxPlayers then beginRaid(current) end
end

function RaidService.Join(player: Player, gateId: string?)
	joinRaid(player, gateId)
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
	feedbackRemote = Instance.new("RemoteEvent")
	feedbackRemote.Name = "RaidCombatFeedback"
	feedbackRemote.Parent = folder
	local dashRemote = Instance.new("RemoteEvent")
	dashRemote.Name = "RaidDash"
	dashRemote.Parent = folder
	dashRemote.OnServerEvent:Connect(function(player, direction)
		RaidService.TryDash(player, direction)
	end)

	local boundaryElapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		boundaryElapsed += dt
		if boundaryElapsed < GameConfig.Raid.BoundaryCheckInterval then return end
		boundaryElapsed = 0
		local session = current
		if not session then return end
		local center = GameConfig.Raid.ArenaCenter
		local half = GameConfig.Raid.ArenaSize / 2
		local inset = GameConfig.Raid.ArenaInset
		for player in pairs(session.Participants) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local position = root.Position
				local x = math.clamp(position.X, center.X - half.X + inset, center.X + half.X - inset)
				local z = math.clamp(position.Z, center.Z - half.Z + inset, center.Z + half.Z - inset)
				if x ~= position.X or z ~= position.Z or position.Y < center.Y - 10 or position.Y > center.Y + 25 then
					character:PivotTo(CFrame.new(x, center.Y + 4, z))
					root.AssemblyLinearVelocity = Vector3.zero
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local session = current
		if not session or not session.Participants[player] then return end
		session.Participants[player] = nil
		session.Dash[player] = nil
		if next(session.Participants) == nil then
			if session.Boss then EnemyService.RemoveEnemy(session.Boss) end
			current = nil
			print("[IdleRaid] Empty raid cleaned up")
		elseif session.Status == "Active" and #alivePlayers(session) == 0 then
			finishRaid(session, false)
		else
			pushParticipants(session)
		end
	end)
	local function watchCharacter(player)
		player.CharacterRemoving:Connect(function()
			local session = current
			if not session or not session.Participants[player] then return end
			if session.Status == "Gathering" then
				session.Participants[player] = nil
				session.Dash[player] = nil
				if next(session.Participants) == nil then current = nil end
				StateSyncService.Push(player)
			elseif session.Status == "Active" then
				local health = PlayerDataService.GetHealth(player)
				if health and health > 0 then PlayerDataService.ApplyRaidDamage(player, health) end
				if #alivePlayers(session) == 0 then finishRaid(session, false) end
			end
		end)
		player.CharacterAdded:Connect(function(character)
			task.spawn(function()
				local root = character:WaitForChild("HumanoidRootPart", 5)
				local session = current
				if root and session and session.Participants[player] then
					teleport(player, playerStart(1))
					StateSyncService.Push(player)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(watchCharacter)
	for _, player in ipairs(Players:GetPlayers()) do watchCharacter(player) end
end

return RaidService
