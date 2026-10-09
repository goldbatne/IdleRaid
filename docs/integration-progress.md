# OneShot 통합 진행 기록

작업 기준: IdleRaid_OneShot_Build.md (2026-10-09). 기준 HEAD bba9a4f70b2f06ea9d698aed4ae27039419bc0e8, 작업 브랜치 codex/oneshot-build. 원본 IdleRaid.rbxl은 읽기·수정·스테이징하지 않았다.

## 체크포인트

1. **기준선 확인:** 실제 AGENTS.md, Git, Config, ProfileStore, 전투·장비·레이드와 UI를 확인했다. [integration-baseline.json](integration-baseline.json)에 수식과 기존 정책, [product-contracts.json](product-contracts.json)에 판매 비활성 계약을 기록했다.
2. **끊긴 동선 연결:** 보상 알림을 서버 결과와 연결하고, 아이템 알림→가방 선택→장착 전후 비교, 시설/돌파 전후 표시와 다음 목표 버튼을 추가했다. Raid 중 AUTO 조작을 유지했다.
3. **개발 체험 격리:** Studio UI 지급 전 서버의 별도 Sandbox 프로필 전환을 필수로 했다. 일반 프로필과 Sandbox는 서로 다른 mock key를 사용한다. 운영에서는 개발 원격 자체가 만들어지지 않는다.
4. **관문 예외:** 저장 단계가 미클리어 관문보다 높아진 예외 프로필에서 추가 돌파가 허용될 수 있던 순수 계산 경계를 수정했다.
5. **회귀 검사:** 제출 Rojo 빌드 SHA-256은 [manifest](build-manifest.json)에 기록했다. Studio 통합 34개 검사, Luau 수식·이관·오프라인 시뮬레이션, 실제 UI 버튼, Sandbox 원격, 2인 서버 보상 검사가 통과했다.
6. **실제 무료 Play:** 제출 `build/IdleRaid-oneshot.rbxlx`에서 정상 신규 프로필로 사냥→Gold·실제 장비 드롭→비교·장착→시설 개선→무료 +1 돌파→Gate10 솔로 클리어를 실행했다. Gate10 도달 294초, 보스 전투 107.2초, 시작 후 클리어 406초. [CreatorOutput 발췌](test-logs/oneshot-free-play.studio.log)에 서버/클라이언트 PASS가 있다.

## 현재 확인된 범위

- docs/test-logs/oneshot-integration.studio.log: IR_INTEGRATION_RESULT true nil.
- docs/test-logs/oneshot-ui.studio.log: AUTO/T, 격리 프로필, 지급, 무료/권 돌파, 시설, 장착·해제, Raid 입장 IR_UI_SERVER_RESULT true.
- docs/test-logs/oneshot-compare.studio.log: 실제 GrowthConfig/GrowthMath를 읽은 결정적 계산. 전투 시간·킬 속도는 가정이며 실제 클리어가 아니다.
- docs/test-logs/oneshot-sandbox.studio.log: 정상 프로필의 개발 지급 거부, Studio 격리 기록 전환·복원.
- docs/test-logs/oneshot-raid2.studio.log: 두 클라이언트의 서버 보상·HP 스케일링 검사. 실제 2인 전투 공략은 아니다.
- docs/test-logs/oneshot-free-play.studio.log: 제출 파일 자체로 수행한 실제 솔로 무료 플레이와 Slime King 클리어.
- PC/좁은 화면 캡처: Windows Computer Use helper가 helper_unknown_error: setup refresh had errors로 실행되지 않았다. 화면 검사는 별도 미완료로 유지한다.

## 44개 검사 집계

2026-10-10 기준 17 PASS, 21 NOT_RUN, 6 BLOCKED, 0 FAIL. PASS는 지정한 Studio/mock 환경의 실제 실행으로 한정한다. [각 항목과 근거](oneshot-checks.md)에 환경과 한계를 적었다. Studio mock 결과를 게시 서버 DataStore나 실제 결제 검증으로 확대하지 않는다.

## 남은 작업

- 44개 인수 검사의 남은 미검증·차단 항목은 [검사표](oneshot-checks.md)에 개별 기록했다. 완료로 표시하지 않는다.
- Studio mock은 프로세스 종료 시 초기화된다. 동일 유저의 실제 서버 종료·재접속 복원 및 운영 DataStore 동작은 미검증이다.
- 2인 실전 보스 패턴 공략, 실제 모바일, 가격 조회 실패·구매 복구 경로는 미검증이다.
- PC/좁은 화면 시각 확인 도구가 `helper_unknown_error: setup refresh had errors`로 초기화되지 않아 캡처를 만들지 못했다. 오래된 stage10 이미지 대신 이번 빌드의 캡처는 미제출로 기록한다.
- 게시 서버 DataStore, 과거 ProductId 영수증, 실제 모바일, 실제 구매, 원본 사용자 Place 연결은 이번 환경에서 직접 실행되지 않았다.
