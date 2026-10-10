# 장비 클릭 시간 초과 재검증 (2026-10-10)

대상은 [안정화 빌드](../build/IdleRaid-review-stabilized.rbxlx) SHA-256 `d2daa8a8edc7a551cc3bd7e1fa251ec4285a49671224653bfb7e3b1d67d78313`이다. Roblox Studio 0.742.0의 **가상입력 자동 테스트**이며 사람의 실제 마우스/터치 확인은 아니다.

## 변경 전 관찰

[첫 UI 실행](test-logs/review-final-ui-full.studio.log)은 자동 버튼, 무료 돌파, 시설 구매까지 통과하고 `Timeout: equip button`으로 실패했다. [같은 빌드 재실행](test-logs/review-final-ui-retry-full.studio.log)은 장비 비교·장착·해제까지 통과했다. 재실행 성공만으로 결함 해소로 간주하지 않는다.

## 같은 초기 상태 반복

`tests/review-ui-click-diagnostic-v1.luau`(01–05 실행 코드)는 매번 Studio 메모리 모의 프로필을 새로 만든다. 1단계, Gold 0, 시설 1, TrainingSword 1개, 나머지 장비 없음, 기본 수련 ON이다. 제작 빌드 및 `src`는 바꾸지 않았다. 같은 화면 좌표 클릭으로 Bag을 열고 장비 행의 `InputBegan`, `InputEnded`, `Activated`, `Destroying`, 선택 후 Equip 버튼 상태를 기록했다.

| 실행 | 결과 | 관찰 | 전체 로그 |
| --- | --- | --- | --- |
| 01 | 성공 | 행 down/Activated 1회, 선택 즉시 행 재생성, Equip 표시 | [run01](test-logs/review-ui-click-run01.studio.log) |
| 02 | 실패 | 초기 프로필 정상. Bag 버튼 가상 클릭 뒤 8초 동안 Bag이 열리지 않음. 장비 행 클릭 전에 종료 | [run02](test-logs/review-ui-click-run02.studio.log) |
| 03 | 성공 | 행 down/Activated 1회, Equip 표시 | [run03](test-logs/review-ui-click-run03.studio.log) |
| 04 | 성공 | 행 down/Activated 1회, Equip 표시 | [run04](test-logs/review-ui-click-run04.studio.log) |
| 05 | 성공 | 행 down/Activated 1회, Equip 표시 | [run05](test-logs/review-ui-click-run05.studio.log) |

## Bag/장비 이벤트를 추가 계측한 동일 상태 반복

`tests/review-ui-click-diagnostic.luau`는 같은 초기 프로필에 Bag 버튼 `Activated`와 클릭 위치·상단 GUI 기록을 추가했다.

| 실행 | 결과 | 핵심 증거 |
| --- | --- | --- |
| 06 | 성공 | Bag Activated 1, 행 Activated 1, Equip 표시. [로그](test-logs/review-ui-click-run06.studio.log) |
| 07 | 성공 | Bag Activated 1, 행 Activated 1, Equip 표시. [로그](test-logs/review-ui-click-run07.studio.log) |
| 08 | 실패 | Bag Activated 0, Bag 미열림. 행 검사 전 종료. [로그](test-logs/review-ui-click-run08.studio.log) |
| 09 | 성공 | Bag 및 행 클릭 정상. [로그](test-logs/review-ui-click-run09.studio.log) |
| 10 | **장비 선택 실패** | Bag Activated 1·열림. 행 MouseDown 1 뒤 상태 revision 3에서 Destroying 1, Activated 0, Equip 숨김. 자연 수련이 켜진 상태이며 테스트 전용 강제 수련력 지급은 없었다. [실패 로그](test-logs/review-ui-click-run10.studio.log) |

08의 Bag 클릭은 핸들러까지 도달하지 않았다. 위치 질의에서 클릭 좌표의 상단 GUI는 GrowthMenu로 보고됐지만 06/07/09의 성공 실행도 같은 좌표 진단이었다. 따라서 API 좌표계나 가상입력 타이밍 문제를 의심하되 Bag의 단일 원인을 확정하지 않는다. 10은 메뉴 입력 실패와 구별되는 **실제 Inventory UI 상태 갱신 경합**이다.

## 의도적으로 상태 갱신을 끼워 넣은 검사

[Race 테스트 코드](../tests/review-ui-click-race.luau)는 별도 Studio 모의 프로필에서 Bag을 연 뒤 실제 가상 MouseDown이 장비 행에 도달한 것을 확인한다. MouseUp 전에 서버가 테스트용 수련력 1000을 지급해 레벨·FinalAttack을 변경한다. 이는 **테스트 전용 서버 스크립트**이며 제출 빌드의 게임 코드는 바꾸지 않는다. 서버 원본 상태 갱신이 UI에 도착한 뒤 MouseUp을 보낸다.

| 실행 | 결과 | 증거 |
| --- | --- | --- |
| 01 | Bag 가상 클릭 실패, 행 검사 전 종료 | [실패 로그](test-logs/review-ui-click-race-run01.studio.log) |
| 02 | Bag 가상 클릭 실패, 행 검사 전 종료 | [실패 로그](test-logs/review-ui-click-race-run02.studio.log) |
| 03 | 행 MouseDown 1 → 서버 상태 갱신 → 기존 행 Destroying 1 → MouseUp 뒤 Activated 0·Equip 숨김. **UI 경합 재현** | [성공적 재현 로그](test-logs/review-ui-click-race-run03.studio.log) |
| 04 | 동일한 UI 경합 재현 | [성공적 재현 로그](test-logs/review-ui-click-race-run04.studio.log) |

03/04의 `IR_UI_RACE_RESULT true`는 **결함 재현 검사가 성공했다는 뜻**이지 장비 클릭 UI가 정상이라는 뜻이 아니다. `InventoryController.render`가 FinalAttack 변경 때 아이템 행을 파괴·재생성하기 때문에 눌림과 놓음 사이 서버 상태 갱신이 있으면 선택 이벤트가 사라질 수 있다. 실제 일반 플레이에서도 레벨업 중 장비 클릭에 같은 경합이 가능하다. 원래 `equip button` 시간 초과가 바로 이 경합으로 발생했는지는 원본 로그에 MouseDown/Destroying 계측이 없어 확정할 수 없다. 새 기능·게임 소스 변경을 금지한 이번 범위에서는 수정하지 않았다.

**분류:** 검출된 원인은 둘이다. Bag 버튼 입력 누락은 가상입력/좌표·동기화 측면의 실패이며 정확한 세부 원인은 미확정이다. 장비 행 실패는 서버 상태 갱신 시 행을 파괴·재생성하는 실제 UI 경합으로 자연 수련 중 재현됐다. 원래 `equip button` 시간 초과 로그에는 이벤트 계측이 없어 원래 실행의 단일 원인을 단정하지 않는다. 실제 사람의 PC/모바일 조작 빈도는 미측정이다. 모든 실패 로그를 보존하며 UI 동선의 최신 검사는 FAIL로 기록한다.
