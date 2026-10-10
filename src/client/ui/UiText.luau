-- Shared UI wording lives here so later localization can replace one table.
local UiText = {
	Loading = "데이터 연결 확인 중",
	Power = "수련력",
	Lifetime = "누적 수련력",
	Available = "사용 가능 수련력",
	Stage = "돌파 단계",
	Level = "레벨",
	Rate = "기본 수련/초",
	Multiplier = "수련 배수",
	Free = "무료 +1",
	Gate10 = "10단계 관문",
	Gate20 = "20단계 관문",
	Gate30 = "30단계 관문",
	Ready = "사용 가능",
	Reasons = {
		ProfileNotReady = "데이터 연결 확인 중",
		ReceiptSaving = "구매 기록 저장 중",
		RaidInProgress = "전투 종료 후 사용 가능",
		InsufficientPower = "수련력 부족",
		PowerCap = "수련력 상한에 도달했습니다. 수련권은 소비되지 않았습니다",
		InsufficientGold = "Gold 부족",
		InsufficientToken = "Raid Token 부족",
		NoTicket = "돌파권 없음",
		NoVoucher = "수련권 없음",
		Gate10 = "10단계 관문 클리어 필요",
		Gate20 = "20단계 관문 클리어 필요",
		Gate30 = "30단계 관문 클리어 필요",
		GateRequired = "이전 관문 클리어 필요",
		MaxStage = "최고 단계",
		MaxFacility = "최고 시설 등급",
		StalePreview = "상태가 바뀌었습니다. 다시 확인하세요",
		RateLimited = "잠시 후 다시 시도하세요",
		Busy = "이전 요청 처리 중",
		InvalidRequest = "요청을 확인할 수 없습니다",
	},
}
function UiText.LoadStatus(status)
	if status == "Loading" or status == nil then return UiText.Loading end
	if status == "SessionLocked" then return "다른 서버 접속이 끝나지 않았습니다. 다시 접속하세요" end
	if status == "SessionLost" then return "저장 세션 연결이 끊겼습니다. 다시 접속하세요" end
	if status == "UnsupportedDataVersion" then return "저장 데이터 버전 확인이 필요합니다" end
	if status ~= "LoadFailed" then return "저장 데이터 확인이 필요합니다: " .. tostring(status) end
	return "데이터 연결에 실패했습니다. 잠시 후 다시 접속하세요"
end

function UiText.Reason(code)
	return UiText.Reasons[code] or "요청을 처리하지 못했습니다"
end
return UiText
