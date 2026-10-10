# 안정화 빌드 추가 검증 (2026-10-10)

## 범위와 보존

이번 작업은 검증·문서·패키징만 수행했다. `src`, 경제 수치, 돌파 비용, 보스 수치, 가격, ProductId, 운영 저장 데이터, 원본 `IdleRaid.rbxl`을 변경하지 않았다. 실제 판매 OFF와 `main` 병합 보류를 유지한다. 대상은 [안정화 빌드](../build/IdleRaid-review-stabilized.rbxlx)이며 [빌드/소스 대조](review-build-manifest.json)의 43개 Script가 현재 `src`와 일치한다.

## 장비 클릭 시간 초과

[동일 프로필 반복 진단과 성공·실패 원본 로그](review-ui-click-diagnostic.md)를 참조한다. 초기 5회는 4회 성공·Bag 메뉴 실패 1회였다. 추가 5회는 3회 성공·Bag 메뉴 실패 1회·자연 수련 상태 갱신 중 장비 행 선택 실패 1회였다. 이전 `equip button` 시간 초과의 단일 원인은 확정하지 않았다. 별도 Race 검사는 실제 서버 레벨 갱신이 MouseDown과 MouseUp 사이에 오면 장비 행이 파괴되어 선택이 사라지는 UI 경합을 2회 재현했다. Bag 메뉴 가상 클릭 실패도 별도로 4회 관찰했다. 최신 V02 UI 동선 검사는 FAIL로 남겼다. 재실행 성공만으로 해결됐다고 처리하지 않았다.

## 성장·관문 실제 Play

[동일 조건 Studio 가상입력 비교](review-matched-play.md)와 [기계 추출 CSV](review-matched-play.csv)에 무료 / 모의 +5권 1회 / 모의 10분권 1회의 관문 도달, 입장 대기, 보스 전투, 클리어 구간을 분리한다. 세 경로는 새 메모리 프로필과 동일한 장비·시설 정책으로 실행했다. 권 사용 단계와 시점은 로그 마커에 남긴다. 실제 플레이 중 드롭 난수는 고정하지 않았으므로 차이를 권만의 순효과라고 단정하지 않는다. 첫 실행과 계측 정정 재실행을 모두 보존한다. Gate20/30은 실제 Play로 검증하지 않았다.

기존 [결정적 수식 모델](review-equal-compare.md)은 레이드 중 기본 수련을 각 전투 초마다 반영한다. 최고 개방 Zone에서 분당 8킬이라는 사냥 가정은 실제 최근접 대상 선택과 다르며 미수정이다. 모델의 도달·가정 클리어 시간은 실제 Play PASS가 아니다.

## 검사·환경·남은 위험

[44개 검사 원표](oneshot-checks.md)는 현재 **17 PASS / 1 FAIL / 20 NOT_RUN / 6 BLOCKED**다. Gate10 세 경로 실제 Play로 V08만 범위를 제한해 PASS로 올렸다. [신규 증거 연결 및 실행 가능성 분류](review-stabilized-checks.md)도 함께 참조한다. Studio에서 가능한 미실행 검사와 게시 서버 DataStore, 실제 모바일, 과거 상품 식별값 같은 외부 권한·정책 의존 검사를 구분했다. Studio 자동 테스트는 사람의 보스 회피 난도·PC/좁은 화면 가독성·실기 모바일·운영 DataStore를 검증하지 않는다. 화면 도구 오류와 무관하게 Studio/코드/패키지 검증을 계속했다.

제출 ZIP의 정확한 HEAD, 미커밋 파일, 빌드 대응, 재현 명령, 저장 모드, 판매 상태, 제외 파일과 해시는 [ZIP README](../REVIEW_STABILIZED_README.md) 및 [패키지 manifest](review-stabilized-package-manifest.json)에 기록한다.
