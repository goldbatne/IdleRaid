local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GrowthConfig = require(ReplicatedStorage.Shared.GrowthConfig)
local GrowthMath = require(ReplicatedStorage.Shared.GrowthMath)
local ItemConfig = require(ReplicatedStorage.Shared.ItemConfig)
local AutoCombatController = require(script.Parent.Parent.AutoCombatController)
local UiStyle = require(script.Parent.UiStyle)

local GoalController = {}

function GoalController.Start(gui: ScreenGui, stateController, openPage, selectItem)
	local remotes = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
	local trainingRemote = remotes:WaitForChild("SetTrainingEnabled")
	local button = UiStyle.Button(gui, "NextGoal", "다음 목표 확인 중",
		UDim2.new(0.58, 0, 0, 52), UDim2.fromOffset(12, 198))
	button.TextSize = 13
	button.BackgroundColor3 = UiStyle.Colors.Panel
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(260, 52)
	limit.MinSize = Vector2.new(178, 52)
	limit.Parent = button
	local state
	local action
	local function update()
		if not state or not state.Ready then
			button.Text = "다음 목표 확인 중"
			button.Active = false
			return
		end
		button.Visible = not (state.Raid and state.Raid.IsParticipant)
		button.Active = true
		if not state.TrainingEnabled then
			button.Text = "다음 목표 · 기본 수련 시작"
			action = function() trainingRemote:FireServer(true) end
			return
		end
		local stage = state.BreakthroughStage or 1
		local gate = GrowthMath.NextGate(stage, state.ClearedRaidGates or {})
		if gate and stage >= gate.Stage then
			button.Text = "다음 목표 · " .. tostring(gate.Stage) .. "단계 관문 도전"
			action = function() openPage("Raid") end
			return
		end
		for _, stack in ipairs(state.Inventory or {}) do
			local definition = ItemConfig.Items[stack.ItemId]
			local wornId = definition and (state.Equipment or {})[definition.Type]
			local worn = wornId and ItemConfig.Items[wornId]
			local improves = definition and (not worn
				or (definition.Attack or 0) > (worn.Attack or 0)
				or (definition.Defense or 0) > (worn.Defense or 0))
			if improves then
				button.Text = "다음 목표 · 획득 장비 비교"
				action = function()
					if selectItem(stack.ItemId) then openPage("Bag") end
				end
				return
			end
		end
		local tier = state.TrainingFacilityTier or 1
		local facility = GrowthConfig.Facilities[tier + 1]
		if facility and (state.Gold or 0) >= facility.GoldCost
			and (not facility.RequiredGate or (state.ClearedRaidGates or {})[facility.RequiredGate]) then
			button.Text = "다음 목표 · Gold로 시설 개선"
			action = function() openPage("Growth") end
			return
		end
		if stage < GrowthConfig.MaxStage and GrowthMath.CanAdvance(stage, 1, state.ClearedRaidGates or {})
			and (state.AvailableTrainingPower or 0) >= (state.BreakthroughCost or math.huge) then
			button.Text = "다음 목표 · 무료 +1 돌파"
			action = function() openPage("Growth") end
			return
		end
		if not AutoCombatController.GetEnabled() then
			button.Text = "수련 중 · 눌러서 사냥 시작"
			action = AutoCombatController.Toggle
			return
		end
		button.Text = if stage >= GrowthConfig.MaxStage and not gate then "현재 관문 모두 클리어"
			else "수련·사냥으로 다음 성장 준비"
		action = function() openPage("Growth") end
	end
	button.Activated:Connect(function()
		if button.Active and action then action() end
	end)
	stateController.Subscribe(function(snapshot)
		state = snapshot
		update()
	end)
	AutoCombatController.OnChanged(update)
	return button
end

return GoalController
