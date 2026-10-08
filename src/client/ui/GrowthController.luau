local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GrowthConfig = require(ReplicatedStorage.Shared.GrowthConfig)
local GrowthMath = require(ReplicatedStorage.Shared.GrowthMath)
local NumberFormatter = require(ReplicatedStorage.Shared.NumberFormatter)
local UiStyle = require(script.Parent.UiStyle)
local UiText = require(script.Parent.UiText)

local GrowthController = {}

local function label(parent, name, text, y, height)
	local result = UiStyle.Text(parent, name, text, UDim2.new(1, -20, 0, height), UDim2.fromOffset(10, y))
	result.TextSize = 14
	return result
end

local function button(parent, name, text, y)
	local result = UiStyle.Button(parent, name, text, UDim2.new(1, -20, 0, 44), UDim2.fromOffset(10, y))
	result.TextSize = 14
	return result
end

function GrowthController.Start(panel: Frame, stateController)
	local remote = ReplicatedStorage:WaitForChild("IdleRaidRemotes"):WaitForChild("GrowthAction")
	local trainingRemote = ReplicatedStorage.IdleRaidRemotes:WaitForChild("SetTrainingEnabled")
	local tabNames = { "돌파", "시설", "수련권" }
	local tabs = {}
	local views = {}
	local currentState
	local selectedPreview
	local busy = false

	local title = label(panel, "Title", "성장", 8, 26)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextColor3 = UiStyle.Colors.Gold
	local feedback = label(panel, "Feedback", "", 36, 28)
	feedback.TextColor3 = UiStyle.Colors.Accent
	feedback.TextSize = 12

	for index, name in ipairs(tabNames) do
		local tab = UiStyle.Button(panel, "Tab" .. index, name,
			UDim2.new(1 / 3, -8, 0, 42), UDim2.new((index - 1) / 3, 6, 0, 67))
		tabs[index] = tab
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = "Growth" .. index
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.ScrollBarThickness = 5
		scroll.Size = UDim2.new(1, -10, 1, -116)
		scroll.Position = UDim2.fromOffset(5, 112)
		scroll.CanvasSize = UDim2.fromOffset(0, 640)
		scroll.Visible = index == 1
		scroll.Parent = panel
		views[index] = scroll
		tab.Activated:Connect(function()
			for viewIndex, view in ipairs(views) do
				view.Visible = viewIndex == index
				tabs[viewIndex].BackgroundColor3 = if viewIndex == index then UiStyle.Colors.Accent else UiStyle.Colors.Surface
			end
			selectedPreview = nil
		end)
	end
	tabs[1].BackgroundColor3 = UiStyle.Colors.Accent

	local stageLine = label(views[1], "Stage", "돌파 1단계", 4, 22)
	local availableLine = label(views[1], "Available", "사용 가능 수련력 --", 29, 27)
	availableLine.TextColor3 = UiStyle.Colors.Gold
	local costLine = label(views[1], "Cost", "다음 돌파 비용 --", 60, 22)
	local gateLine = label(views[1], "Gate", "다음 관문 --", 86, 22)
	local previewLine = label(views[1], "Preview", "돌파 방법을 선택하세요", 113, 74)
	previewLine.TextWrapped = true
	previewLine.TextColor3 = UiStyle.Colors.Accent
	local stepButtons = {}
	for index, steps in ipairs({ 1, 2, 3, 5 }) do
		local row = button(views[1], "Step" .. steps, if steps == 1 then "무료 +1" else "+" .. steps .. "권 사용", 195 + (index - 1) * 49)
		stepButtons[steps] = row
	end
	local confirm = button(views[1], "ConfirmBreakthrough", "돌파 확정", 400)
	confirm.Visible = false
	local purchaseNote = label(views[1], "ProductNote",
		"추가 구매: 준비 중 · 가격 및 상품 ID 미설정\n돌파권은 앞으로의 수련 단계만 올립니다. 관문은 직접 클리어해야 합니다.", 451, 70)
	purchaseNote.TextSize = 12
	purchaseNote.TextColor3 = UiStyle.Colors.Muted

	local facilityLine = label(views[2], "Facility", "현재 시설 1단계", 9, 30)
	facilityLine.TextColor3 = UiStyle.Colors.Gold
	local facilityNext = label(views[2], "FacilityNext", "", 49, 85)
	local facilityBuy = button(views[2], "FacilityBuy", "Gold로 시설 업그레이드", 142)
	local trainingToggle = button(views[2], "TrainingToggle", "기본 수련 켜기/끄기", 198)
	local facilityNote = label(views[2], "FacilityNote",
		"시설은 Gold로 영구 개선합니다.\n새 배수가 이전 배수를 대체하며 돌파 비용은 그대로입니다.", 254, 70)
	facilityNote.TextColor3 = UiStyle.Colors.Muted

	local voucherIntro = label(views[3], "VoucherIntro",
		"수련권은 현재 기본 획득량/초를 기준으로 즉시 수련력을 줍니다.\n돌파나 관문 클리어를 자동으로 하지 않습니다.", 7, 65)
	local voucherButtons = {}
	for index, voucherId in ipairs({ "Minutes10", "Minutes30", "Minutes120" }) do
		voucherButtons[voucherId] = button(views[3], voucherId, GrowthConfig.Vouchers[voucherId].Label, 82 + (index - 1) * 54)
	end
	local voucherPreview = label(views[3], "VoucherPreview", "수련권을 선택하세요", 257, 72)
	voucherPreview.TextColor3 = UiStyle.Colors.Accent
	local voucherConfirm = button(views[3], "VoucherConfirm", "수련권 사용 확정", 335)
	voucherConfirm.Visible = false
	local voucherProduct = label(views[3], "VoucherProduct",
		"추가 구매: 준비 중 · 가격 및 상품 ID 미설정\n보유한 수련권은 조건이 맞을 때 사용할 수 있습니다.", 390, 64)
	voucherProduct.TextSize = 12
	voucherProduct.TextColor3 = UiStyle.Colors.Muted

	local function invoke(action, payload)
		local ok, result = pcall(function() return remote:InvokeServer(action, payload) end)
		if not ok or typeof(result) ~= "table" then
			feedback.Text = "서버 응답을 확인하지 못했습니다"
			return nil
		end
		if not result.Ok then
			feedback.Text = UiText.Reason(result.Reason)
		else
			feedback.Text = UiText.Ready
		end
		return result
	end

	for steps, row in pairs(stepButtons) do
		row.Activated:Connect(function()
			if busy or not currentState or not currentState.Ready then return end
			busy = true
			local result = invoke("PreviewBreakthrough", { Steps = steps })
			busy = false
			if not result then return end
			if not result.Ok then
				selectedPreview = nil
				confirm.Visible = false
				previewLine.Text = UiText.Reason(result.Reason)
				return
			end
			selectedPreview = { Kind = "Breakthrough", Steps = steps, Stage = result.Stage }
			previewLine.Text = string.format("%d → %d단계  |  배수 x%s → x%s\n기본 수련 %s → %s/초\n비용 %s · 다음 관문 %s",
				result.Stage, result.TargetStage, NumberFormatter.Format(result.CurrentMultiplier),
				NumberFormatter.Format(result.TargetMultiplier), NumberFormatter.Format(result.CurrentRate),
				NumberFormatter.Format(result.TargetRate), NumberFormatter.Format(result.Cost),
				result.NextGate and result.NextGate.Stage or "완료")
			confirm.Visible = true
		end)
	end
	confirm.Activated:Connect(function()
		if busy or not selectedPreview or selectedPreview.Kind ~= "Breakthrough" then return end
		busy = true
		local result = invoke("Breakthrough", {
			Steps = selectedPreview.Steps, ExpectedStage = selectedPreview.Stage,
			RequestId = HttpService:GenerateGUID(false),
		})
		busy = false
		selectedPreview = nil
		confirm.Visible = false
		if result and result.Ok then
			feedback.Text = string.format("%d단계 돌파 성공", result.Stage)
			previewLine.Text = "다음 돌파 방법을 선택하세요"
		end
	end)

	facilityBuy.Activated:Connect(function()
		if busy or not currentState or not currentState.Ready then return end
		busy = true
		local result = invoke("UpgradeFacility", {
			ExpectedTier = currentState.TrainingFacilityTier,
			RequestId = HttpService:GenerateGUID(false),
		})
		busy = false
		if result and result.Ok then feedback.Text = string.format("시설 %d단계 해금", result.Tier) end
	end)
	trainingToggle.Activated:Connect(function()
		if currentState and currentState.Ready then
			trainingRemote:FireServer(not currentState.TrainingEnabled)
		end
	end)

	for voucherId, row in pairs(voucherButtons) do
		row.Activated:Connect(function()
			if busy or not currentState or not currentState.Ready then return end
			busy = true
			local result = invoke("PreviewVoucher", { VoucherId = voucherId })
			busy = false
			if not result or not result.Ok then
				selectedPreview = nil
				voucherConfirm.Visible = false
				voucherPreview.Text = result and UiText.Reason(result.Reason) or "미리보기를 확인할 수 없습니다"
				return
			end
			selectedPreview = { Kind = "Voucher", Id = voucherId, Rate = result.Rate, Count = result.Count }
			voucherPreview.Text = string.format("%s 보유 %d장\n현재 기본 수련 %s/초 × %d초 = +%s 수련력",
				GrowthConfig.Vouchers[voucherId].Label, result.Count, NumberFormatter.Format(result.Rate),
				GrowthConfig.Vouchers[voucherId].Seconds, NumberFormatter.Format(result.Grant))
			voucherConfirm.Visible = true
		end)
	end
	voucherConfirm.Activated:Connect(function()
		if busy or not selectedPreview or selectedPreview.Kind ~= "Voucher" then return end
		busy = true
		local result = invoke("UseVoucher", {
			VoucherId = selectedPreview.Id, ExpectedRate = selectedPreview.Rate,
			ExpectedCount = selectedPreview.Count, RequestId = HttpService:GenerateGUID(false),
		})
		busy = false
		selectedPreview = nil
		voucherConfirm.Visible = false
		if result and result.Ok then
			feedback.Text = "+" .. NumberFormatter.Format(result.GrantedPower) .. " 수련력"
			voucherPreview.Text = "다음 수련권을 선택하세요"
		end
	end)

	stateController.Subscribe(function(state)
		currentState = state
		if not state.Ready then
			feedback.Text = UiText.Loading
			return
		end
		local stage = state.BreakthroughStage or 1
		stageLine.Text = string.format("현재 %d단계 · 배수 x%s · 기본 %s/초", stage,
			NumberFormatter.Format(state.StageMultiplier or 1), NumberFormatter.Format(state.BaseTrainingRate or 0))
		availableLine.Text = "사용 가능 수련력  " .. NumberFormatter.Format(state.AvailableTrainingPower or 0)
		costLine.Text = if state.BreakthroughCost then "다음 돌파 비용  " .. NumberFormatter.Format(state.BreakthroughCost)
			else "최고 단계"
		local nextGate = GrowthMath.NextGate(stage, state.ClearedRaidGates or {})
		gateLine.Text = if nextGate then string.format("다음 미클리어 관문: %d단계", nextGate.Stage)
			else "모든 관문 클리어"
		for steps, row in pairs(stepButtons) do
			local count = (state.BreakthroughTickets or {})[tostring(steps)] or 0
			row.Text = if steps == 1 then "무료 +1단계" else string.format("+%d단계권 사용 · %d장", steps, count)
		end
		local tier = state.TrainingFacilityTier or 1
		local facility = GrowthConfig.Facilities[tier]
		local nextFacility = GrowthConfig.Facilities[tier + 1]
		facilityLine.Text = string.format("현재 수련 시설 %d등급 · x%.1f", tier,
			facility.Numerator / facility.Denominator)
		if nextFacility then
			facilityNext.Text = string.format("다음 %d등급 · x%.1f\n필요 Gold %s%s", tier + 1,
				nextFacility.Numerator / nextFacility.Denominator,
				NumberFormatter.Format(nextFacility.GoldCost),
				if nextFacility.RequiredGate then "\n선행 " .. nextFacility.RequiredGate else "")
			facilityBuy.Visible = true
		else
			facilityNext.Text = "최고 시설 등급"
			facilityBuy.Visible = false
		end
		trainingToggle.Text = if state.TrainingEnabled then "기본 자동수련: 켜짐" else "기본 자동수련: 꺼짐"
		for voucherId, row in pairs(voucherButtons) do
			row.Text = string.format("%s · 보유 %d장", GrowthConfig.Vouchers[voucherId].Label,
				(state.TrainingVouchers or {})[voucherId] or 0)
		end
	end)
end

return GrowthController
