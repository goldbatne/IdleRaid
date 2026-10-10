# OneShot 44개 인수 검사

상태는 PASS / FAIL / BLOCKED / NOT_RUN만 사용한다. PASS는 해당 환경에서 실제 실행한 증거가 있을 때만 기록한다. 코드 작성·빌드만으로 실제 플레이 항목을 통과시키지 않는다. `oneshot-free-play`는 **Studio 가상입력 자동 통합 테스트**다. RaidTelegraph 좌표를 읽어 회피하며 인간의 육안 공략·모바일 가독성 검사는 아니다. `growth-v2-raid2`는 서버에서 보스 HP를 직접 감소시킨 공동 보상 검사이며 실제 2인 전투 공략이 아니다. 아래 기존 PASS는 이 범위로만 해석한다; 검토 안정화의 신규 회귀 결과는 `oneshot-review-stabilization.md`에 별도 기록한다. 최종 빌드의 UI 가상입력은 첫 실행에서 장비 선택 클릭 시간 초과, 동일 빌드 재실행에서 전체 통과했다. 이 변동은 함께 기록하며 사람의 UI 가독성 판정으로 쓰지 않는다.

| ID | 검사 | 상태 | 실행 환경 | 증거 / 한계 |
| --- | --- | --- | --- | --- |
| X01 | 정상 프로필에서 Command Bar 없이 수련/사냥 → 보상 → 실제 보유 장비 장착 → 시설 개선 → 돌파 → 첫 관문 도전으로 이동한다. 접근 자격과 실제 보유량을 준수한다. | PASS | Studio Play | [최종 빌드 무료 Play 전체 로그](test-logs/review-final-free-play-full.studio.log): Gate10 클리어 406초, 서버/클라이언트 true. 가상입력 자동 통합 검사 |
| X02 | 작은 수련 보상·아이템 획득·레벨업·시설 개선·돌파·관문 성공 알림이 서버 이벤트와 일치하고 중복·과잉 가림이 없다. | NOT_RUN | Studio Play 일부 | 서버 결과 알림 구현·UI 입력은 확인. 각 알림의 화면 표시/가림은 캡처·직접 관찰 미완료 |
| X03 | 시설·돌파·장비 미리보기의 이전/이후 값이 적용 후 서버 원본과 일치한다. 성장 잔액의 자연 증가 때문에 정상 요청이 계속 거부되지 않는다. | PASS | Studio Play mock + 무료 Play | [최종 UI 재실행](test-logs/review-final-ui-retry-full.studio.log) preview_values·적용 rate/Attack 대조; [첫 UI 실행의 클릭 시간 초과](test-logs/review-final-ui-full.studio.log); [최종 무료 Play](test-logs/review-final-free-play-full.studio.log) 수련 중 연속 정상 돌파 |
| X04 | 모의 상품 체험은 격리된 Studio 테스트에서만 가능하고 실제 구매창이나 정상 프로필의 무료 지급을 만들지 않는다. | PASS | Studio Play mock | [sandbox 로그](test-logs/oneshot-sandbox.studio.log): 정상 지급 거부, 별도 기록, 정상 복귀, 재진입 복원 |
| X05 | 무료와 모의 유료 경로가 같은 효과 적용/관문 검증을 호출한다. +5권의 관문 초과 거부 시 아무 자원도 소비되지 않는다. | PASS | Studio Play mock | [integration 로그](test-logs/oneshot-integration.studio.log): 무료/권 돌파, +5 관문 초과 거부 시 장부 보존; [UI 로그](test-logs/oneshot-ui.studio.log) |
| X06 | 레이드 중 상점·성장 패널을 접어도 HP·장판·Dash·자동전투 상태를 조작할 수 있다. 성공/실패 후 정상 성장 화면으로 복귀한다. | NOT_RUN | Studio Play 일부 | 실전 자동공격·Dash는 확인. Raid 중 메뉴 접기 및 HP/장판 시각 가독성 미확인 |
| X07 | ‘다음 목표’ 안내는 실제 가능 상태에 따라 갱신되고, 현행 콘텐츠 끝에서는 없는 다음 관문이나 미사용 상품을 광고하지 않는다. | NOT_RUN | Studio Play 일부 | [UI 검사](test-logs/oneshot-ui.studio.log) 사냥·장비·돌파 목표 전환 확인. 최종 30단계/모든 관문 클리어 화면 미검증 |
| X08 | 최종 파일·현재 커밋·테스트한 빌드·캡처의 빌드 식별값이 일치한다. 다른 임시 Place의 결과를 원본 Place 검증으로 보고하지 않는다. | BLOCKED | 제출 빌드 확인 | [manifest](build-manifest.json)와 실제 테스트 파일 SHA-256 일치. 캡처 생성 실패, 원본 Place 연결 미실행 |
| G01 | 초기값·누적량·잔액·레벨 진행도 일치. | PASS | Studio Play mock | [integration](test-logs/oneshot-integration.studio.log), [UI](test-logs/oneshot-ui.studio.log) 초기/잔액/레벨 확인 |
| G02 | 단일 및 다중 레벨업, 레벨 경계, 큰 수 저장·복원. | NOT_RUN | Studio Luau 일부 | [simulate](test-logs/oneshot-simulate.studio.log) 경계·큰 수 검사. 큰 수 저장 후 동일 사용자 재접속 복원 미확인 |
| G03 | 프레임률·수련 요청 스팸이 시간 수련량을 늘리지 않음. | NOT_RUN | 코드 확인 | 서버 경과시간 정산 구조 확인; 프레임률·악의적 요청 스팸 실험 미실행 |
| G04 | 효과 변경 전후 구간 정산과 중복 수련 루프 방지. | NOT_RUN | Studio Play 일부 | 시설 변경 중 실제 수련 지속 확인; 구간별 정확 정산·루프 중복 스트레스 미실행 |
| G05 | 장비 반복 장착·해제 뒤 스탯 복원, 실제 수동/자동 피해 일치. | NOT_RUN | Studio Play 일부 | UI 장착/해제 스탯 복원과 실전 자동공격 Damage 확인. 반복·수동 Damage 비교 미완료 |
| G06 | UI 입력·수동 이동·Dash와 자동 이동 충돌 방지. | PASS | Studio Play | [free-play 로그](test-logs/oneshot-free-play.studio.log): 자동공격 중 23회 패턴 이동·Dash, 0 피격 |
| G07 | 일반 처치의 성장/Gold/드롭 중복 지급 방지. | NOT_RUN | Studio Play 일부 | 실제 사냥 보상 확인; 동일 Enemy 동시 처치 중복 공격 실험 미실행 |
| U01 | 무료 시설과 같은 등급의 모의 유료 시설 효과 일치. | BLOCKED | 정책 미정 | 유료 시설 상품/권리 계약이 정의되지 않음. 무료 시설은 Play 검증 |
| U02 | 효과 교체/합산/곱셈이 현재 정의 및 미리보기와 일치. | NOT_RUN | Studio Luau 일부 | [simulate](test-logs/oneshot-simulate.studio.log) 수식 확인; 모든 경로의 미리보기 대조 미완료 |
| U03 | 수련 중 잔액 증가로 정상 업그레이드 요청이 계속 거부되지 않음. | PASS | Studio Play | [free-play 로그](test-logs/oneshot-free-play.studio.log): 수련·사냥 중 Gold 120 충족 후 시설 2등급 구매와 rate 30 확인 |
| U04 | +1/+2/+3/+5 이동과 기존 비용 정책 일치. | PASS | Studio Luau + Play mock | [simulate](test-logs/oneshot-simulate.studio.log) +1/+2/+3/+5 관문 경계, [integration](test-logs/oneshot-integration.studio.log) 기존 비용 |
| U05 | 관문 도달 허용, 관문 초과·미클리어 출발·최대치 초과 차단. | PASS | Studio Luau + Play mock | [simulate](test-logs/oneshot-simulate.studio.log), [integration](test-logs/oneshot-integration.studio.log): 관문 도달/초과/미클리어 차단 |
| U06 | 거부/중복 요청에서 권·재화 손실과 이중 적용 없음. | PASS | Studio Play mock | [integration](test-logs/oneshot-integration.studio.log): 거부 시 수련력·권 보존, 수련권 1회 적용 |
| U07 | 같은 요청 재전송은 1회 처리, 다른 정상 요청은 별도로 검증. | PASS | Studio Play mock | [integration](test-logs/oneshot-integration.studio.log): 같은 요청 ID 재전송 1회 처리, 독립 요청 진행 |
| U08 | 비참가자 보상 차단, 기존 공동 보상, 이탈·전멸·재입장 정리. | NOT_RUN | Studio 2인 일부 | [raid2](test-logs/oneshot-raid2.studio.log): 공동 보상·중복 방지. 이탈/전멸/재입장 전체 실험 미실행 |
| P01 | 상품 ID 미설정/판매 비활성/가격 실패에서 실결제창 없음. | NOT_RUN | 설정 확인 | ProductId/가격 null, 판매 false; 실제 가격 조회 실패·결제창 테스트 금지/미실행 |
| P02 | 같은 영수증 순차/동시 재처리 시 영구 지급 1회. | PASS | Studio mock | [최종 concurrent](test-logs/review-final-receipt-concurrent-full.studio.log): 동시 2회+저장 후 재시도에서 권 1장; [integration](test-logs/oneshot-integration.studio.log) 순차 중복 |
| P03 | 핸들러 false·저장 실패를 성공으로 처리하지 않음. | PASS | Studio mock | [최종 자동 저장 복구](test-logs/review-final-receipt-full.studio.log) 실패→일반 저장만으로 pending 해제·권 1장; [최종 integration](test-logs/review-final-integration-full.studio.log) 실패·재시도 |
| P04 | 커밋 후 응답 전 종료·재접속에서 중복 지급 없음. | NOT_RUN | Studio mock 일부 | 저장된 영수증 재시도 확인. 커밋 직후 프로세스 종료·동일 사용자 재접속 미실행 |
| P05 | 판매 중지 상태에도 알려진 과거 영수증의 지급 경로 유지. | BLOCKED | 과거 상품 ID 없음 | 기존 과거 판매 ProductId 목록이 없어 해당 영수증을 재현할 수 없음 |
| P06 | 구매 도중 무료 획득·상한 도달에서 구매 권리 손실 없음. | NOT_RUN | Studio mock | 구매 중 무료 획득/상한 도달 경쟁 상황 미실행 |
| P07 | 소유 Pass 재접속 적용과 소비형 권의 처리가 혼동되지 않음. | BLOCKED | Pass 계약 없음 | 현재 정의된 Pass가 없어 소유 복원 비교 불가 |
| P08 | 프로필 로드 실패·잠금 상실·서버 경쟁에서 덮어쓰기 방지. | BLOCKED | Studio mock 일부 | [최종 프로필 재시도](test-logs/review-final-profile-full.studio.log) mock 외부 잠금 해제 후 Ready·Gold 37 복구; [integration](test-logs/review-final-integration-full.studio.log) mock 잠금 상실. 운영 DataStore 경쟁은 미검증 |
| P09 | 저장 재시도 중 일반 성장/인벤토리를 오래된 스냅샷으로 덮지 않음. | NOT_RUN | Studio mock | 자동 저장 재시도 중 동시 성장·인벤토리 변경 경쟁 실험 미실행 |
| P10 | 오프라인 반복 수령·시간 상한·음수 시간·변경 후 소급 적용 방지. | PASS | Studio Luau mock | [simulate](test-logs/oneshot-simulate.studio.log): 반복 0, 8시간 한도, 미래 시각 0, 수련 OFF 0, 저장 속도 기준 |
| P11 | 스키마 이관 재실행 시 자산 보존, 테스트/운영 데이터 분리. | NOT_RUN | Studio Luau 일부 | [simulate](test-logs/oneshot-simulate.studio.log) v1→v2 재이관 보존. 운영 데이터 분리 실제 접속 미실행 |
| P12 | 운영 클라이언트의 모의 구매/강제 지급 접근 차단. | NOT_RUN | Studio Play + 코드 | [sandbox](test-logs/oneshot-sandbox.studio.log) 정상 프로필 원격 거부. 게시 서버 클라이언트 미실행 |
| V01 | 메인 성장 수치·메뉴별 상세 스탯/토큰 배치. | NOT_RUN | 코드 확인 | HUD/캐릭터/레이드 메뉴 분리 구현. 실제 PC·좁은 화면 시각 판독 미완료 |
| V02 | 획득→가방→비교→장착, 시설→수련량 변화의 실제 버튼 동선. | PASS | Studio Play | [free-play 로그](test-logs/oneshot-free-play.studio.log): 아이템 드롭→가방 비교→장착, Gold 시설→rate 변화 |
| V03 | 돌파 비용·조건·전후 수치·불가 사유가 서버와 일치. | NOT_RUN | Studio Play 일부 | [UI 검사](test-logs/oneshot-ui.studio.log) 돌파 비용·전후 rate 일치. 모든 거부 사유의 화면 대조는 미완료 |
| V04 | PC·좁은 화면·터치 에뮬레이션과 실제 모바일 결과 구분. | BLOCKED | Computer Use 오류 | [최종 모바일 버튼 경로](test-logs/review-final-mobile-full.studio.log) 테스트 전용 위치에서 가상 클릭→Slime HP 40→30. 화면 helper 프로세스 종료 오류로 PC/좁은 캡처 미확보; 원래 버튼 배치·실기 터치는 미검증 |
| V05 | 실제 솔로 보스 공략, 2인 공략과 공동 보상. | NOT_RUN | Studio Play + 2인 서버 검사 | [free-play](test-logs/oneshot-free-play.studio.log) 솔로 실전 클리어; [raid2](test-logs/oneshot-raid2.studio.log) 2인 서버 보상만. 2인 실전 공략 미실행 |
| V06 | 임시 Place와 실제 사용자 Place의 Rojo 연결 검사 구분. | PASS | 보고서/빌드 식별 | [manifest](build-manifest.json)에 별도 Rojo Place 식별. 원본 IdleRaid.rbxl 연결 검증으로 주장하지 않음 |
| V07 | 리스폰·UI 재열기·레이드 반복 후 이벤트/이펙트 정리. | NOT_RUN | Studio Play 일부 | 실전 레이드 1회 종료 확인. 리스폰·반복 레이드·UI 재열기 누수 검사는 미실행 |
| V08 | 실제 무료/모의 유료 동일 조건 비교와 원본 로그. | NOT_RUN | Studio Luau 모의 | [비교](oneshot-compare.md)는 같은 수식/정책의 결정적 가정. 모의 유료 실제 Play 관문 클리어 시간은 미측정 |
| V09 | Rojo 빌드, 사용 가능한 Luau 검사, git diff --check. | PASS | Rojo + Studio + Git | 최종 안정화 Rojo .rbxlx 빌드, 내장 Script 43/43 소스 일치, Studio ModuleScript 41/41 로드, git diff --check. [새 manifest](review-build-manifest.json) |
