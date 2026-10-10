# Inventory UI 행 경합 수정 검증

## 범위와 원인

기존 `InventoryController.render`는 서버 상태가 갱신될 때마다 모든 아이템 `TextButton`을 파괴하고 다시 만들었다. 자연 수련 중 마우스 버튼을 누른 행이 파괴되면 Roblox의 `Activated`가 발생하지 않아 비교와 장착 버튼이 나타나지 않았다. 기존 [자연 실패 로그](test-logs/review-ui-click-run10.studio.log)는 MouseDown 1, Destroying 1, Activated 0을 기록한다. [강제 상태 갱신 재현 03](test-logs/review-ui-click-race-run03.studio.log)·[04](test-logs/review-ui-click-race-run04.studio.log)의 `IR_UI_RACE_RESULT true`는 **결함 재현 성공**이며 제품 UI의 PASS가 아니다. [원래 장비 버튼 시간 초과](test-logs/review-final-ui-full.studio.log)도 보존한다.

수정 후에는 `rowsByItemId`로 각 행과 `Activated` 연결을 유지한다. 수량·선택·스탯·장착 상태는 기존 버튼의 텍스트, 색상, 비교 설명만 갱신한다. 새 아이템은 뒤에 추가해 눌린 행을 밀지 않고, 실제로 삭제된 아이템 행만 연결 해제 후 파괴한다. 삭제된 선택의 장착 요청은 차단한다. UI 섹션이 제거되면 상태 구독과 행 연결을 해제한다. 서버의 수련·전체 상태 전송은 그대로다.

## 새 빌드에서 직접 실행한 검사

대상은 `build/IdleRaid-review-ui-fixed.rbxlx` SHA-256 `81f97c73de0d348fbb43317695d854709243663f118ed9f74342e9e98f61218f`, Roblox Studio 0.742.0, 격리된 메모리 모의 프로필, **가상입력 자동 테스트**다. 실제 사람의 PC 마우스/실기 모바일 입력 검사는 아니다. 행 경합 검사에서는 Bag 페이지를 테스트 클라이언트에서 직접 열어 메뉴 가상입력의 별도 불안정성과 행 클릭을 분리한다.

| 실행 | 결과 | 근거 |
| --- | --- | --- |
| [run01](test-logs/review-ui-fixed-race-run01.studio.log) | PASS, 초기 검사 | 자연 수련 레벨업, 동일 전체 상태, 수량 증가, 새 드롭, 방어구 장착, 변경 없는 부분 상태. 기존 행 유지, Destroying 0, 선택/장착 버튼 1회, 서버 요청 6회 |
| [run02](test-logs/review-ui-fixed-race-run02.studio.log) | FAIL, 보강 측정 | 자연 레벨업 중 전역 화면 좌표 이동 단언 실패. 행 파괴 여부나 버튼 결과를 이 실행의 PASS로 세지 않음 |
| [run03](test-logs/review-ui-fixed-race-run03.studio.log) | FAIL, 보강 측정 | 자연·동일 전체 상태는 성공. 수량 증가 때 행 전역 X좌표 150→292로 이동; 당시 패널 좌표가 없어 원인 미확정 |
| [run04](test-logs/review-ui-fixed-race-run04.studio.log) | PASS, 상대 좌표·적용 확인 | 여섯 시나리오에서 같은 행, 목록 내 좌표 유지, Destroying 0, 각 Activated 1. 매번 서버 장착 적용 후 해제, 요청 총 6회. 실제 제거 중 눌림에서는 행 1개만 삭제, 장착 숨김·추가 요청 0 |
| [run05](test-logs/review-ui-fixed-race-run05.studio.log) | FAIL, 고정 화면 좌표 입력 | 자연 레벨업 중 패널과 행이 모두 X축 142px 이동, 목록 내 좌표는 일정. 고정 마우스 좌표의 MouseUp이 이동한 버튼에 도달하지 않아 Activated 시간 초과 |
| [run06](test-logs/review-ui-fixed-race-run06.studio.log) | PASS, 뷰포트 안정화 | 화면 배치가 3초 유지된 뒤 시작. 여섯 갱신에서 같은 행·목록 내 위치·Activated 각 1회, 장착 적용/해제 확인 |
| [run07](test-logs/review-ui-fixed-race-run07.studio.log) | PASS, 동일 조건 반복 | run06과 같은 초기 모의 프로필·입력 절차로 재실행해 모두 통과 |

[run04 테스트 코드](../tests/review-ui-fixed-race.luau)는 자연 수련으로 1→2 레벨업을 실제 서버 Tick에서 발생시킨다. 다른 갱신은 서버 모듈의 `Push`, `AddItem`, `EquipItem`, `PushGrowth`를 사용한다. 한 시나리오마다 MouseDown → 해당 서버 갱신 확인 → 동일 화면 좌표 MouseUp → `Activated` 1회 → 장착 요청 1회와 서버 장착 상태를 확인한다. 실제 제거 테스트는 단지 무효 선택이 장착 요청으로 이어지지 않는지 본다.

run01–05는 계측을 단계적으로 보강하는 중간 테스트 변형으로 실행했다. 현재 제출하는 `tests/review-ui-fixed-race.luau`는 run06/07의 최종 버전이며, 중간 변형의 완전한 원본 파일은 별도로 보존되지 않았다. 각 실행의 원본 Studio 로그와 적용된 빌드 SHA는 보존한다. 전역 좌표 실패 02/03/05를 재실행 성공으로 없던 일처럼 취급하지 않는다. run04/06/07은 패널과 목록에 대한 상대 위치를 추가로 확인했으며 모든 갱신에서 행의 로컬 위치가 `0,0`으로 일정했다. 05에서는 패널과 행 모두 142px 이동한 것이 확인되어 Studio Play 뷰포트 재배치와 고정 가상입력 좌표 간 불일치로 분류한다. 02/03은 당시 패널 좌표가 없어 같은 원인이라고 확정하지 않는다. 테스트는 첫 화면 배치가 3초 안정된 다음 시작하며 클릭 실패를 무조건 재시도하지 않는다.

## 가방 재열기와 스크롤

[첫 가방 반복 실패](test-logs/review-ui-fixed-lifecycle-run01.studio.log)는 메뉴 버튼으로 연 뒤 같은 메뉴 버튼 가상 클릭을 보내 닫으려 했으나 첫 닫기 입력이 전달되지 않았다. 정상 UI의 닫기 버튼을 사용한 [run02](test-logs/review-ui-fixed-lifecycle-run02.studio.log)는 20회 열기·닫기와 행 선택 20회에서 Destroying 0, `Activated` 20회, 전체/부분 상태 갱신 후 스크롤 60→60을 기록했다. 첫 실패를 제품 UI PASS로 세지 않는다. 메뉴 버튼으로 닫는 가상입력 누락의 독립 원인은 아직 확정하지 않았다.

## 추가 회귀와 범위

[프로필 회복](test-logs/review-ui-fixed-profile.studio.log), [영수증 복구](test-logs/review-ui-fixed-receipt.studio.log), [수련력 상한 저장](test-logs/review-ui-fixed-cap.studio.log), [부분 상태·자동사냥 전환](test-logs/review-ui-fixed-state-auto.studio.log), [모바일 공격 버튼 가상입력](test-logs/review-ui-fixed-mobile.studio.log), [성장 통합](test-logs/review-ui-fixed-integration.studio.log), [성장 UI](test-logs/review-ui-fixed-main-ui.studio.log), [모듈 41/41](test-logs/review-ui-fixed-modules.studio.log), [동시 영수증](test-logs/review-ui-fixed-receipt-concurrent.studio.log), [수련력 경계](test-logs/review-ui-fixed-cap-boundary.studio.log), [모의 지급 격리](test-logs/review-ui-fixed-sandbox.studio.log)는 수정 빌드에서 PASS다. [무료·+5권·10분권 Gate10 실측](review-ui-fixed-comparison.md)도 새 빌드의 각 원본 로그와 CSV로 분리한다.

실제 판매는 `GrowthConfig.MonetizationEnabled=false`, 모든 `ProductId=nil` 상태다. 경제 수치·돌파 비용·권 효과·보스 수치·가격을 변경하지 않았으며, 원본 `IdleRaid.rbxl`과 기존 실패 로그를 수정하지 않았다. main 병합은 하지 않는다.
