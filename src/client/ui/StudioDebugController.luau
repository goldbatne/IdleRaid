local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiStyle = require(script.Parent.UiStyle)

local StudioDebugController = {}

function StudioDebugController.Start(panel: ScrollingFrame, stateController)
	if not RunService:IsStudio() then return end
	local remotes = ReplicatedStorage:WaitForChild("IdleRaidRemotes")
	local modeRemote = remotes:WaitForChild("StudioProfileMode")
	local grant = remotes:WaitForChild("StudioGrowthGrant")
	local receipt = remotes:WaitForChild("StudioSyntheticReceipt")
	local itemGrant = remotes:WaitForChild("StudioInventoryGrant")
	local title = UiStyle.Text(panel, "DebugTitle", "Studio 성장 테스트", UDim2.new(1, -20, 0, 32),
		UDim2.fromOffset(10, 8))
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextColor3 = UiStyle.Colors.Gold
	local note = UiStyle.Text(panel, "DebugNote",
		"개발 테스트 · 실제 결제 없음. 일반 프로필과 분리됩니다.",
		UDim2.new(1, -20, 0, 45), UDim2.fromOffset(10, 42))
	note.TextSize = 12
	note.TextColor3 = UiStyle.Colors.Muted
	local feedback = UiStyle.Text(panel, "DebugFeedback", "", UDim2.new(1, -20, 0, 38),
		UDim2.fromOffset(10, 91))
	feedback.TextSize = 13
	feedback.TextColor3 = UiStyle.Colors.Accent

	local modeButton = UiStyle.Button(panel, "SwitchSandbox", "개발 체험 시작",
		UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 136))
	local sandbox = false
	local grantButtons = {}
	modeButton.Activated:Connect(function()
		local ok, result = pcall(function() return modeRemote:InvokeServer(not sandbox) end)
		feedback.Text = if ok and result then "프로필 전환 완료" else "프로필 전환 거부됨"
	end)

	local actions = {
		{ Label = "수련력 +10K", Kind = "Power", Value = 10000 },
		{ Label = "Gold +1K", Kind = "Gold", Value = 1000 },
		{ Label = "+2 돌파권 1장", Kind = "Ticket", Value = 2 },
		{ Label = "+3 돌파권 1장", Kind = "Ticket", Value = 3 },
		{ Label = "+5 돌파권 1장", Kind = "Ticket", Value = 5 },
		{ Label = "10분 수련권 1장", Kind = "Voucher", Value = "Minutes10" },
	}
	for index, action in ipairs(actions) do
		local button = UiStyle.Button(panel, "Grant" .. index, action.Label,
			UDim2.new(1, -20, 0, 42), UDim2.fromOffset(10, 188 + (index - 1) * 47))
		table.insert(grantButtons, button)
		button.Activated:Connect(function()
			local ok, result = pcall(function() return grant:InvokeServer(action.Kind, action.Value) end)
			feedback.Text = if ok and result == true then action.Label .. " 지급됨" else "지급 거부됨"
		end)
	end
	local itemButton = UiStyle.Button(panel, "GrantTrainingSword", "Training Sword 1개",
		UDim2.new(1, -20, 0, 42), UDim2.fromOffset(10, 481))
	table.insert(grantButtons, itemButton)
	itemButton.Activated:Connect(function()
		local ok, result = pcall(function() return itemGrant:InvokeServer("TrainingSword") end)
		feedback.Text = if ok and result == true then "Training Sword 지급됨" else "아이템 지급 거부됨"
	end)
	local receiptButton = UiStyle.Button(panel, "Receipt", "모의 영수증: +2권 1장",
		UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, 528))
	table.insert(grantButtons, receiptButton)
	receiptButton.Activated:Connect(function()
		local purchaseId = "Studio:" .. HttpService:GenerateGUID(false)
		local ok, result = pcall(function() return receipt:InvokeServer(purchaseId, "Ticket2") end)
		feedback.Text = if ok and result == Enum.ProductPurchaseDecision.PurchaseGranted
			then "모의 영수증 저장 및 지급 완료" else "모의 영수증 보류"
	end)
	stateController.Subscribe(function(state)
		sandbox = state.StudioSandbox == true
		modeButton.Text = if sandbox then "일반 프로필로 돌아가기" else "개발 체험 시작 (격리 프로필)"
		for _, button in ipairs(grantButtons) do button.Visible = sandbox end
		note.Text = if sandbox then "개발 테스트 프로필 · 실제 결제 없음"
			else "일반 프로필 · 개발 지급 비활성"
	end)
	panel.CanvasSize = UDim2.fromOffset(0, 600)
end

return StudioDebugController
