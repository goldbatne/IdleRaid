local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)
local GrowthConfig = require(ReplicatedStorage.Shared.GrowthConfig)
local NumberFormatter = require(ReplicatedStorage.Shared.NumberFormatter)
local UiStyle = require(script.Parent.UiStyle)
local UiText = require(script.Parent.UiText)

local RaidMenuController = {}
local gateNames = { Gate10 = "관문 10 · 일반", Gate20 = "관문 20 · 어려움", Gate30 = "관문 30 · 악몽" }

function RaidMenuController.Start(panel: Frame, stateController)
	local remotes = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
	local join = remotes:WaitForChild("JoinRaid")
	local growth = remotes:WaitForChild("GrowthAction")
	local state

	local title = UiStyle.Text(panel, "RaidTitle", "관문 레이드", UDim2.new(1, -20, 0, 32), UDim2.fromOffset(10, 10))
	title.TextSize = 21
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = UiStyle.Colors.Gold
	local token = UiStyle.Text(panel, "RaidTokens", "Raid Token 0", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 47))
	local hint = UiStyle.Text(panel, "RaidHint", "팀 승리와 유효한 공격이 있어야 관문 기록이 남습니다.",
		UDim2.new(1, -20, 0, 48), UDim2.fromOffset(10, 72))
	hint.TextSize = 12
	hint.TextColor3 = UiStyle.Colors.Muted
	local feedback = UiStyle.Text(panel, "RaidFeedback", "", UDim2.new(1, -20, 0, 25), UDim2.fromOffset(10, 121))
	feedback.TextSize = 12
	feedback.TextColor3 = UiStyle.Colors.Accent

	local gateButtons = {}
	for index, gate in ipairs(GrowthConfig.Gates) do
		local y = 155 + (index - 1) * 59
		local button = UiStyle.Button(panel, gate.Id, gateNames[gate.Id], UDim2.new(1, -20, 0, 52), UDim2.fromOffset(10, y))
		button.TextSize = 13
		gateButtons[gate.Id] = button
		button.Activated:Connect(function()
			if not state or not state.Ready then return end
			if state.Raid and state.Raid.IsParticipant then return end
			if gate.Id ~= "Gate10" and (state.BreakthroughStage or 1) < gate.Stage then
				feedback.Text = "이 관문 단계에 먼저 도달해야 합니다"
				return
			end
			join:FireServer(gate.Id)
			feedback.Text = gateNames[gate.Id] .. " 입장 요청"
		end)
	end
	local shopTitle = UiStyle.Text(panel, "TokenShop", "Raid Token 교환", UDim2.new(1, -20, 0, 25), UDim2.fromOffset(10, 342))
	shopTitle.Font = Enum.Font.GothamBold
	shopTitle.TextColor3 = UiStyle.Colors.Gold
	local shopButtons = {}
	for index, steps in ipairs(GrowthConfig.TicketSteps) do
		local button = UiStyle.Button(panel, "Exchange" .. steps, "",
			UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 374 + (index - 1) * 49))
		button.TextSize = 13
		shopButtons[steps] = button
		button.Activated:Connect(function()
			if not state or not state.Ready then return end
			local ok, result = pcall(function()
				return growth:InvokeServer("ExchangeTicket", {
					Steps = steps,
					ExpectedTokens = state.RaidToken,
					ExpectedCount = (state.BreakthroughTickets or {})[tostring(steps)] or 0,
					RequestId = game:GetService("HttpService"):GenerateGUID(false),
				})
			end)
			feedback.Text = if ok and typeof(result) == "table"
				then (if result.Ok then string.format("+%d단계권 1장 획득", steps) else UiText.Reason(result.Reason))
				else "서버 응답을 확인하지 못했습니다"
		end)
	end
	local shopNote = UiStyle.Text(panel, "ShopNote",
		"돌파권 추가 구매: 준비 중 · 상품 ID와 가격 미설정",
		UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 528))
	shopNote.TextSize = 12
	shopNote.TextColor3 = UiStyle.Colors.Muted

	stateController.Subscribe(function(snapshot)
		state = snapshot
		token.Text = "Raid Token  " .. NumberFormatter.Format(snapshot.RaidToken or 0)
		for _, gate in ipairs(GrowthConfig.Gates) do
			local difficulty = GameConfig.Raid.DifficultyByGate[gate.Id]
			local cleared = (snapshot.ClearedRaidGates or {})[gate.Id] == true
			local ready = (snapshot.BreakthroughStage or 1) >= gate.Stage
			gateButtons[gate.Id].Text = string.format("%s · %s\n보상 Gold %s · Token %d",
				gateNames[gate.Id], if cleared then "클리어" elseif ready then "도전 가능" else "연습 가능",
				NumberFormatter.Format(difficulty.Gold), difficulty.Tokens)
		end
		for steps, button in pairs(shopButtons) do
			button.Text = string.format("+%d단계권 · Token %d · 보유 %d장",
				steps, GrowthConfig.TokenTicketCost[steps],
				(snapshot.BreakthroughTickets or {})[tostring(steps)] or 0)
		end
	end)
end

return RaidMenuController
