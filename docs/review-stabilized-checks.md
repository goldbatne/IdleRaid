# 안정화 검토의 44개 검사 연결

기준 [44개 검사표](oneshot-checks.md)의 각 행은 ID·현재 상태·증거 경로·한계를 보유한다. 상태는 새 실제 실행 결과만으로 변경한다. [장비 클릭 반복](review-ui-click-diagnostic.md)과 [같은 조건 성장 Play](review-matched-play.md)의 신규 로그는 아래 행에 추가 연결한다.

| ID | 신규 근거 | 판정 범위 |
| --- | --- | --- |
| X01 | [같은 조건 무료 Play 로그](test-logs/review-matched-free.studio.log) | 실제 완료 마커를 확인한 경우에만 기존 Studio 가상입력 범위의 재검증 |
| G01 | [세 경로 초기 상태](review-matched-play.csv) | Stage 1, Gold 0, 시설 1, Attack 10, Inventory 0을 실제 Studio snapshot으로 기록 |
| X03 | [클릭 5회 조사](review-ui-click-diagnostic.md), 특히 [실패 02](test-logs/review-ui-click-run02.studio.log) | 기존 PASS는 미리보기 수치 대조에 한정. 간헐적 클릭 실패는 미해결 |
| G06 | [세 경로 Raid 원본 로그](review-matched-play.md) | 가상 이동·Dash 회피 경로. 사람 조작감 검사는 아님 |
| U04·U05 | [+5권 사용 로그](test-logs/review-matched-ticket5-rerun.studio.log) | 1→6 사용 후 Gate10은 직접 도달·공략. 거부/경계 전체는 기존 검사표 근거 참조 |
| V02 | [총 10회 자연 클릭 및 Race 조사](review-ui-click-diagnostic.md), [자연 실패 run10](test-logs/review-ui-click-run10.studio.log) | **FAIL**: 상태 갱신 중 행이 파괴되어 선택이 누락됨. 성공 동선도 별도 보존 |
| V05 | [세 경로 솔로 Raid 원본 로그](review-matched-play.md) | Gate10 솔로 실제 전투. 2인 실전은 미실행 |
| V08 | [동일 조건 비교표](review-matched-play.md), [원본 로그 추출 CSV](review-matched-play.csv) | Gate10 실제 Play 성공분만 측정. Gate20/30은 수식 시뮬레이션으로 통과 처리하지 않음 |
| V09 | [빌드 manifest](review-build-manifest.json), [최신 ZIP manifest](review-stabilized-package-manifest.json) | 검토 ZIP의 파일/해시·소스 대응을 별도 확인 |

## 아직 Studio에서 실행 가능한 검사

아래는 **미실행·부분 실행**이며 외부 운영 권한이 없어도 Studio mock/Play, Studio 2인 세션 또는 로컬 UI 화면 확인으로 추가 검증할 수 있다. 실행 전까지 통과가 아니다.

- X02, X06, X07, X08의 화면 부분
- G02, G03, G04, G05, G07
- U02, U08
- P01의 미설정 상태 확인, P04, P06, P09, P11의 mock 부분
- V01, V03, V04의 PC·좁은 화면 에뮬레이션 부분, V05의 2인 실전, V07
- V08의 Gate20·Gate30 실제 Play와 여러 시드 반복

## 별도 정책 계약 또는 외부 권한이 필요한 검사

| ID | 필요한 것 | 현재 분류 |
| --- | --- | --- |
| U01 | 유료 시설 상품 및 권리 계약 정의 | 정책 미정, 현재 판매 비활성 |
| P05 | 실제 과거 ProductId/영수증 계약 | 상품 식별값 부재 |
| P07 | Pass 상품·소유 계약 | 상품 정의 부재 |
| P08 | 게시 서버 DataStore의 실제 동시 서버 접근 | 운영 권한·게시 환경 필요. Studio mock 잠금 경로는 기존 로그에 별도 기록 |
| P11 | 운영 데이터와 모의 데이터의 실제 저장소 분리 확인 | 게시 환경 권한 필요. 스키마 mock 검사는 Studio 가능 |
| P12 | 게시 서버에서 개발 전용 지급 경로의 접근 차단 | 게시 서버 권한 필요. Studio 정상 프로필 차단 로그는 기존 검사표에 있음 |
| V04 | 실제 모바일 기기에서 터치·가독성 확인 | 실기 필요. Studio 에뮬레이션은 로컬에서 별도 실행 가능 |
| X08 | 실제 사용자 Place의 Rojo 연결·캡처 일치 | 해당 Place에 접근하고 화면을 확인할 권한·도구 필요 |

화면 도구의 오류는 위 Studio mock/자동 검사를 중단시키지 않았다. 원본 Place나 실제 운영 DataStore의 검증을 임시 rbxlx 테스트의 PASS로 대체하지 않는다.
