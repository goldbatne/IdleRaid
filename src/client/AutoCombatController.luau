local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local StateController = require(script.Parent.StateController)

local AutoCombatController = {}

local player = Players.LocalPlayer
local enabled = false
local raidParticipant = false
local raidActive = false
local raidDefeated = false
local target: Model?
local moving = false
local lastMoveAt = -math.huge
local lastAttackRequestAt = -math.huge
local heldMovementKeys = {}
local heldMovementTouches = {}
local manualUntil = -math.huge
local changed = Instance.new("BindableEvent")

local movementKeys = {
	[Enum.KeyCode.W] = true,
	[Enum.KeyCode.A] = true,
	[Enum.KeyCode.S] = true,
	[Enum.KeyCode.D] = true,
	[Enum.KeyCode.Up] = true,
	[Enum.KeyCode.Down] = true,
	[Enum.KeyCode.Left] = true,
	[Enum.KeyCode.Right] = true,
}

local function getCharacterParts(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return nil, nil
	end
	return humanoid, root
end

local function stopAutoMove()
	if not moving then
		return
	end
	moving = false
	local humanoid, root = getCharacterParts()
	if humanoid and root then
		humanoid:MoveTo(root.Position)
	end
end

local function getEnemyFolder(): Folder?
	local folder = Workspace:FindFirstChild("Enemies")
	return if folder and folder:IsA("Folder") then folder else nil
end

local function getEnemyPosition(enemy: Model, folder: Folder): Vector3?
	if enemy.Parent ~= folder or typeof(enemy:GetAttribute("EnemyId")) ~= "string"
		or (enemy:GetAttribute("IsBoss") == true) ~= raidParticipant then
		return nil
	end
	local state = StateController.GetSnapshot()
	local requiredStage = enemy:GetAttribute("RequiredStage")
	if typeof(requiredStage) == "number" and (not state or (state.BreakthroughStage or 1) < requiredStage) then
		return nil
	end
	local health = enemy:GetAttribute("Health")
	if typeof(health) ~= "number" or health <= 0 then
		return nil
	end
	local body = enemy.PrimaryPart
	return body and body.Position or nil
end

local function findNearestEnemy(root: BasePart, folder: Folder): Model?
	local nearest: Model?
	local nearestDistance = math.huge
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			local position = getEnemyPosition(child, folder)
			if position then
				local distance = (root.Position - position).Magnitude
				if distance < nearestDistance then
					nearest = child
					nearestDistance = distance
				end
			end
		end
	end
	return nearest
end

local function isMovingManually(): boolean
	return next(heldMovementKeys) ~= nil or next(heldMovementTouches) ~= nil or os.clock() < manualUntil
end

local function update(attackRemote: RemoteEvent)
	if not enabled then
		return
	end
	if raidParticipant and (not raidActive or raidDefeated) then
		target = nil
		stopAutoMove()
		return
	end

	local humanoid, root = getCharacterParts()
	if not humanoid or not root then
		target = nil
		moving = false
		return
	end

	local folder = getEnemyFolder()
	if not folder then
		target = nil
		stopAutoMove()
		return
	end

	local position = if target then getEnemyPosition(target, folder) else nil
	if not position then
		target = findNearestEnemy(root, folder)
		position = if target then getEnemyPosition(target, folder) else nil
		lastMoveAt = -math.huge
	end
	if not target or not position then
		stopAutoMove()
		return
	end

	if isMovingManually() then
		stopAutoMove()
		return
	end
	local distance = (root.Position - position).Magnitude
	if distance > GameConfig.Combat.AttackRange then

		local horizontal = Vector3.new(position.X - root.Position.X, 0, position.Z - root.Position.Z)
		if horizontal.Magnitude > 0 then
			local now = os.clock()
			if not moving or now - lastMoveAt >= GameConfig.AutoCombat.MoveRefreshInterval then
				local travel = math.max(0, horizontal.Magnitude - GameConfig.AutoCombat.ApproachDistance)
				humanoid:MoveTo(root.Position + horizontal.Unit * travel)
				moving = true
				lastMoveAt = now
			end
		end
		return
	end

	stopAutoMove()
	local now = os.clock()
	if now - lastAttackRequestAt >= GameConfig.AutoCombat.AttackRequestInterval then
		lastAttackRequestAt = now
		attackRemote:FireServer(target)
	end
end

function AutoCombatController.PauseForDash()
	manualUntil = math.max(manualUntil, os.clock() + GameConfig.Raid.Dash.ManualPauseTime)
	stopAutoMove()
end

function AutoCombatController.GetEnabled(): boolean
	return enabled
end

function AutoCombatController.OnChanged(callback)
	local connection = changed.Event:Connect(callback)
	callback(enabled)
	return connection
end

function AutoCombatController.SetEnabled(nextEnabled: boolean)
	if enabled == nextEnabled then
		return
	end
	enabled = nextEnabled
	target = nil
	if not enabled then
		stopAutoMove()
	end
	print(if enabled then "[IdleRaid] AutoCombat ON" else "[IdleRaid] AutoCombat OFF")
	changed:Fire(enabled)
end

function AutoCombatController.Toggle()
	AutoCombatController.SetEnabled(not enabled)
end

function AutoCombatController.ShouldResetForRaid(
	wasParticipant: boolean, wasActive: boolean, wasDefeated: boolean,
	nextParticipant: boolean, nextActive: boolean, nextDefeated: boolean
): boolean
	local wasBlocked = wasParticipant and (not wasActive or wasDefeated)
	local blocked = nextParticipant and (not nextActive or nextDefeated)
	return wasParticipant ~= nextParticipant or wasBlocked ~= blocked
end

function AutoCombatController.Start()
	local attackRemote = ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("BasicAttack")
	StateController.Subscribe(function(state)
		local raid = state.Raid or {}
		local nextParticipant = raid.IsParticipant == true
		local nextActive = raid.Status == "Active"
		local nextDefeated = raid.Defeated == true
		local reset = AutoCombatController.ShouldResetForRaid(
			raidParticipant, raidActive, raidDefeated, nextParticipant, nextActive, nextDefeated)
		raidParticipant, raidActive, raidDefeated = nextParticipant, nextActive, nextDefeated
		if reset then
			target = nil
			stopAutoMove()
		end
	end)

	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.Touch then
			local camera = Workspace.CurrentCamera
			local viewport = camera and camera.ViewportSize
			if viewport and input.Position.X < viewport.X * 0.45 and input.Position.Y > viewport.Y * 0.4 then
				heldMovementTouches[input] = true
				stopAutoMove()
			end
			return
		end
		if gameProcessed then
			return
		end
		if input.KeyCode == Enum.KeyCode.T then
			AutoCombatController.Toggle()
		elseif movementKeys[input.KeyCode] then
			heldMovementKeys[input.KeyCode] = true
			stopAutoMove()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch then
			heldMovementTouches[input] = nil
		end
		if movementKeys[input.KeyCode] then
			heldMovementKeys[input.KeyCode] = nil
		end
	end)

	player.CharacterAdded:Connect(function()
		moving = false
		table.clear(heldMovementKeys)
		table.clear(heldMovementTouches)
		manualUntil = -math.huge
		AutoCombatController.SetEnabled(false)
		target = nil
	end)

	task.spawn(function()
		while true do
			update(attackRemote)
			task.wait(GameConfig.AutoCombat.TargetScanInterval)
		end
	end)
end

return AutoCombatController
