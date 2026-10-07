local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local EnemyService = {}

local currentDummy: Model? = nil
local currentHealth = 0
local spawnPosition: Vector3? = nil
local dummyTemplate: Model? = nil

local function getSpawnPosition(): Vector3
	local playerSpawn = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if playerSpawn then
		return playerSpawn.Position
			+ playerSpawn.CFrame.LookVector * GameConfig.TrainingDummy.SpawnDistanceFromPlayerSpawn
			+ Vector3.new(0, 3, 0)
	end

	return Vector3.new(0, 3, -GameConfig.TrainingDummy.SpawnDistanceFromPlayerSpawn)
end

local function makeDummyTemplate(): Model
	local model = Instance.new("Model")
	model.Name = "TrainingDummy"

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(4, 6, 2)
	body.Color = Color3.fromRGB(220, 65, 65)
	body.Anchored = true
	body.CanCollide = true
	body.Position = spawnPosition :: Vector3
	body.Parent = model
	model.PrimaryPart = body
	return model
end

local function activateDummy(model: Model)
	currentHealth = GameConfig.TrainingDummy.MaxHealth
	model:SetAttribute("MaxHealth", GameConfig.TrainingDummy.MaxHealth)
	model:SetAttribute("Health", currentHealth)
	model.Parent = Workspace
	currentDummy = model
	print("[IdleRaid] TrainingDummy spawned")
end

local function spawnDummy()
	activateDummy((dummyTemplate :: Model):Clone())
end

function EnemyService.Start()
	local existing = Workspace:FindFirstChild("TrainingDummy")
	if existing and existing:IsA("BasePart") then
		local model = Instance.new("Model")
		model.Name = "TrainingDummy"
		existing.Name = "Body"
		existing.Parent = model
		model.PrimaryPart = existing
		model.Parent = Workspace
		existing = model
	end

	if existing then
		if not existing:IsA("Model") then
			warn("[IdleRaid] TrainingDummy must be a Model or BasePart")
			return
		end

		local body = existing.PrimaryPart or existing:FindFirstChildWhichIsA("BasePart", true)
		if not body then
			warn("[IdleRaid] TrainingDummy has no BasePart")
			return
		end

		existing.PrimaryPart = body
		spawnPosition = body.Position
		dummyTemplate = existing:Clone()
		activateDummy(existing)
		return
	end

	spawnPosition = getSpawnPosition()
	dummyTemplate = makeDummyTemplate()
	spawnDummy()
end

function EnemyService.GetAttackPosition(target: Instance): Vector3?
	if target ~= currentDummy or not currentDummy or not currentDummy.Parent then
		return nil
	end

	local body = currentDummy.PrimaryPart
	return body and body.Position or nil
end

function EnemyService.ApplyDamage(target: Instance, damage: number): (number, boolean)
	if target ~= currentDummy or not currentDummy or not currentDummy.Parent or currentHealth <= 0 then
		return 0, false
	end

	local dealt = math.min(damage, currentHealth)
	currentHealth -= dealt
	currentDummy:SetAttribute("Health", currentHealth)

	if currentHealth > 0 then
		return dealt, false
	end

	local defeatedDummy = currentDummy
	currentDummy = nil
	defeatedDummy:Destroy()
	task.delay(GameConfig.TrainingDummy.RespawnTime, spawnDummy)
	return dealt, true
end

return EnemyService
