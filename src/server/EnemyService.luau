local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local EnemyService = {}

local enemies = {}
local activeBySpawn = {}
local respawnPending = {}
local started = false
local enemyFolder: Folder?

local function getSpawnLayout(): (Vector3, Vector3)
	local playerSpawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if playerSpawn then
		local center = playerSpawn.Position
			+ playerSpawn.CFrame.LookVector * GameConfig.EnemySpawns.DistanceFromPlayerSpawn
		return center, playerSpawn.CFrame.RightVector
	end

	return Vector3.new(0, 0, -GameConfig.EnemySpawns.DistanceFromPlayerSpawn), Vector3.new(1, 0, 0)
end

local function getSpawnPoints(folder: Folder): { BasePart }
	local points = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(points, child)
		end
	end

	if #points > 0 then
		return points
	end

	local center, right = getSpawnLayout()
	local count = GameConfig.EnemySpawns.DefaultCount
	for index = 1, count do
		local point = Instance.new("Part")
		point.Name = string.format("SpawnPoint%d", index)
		point.Size = Vector3.new(2, 0.2, 2)
		point.Color = Color3.fromRGB(85, 170, 105)
		point.Transparency = 0.7
		point.Anchored = true
		point.CanCollide = false
		point.CanTouch = false
		point.CanQuery = false
		point.Position = center
			+ right * ((index - (count + 1) / 2) * GameConfig.EnemySpawns.Spacing)
			+ Vector3.new(0, 0.2, 0)
		point:SetAttribute("EnemyId", GameConfig.EnemySpawns.DefaultEnemyId)
		point.Parent = folder
		table.insert(points, point)
	end

	return points
end

local function makeEnemyModel(definition, spawnPoint: BasePart): Model
	local model = Instance.new("Model")
	model.Name = definition.Id

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = definition.Size or Vector3.new(3, 3, 3)
	body.Color = definition.Color or Color3.fromRGB(85, 205, 105)
	body.Anchored = true
	body.CanCollide = true
	body.Position = spawnPoint.Position + Vector3.new(0, spawnPoint.Size.Y / 2 + body.Size.Y / 2, 0)
	body.Parent = model
	model.PrimaryPart = body

	return model
end

function EnemyService.RegisterEnemy(model: Model, spawnPoint: BasePart, enemyId: string, options): boolean
	local definition = GameConfig.Enemies[enemyId]
	if not enemyFolder or not definition or not model.PrimaryPart or enemies[model] or activeBySpawn[spawnPoint] then
		return false
	end

	enemies[model] = {
		Id = enemyId,
		Health = (options and options.MaxHealth) or definition.MaxHealth,
		MaxHealth = (options and options.MaxHealth) or definition.MaxHealth,
		NoRespawn = options and options.NoRespawn or false,
		Definition = definition,
		SpawnPoint = spawnPoint,
		Alive = true,
	}
	activeBySpawn[spawnPoint] = model
	model:SetAttribute("EnemyId", enemyId)
	model:SetAttribute("Health", enemies[model].Health)
	model:SetAttribute("MaxHealth", enemies[model].MaxHealth)
	model:SetAttribute("IsBoss", definition.IsBoss == true)
	model:SetAttribute("Attack", definition.Attack)
	model:SetAttribute("Level", definition.Level)
	model.Parent = enemyFolder
	print(string.format("[IdleRaid] %s spawned at %s", enemyId, spawnPoint.Name))
	return true
end

function EnemyService.SpawnAt(spawnPoint: BasePart, enemyId: string, options): Model?
	local definition = GameConfig.Enemies[enemyId]
	if not definition or activeBySpawn[spawnPoint] then return nil end
	local model = makeEnemyModel(definition, spawnPoint)
	if not EnemyService.RegisterEnemy(model, spawnPoint, enemyId, options) then
		model:Destroy()
		return nil
	end
	return model
end

local function spawnAt(spawnPoint: BasePart)
	if activeBySpawn[spawnPoint] or not spawnPoint:IsDescendantOf(Workspace) then
		return
	end

	local enemyId = spawnPoint:GetAttribute("EnemyId")
	if typeof(enemyId) ~= "string" or enemyId == "" then
		enemyId = GameConfig.EnemySpawns.DefaultEnemyId
	end

	local definition = GameConfig.Enemies[enemyId]
	if not definition then
		warn(string.format("[IdleRaid] Unknown EnemyId %s on %s", enemyId, spawnPoint.Name))
		return
	end

	EnemyService.SpawnAt(spawnPoint, enemyId)
end

function EnemyService.Start()
	if started then
		return
	end

	local folder = Workspace:FindFirstChild("EnemySpawns")
	if folder and not folder:IsA("Folder") then
		warn("[IdleRaid] Workspace.EnemySpawns must be a Folder")
		return
	end
	local existingEnemies = Workspace:FindFirstChild("Enemies")
	if existingEnemies and not existingEnemies:IsA("Folder") then
		warn("[IdleRaid] Workspace.Enemies must be a Folder")
		return
	end

	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "EnemySpawns"
		folder.Parent = Workspace
	end
	if not existingEnemies then
		existingEnemies = Instance.new("Folder")
		existingEnemies.Name = "Enemies"
		existingEnemies.Parent = Workspace
	end
	enemyFolder = existingEnemies
	started = true

	for _, spawnPoint in ipairs(getSpawnPoints(folder)) do
		spawnAt(spawnPoint)
	end
end

function EnemyService.IsAliveEnemy(target: Instance): boolean
	if not target:IsA("Model") then
		return false
	end

	local state = enemies[target]
	return state ~= nil and state.Alive and state.Health > 0 and target.Parent == enemyFolder
end

function EnemyService.GetAttackPosition(target: Instance): Vector3?
	if not EnemyService.IsAliveEnemy(target) then
		return nil
	end

	local body = (target :: Model).PrimaryPart
	return body and body.Position or nil
end

function EnemyService.GetHealthSnapshot(target: Instance)
	if not EnemyService.IsAliveEnemy(target) then return nil end
	local state = enemies[target]
	return { Health = state.Health, MaxHealth = state.MaxHealth, Id = state.Id }
end

function EnemyService.RemoveEnemy(target: Instance)
	local state = enemies[target]
	if not state then return end
	enemies[target] = nil
	activeBySpawn[state.SpawnPoint] = nil
	target:Destroy()
end

function EnemyService.GetKillExp(target: Instance): number?
	if not EnemyService.IsAliveEnemy(target) then
		return nil
	end

	return enemies[target].Definition.KillExp
end

function EnemyService.ApplyDamage(target: Instance, damage: number): (number, boolean, string?)
	if not EnemyService.IsAliveEnemy(target) or damage <= 0 then
		return 0, false, nil
	end

	local state = enemies[target]
	local dealt = math.min(damage, state.Health)
	state.Health -= dealt
	target:SetAttribute("Health", state.Health)

	if state.Health > 0 then
		return dealt, false, state.Id
	end

	state.Alive = false
	enemies[target] = nil
	activeBySpawn[state.SpawnPoint] = nil
	target:Destroy()

	local spawnPoint = state.SpawnPoint
	if not state.NoRespawn and not respawnPending[spawnPoint] then
		respawnPending[spawnPoint] = true
		task.delay(state.Definition.RespawnTime, function()
			respawnPending[spawnPoint] = nil
			spawnAt(spawnPoint)
		end)
	end

	return dealt, true, state.Id
end

return EnemyService
