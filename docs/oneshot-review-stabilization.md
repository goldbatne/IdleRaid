# OneShot 검토 안정화 결과 (2026-10-10)

## 실행 빌드와 재현

- 빌드: [`build/IdleRaid-review-stabilized.rbxlx`](../build/IdleRaid-review-stabilized.rbxlx). Roblox Studio에서 **File → Open from File**로 연 뒤 Play한다. 이 파일은 Rojo가 생성한 별도 Place이며 `IdleRaid.rbxl`을 열거나 저장하지 않았다.
- 브랜치: `codex/oneshot-review-stabilization`. 기준 HEAD: `5ac1da7b115359314390d152ff880294911b5a39`. 최종 안정화 커밋은 제출 응답에 기록한다. `main`에 병합하지 않았다.
- 기준 제출 빌드 SHA-256: `6681bf4eaf50a7178decf112820ae935a2137af590bbd7743220bc55ec5c7854`.
- 새 빌드 SHA-256: `d2daa8a8edc7a551cc3bd7e1fa251ec4285a49671224653bfb7e3b1d67d78313`. `src` 입력 SHA-256: `7fec3001a388a875b57dddae6c3a6576095b187714aab49f4fe53ecf25660022`. 빌드 내 Script 43개가 현재 `src` 43개와 일치했다.
- 도구: Rojo 7.7.1, Roblox Studio 0.742.0. Studio Play 저장은 메모리 모의 저장소다. 게시 서버 DataStore는 실행하지 않았다. ProductId·가격은 미설정, 실제 판매 OFF다.
- 재빌드: `rojo build default.project.json -o build/IdleRaid-review-stabilized-rebuilt.rbxlx`. 소스 대조: `python tests/review-build-source.py build/IdleRaid-review-stabilized.rbxlx`. `git diff --check`도 통과했다.
- Studio Play 테스트 예: `& tests/run-review-play.ps1 -TestName review-profile-retry.luau -Marker IR_REVIEW_R03_RESULT -LogName local-profile.studio.log`. 런처는 설치된 Studio를 찾아 새 빌드를 열고 완료 마커가 든 Studio 전체 로그를 비식별화한다. 생성된 파일을 기존 제출 로그와 섞지 않는다.

## 지적 사항별 변경 전 재현과 변경 후 결과

| ID | 기준 빌드의 재현 | 새 빌드의 결과 | 검증 한계 |
| --- | --- | --- | --- |
| R03 프로필 로드 | [전체 로그](test-logs/review-before-profile-full.studio.log): 외부 유효 잠금 해제 후에도 `SessionLocked`, Gold 37 복구 실패 | [전체 로그](test-logs/review-final-profile-full.studio.log): 외부 잠금을 유지한 채 `Loading`, 해제 후 같은 접속에서 `Ready`, Gold 37 | 제한 시간 초과·로드 중 이탈·게시 서버 DataStore 경쟁은 미검증 |
| R04 영수증 | [전체 로그](test-logs/review-before-receipt-full.studio.log): 저장 실패 뒤 일반 `Save` 성공에도 pending 유지 | [전체 로그](test-logs/review-final-receipt-full.studio.log): 일반 저장만으로 pending 해제, 권 1장·영수증 기록 1개, 재전달 중복 없음, 예외 후 busy 해제. [동시 전달 회귀](test-logs/review-final-receipt-concurrent-full.studio.log) 통과 | 실제 플랫폼 영수증 재전달·프로세스 종료 직후 재접속은 미검증 |
| R05 수련력 상한 | [오프라인 경계](test-logs/review-before-cap.studio.log): 상한−1에서 정산 `PowerCap` 실패. [온라인 로그](test-logs/review-before-cap-full.studio.log): 수련권 미리보기 허용, 온라인 정산 false. 이 실행에서 `Save` 자체는 true여서 저장 실패까지 재현됐다고 주장하지 않는다 | [오프라인 경계](test-logs/review-final-cap-boundary.studio.log): 남은 1 지급 후 상한. [온라인·수련권 전체 로그](test-logs/review-final-cap-full.studio.log): 권 사용 `PowerCap` 거부·권 보존, 정산 true, 저장 true, 두 수련력 장부 모두 정확히 상한 | 상한 초과 손상 프로필과 실제 DataStore 재로드는 별도 |
| R06 자동사냥 | [코드 경로 검사](test-logs/review-before-client-paths.studio.log): 일반 상태 갱신 때도 취소하는 조건 존재 | [전환 검사](test-logs/review-final-state-auto.studio.log): 일반 필드 갱신은 유지, 레이드 참가/차단/이탈 전환은 초기화. [코드 경로](test-logs/review-final-client-paths.studio.log) 확인 | 실제 먼 적 MoveTo 취소 횟수 계측과 리스폰 연속 조작은 미실행 |
| R07 부분 상태 삭제 | [코드 경로](test-logs/review-before-client-paths.studio.log): 삭제 프로토콜 없음 | [전환 검사](test-logs/review-final-state-auto.studio.log): 29→30 부분 갱신 뒤 비용 `nil`, 최종 관문 표시 수식 검사. `_ClearKeys` 명시 삭제 | 실제 최고 단계 UI 화면 판독 미실행 |
| R09 모바일 공격 | [코드 경로](test-logs/review-before-client-paths.studio.log): 터치 버튼·중앙 조준 함수 없음 | [Studio 가상입력 전체 로그](test-logs/review-final-mobile-full.studio.log): 버튼 `Activated` → 기존 `BasicAttack` → Slime HP 40→30. 사거리·Damage는 서버 기존 검증 사용 | CLI 가상 포인터를 위해 테스트에서만 버튼을 화면 안쪽으로 옮기고 강제로 표시했다. 원래 배치·터치 실기·조이스틱 충돌은 미검증 |

프로필은 일시 잠금/통신 실패만 제한된 backoff와 jitter로 재시도한다. 손상 잠금과 스키마 오류는 별도로 끝내고 오류 안내와 재접속 문구를 보여준다. 영수증은 PurchaseId별 pending revision을 저장된 스냅샷의 영수증 기록과 함께 확인한 뒤 해제한다. 자동·오프라인 수련은 사용 가능/누적 장부에서 더 작은 잔여 공간만 지급하며, 수련권은 전체 효과를 지급할 수 없으면 소비하지 않는다. 장착·경제·Raid의 서버 권한과 기존 수치는 유지했다.

## 통합·회귀 테스트

- [최종 무료 Play 전체 로그](test-logs/review-final-free-play-full.studio.log): **Studio 가상입력 자동 통합 테스트**. 수련·사냥·장비·시설·돌파 뒤 Gate10 직접 입장, 정상 공격으로 Clear. 시작→클리어 406초, 보스 전투 107.4초, Slam 12회·Charge 11회, Dash 입력 23회, 피격 0회, 서버·클라이언트 결과 true. 봇은 `RaidTelegraph`의 좌표를 읽어 회피한다. 사람의 시각 판단·조작 난도 증거가 아니다.
- [최종 성장 통합](test-logs/review-final-integration-full.studio.log): 무료/권 돌파, 시설, 수련권, 인벤토리, 토큰, 요청 중복, 잠금 상실, 영수증 실패·재시도가 `IR_INTEGRATION_RESULT true`.
- [최종 UI 가상입력 첫 실행](test-logs/review-final-ui-full.studio.log)은 장비 선택 버튼 대기에서 시간 초과. 동일 빌드 [재실행](test-logs/review-final-ui-retry-full.studio.log)은 자동 버튼·시설·비교·장착/해제·돌파·레이드 참가까지 `IR_UI_SERVER_RESULT true`. 첫 실패를 삭제하거나 통과로 바꾸지 않았다. CLI UI 클릭의 간헐성을 고려해 실제 PC/모바일 UI를 추가 확인해야 한다.
- [ModuleScript 로드](test-logs/review-final-modules.studio.log) 41/41. [새 빌드 manifest](review-build-manifest.json)에 소스·빌드·로그 해시를 기록했다.
- [44개 검사표](oneshot-checks.md): 17 PASS / 21 NOT_RUN / 6 BLOCKED. 기존 PASS는 각 행의 환경·증거에 한정된다. 새 빌드 회귀와 UI 첫 실패/재실행을 표에 반영했다. 실제 2인 보스 공략과 게시 서버 저장은 통과로 승격하지 않았다.

## 동일 조건 무료/모의 권 성장 비교

[방법·가정·결과](review-equal-compare.md), [관문 CSV](review-equal-compare.csv), [1218개 이벤트 CSV](review-equal-events.csv), [최종 Studio 편집 모드 전체 출력](test-logs/review-final-equal-compare.studio.log), [계산 코드](../tests/review-equal-compare.luau)를 함께 제출한다. 세 경로 모두 초기 수련력·Gold 0, 1단계, 시설 1, 무장비·무스킬, 수련 ON, 분당 8킬, 최고 개방 지역, 가능한 시설 즉시 구매 정책으로 독립 실행했다. 레이드 중 기본 수련을 포함한다. 유료 경로는 **Studio 모의 권**이며 결제·Robux 지출이 없다.

| 경로 | Gate10 도달 | Gate20 도달 | Gate30 도달 | 실제 클리어 |
| --- | ---: | ---: | ---: | --- |
| 무료 | 589초 | 1735초 | 3036초 | 미측정 |
| 모의 +5권 | 401초 | 1557초 | 2860초 | 미측정 |
| 모의 10분 수련권 | 477초 | 1630초 | 2933초 | 미측정 |

가정한 전투 시간은 Gate10/20/30에서 60/90/120초이고 모집 대기는 0초다. 이는 비교 시뮬레이션의 가정값이며 실제 클리어 시간이 아니다. 위 406초 무료 가상입력 Play는 처치율·장비·이동·보스 패턴이 다른 실행이므로 이 비교 표와 같은 조건의 실측으로 해석하지 않는다. 경쟁작의 검증되지 않은 수치는 사용하지 않았다.

## 화면·권한·남은 항목

요청한 **최종 빌드의 메인·성장창·레이드 PC 및 좁은 화면 캡처는 확보하지 못했다**. Windows computer-use helper의 `trusted Node process exited unexpectedly; kernel reset` 오류가 재초기화 후에도 반복됐다. 이전 빌드 이미지를 재사용하지 않았다. 따라서 실제 화면 배치·가독성은 통과가 아니다.

[정책·외부 권한 보류](oneshot-policy-gaps.md)에 판매 경로/유료 시설 계약, Charge 판정 의미, Defense 효과, 지역 타깃 효율, 운영 DataStore, 모바일 실기를 구분했다. 실제 결제·운영 저장 데이터 변경·공개 출시·`main` 병합을 수행하지 않았다. 로그 사본은 `tests/review-redact-log.py`로 로컬 사용자 경로, 플레이어 이름/ID, URL, 이메일, 인증·토큰·쿠키 값을 가렸다. 가린 범주만 기록하며 비밀값 자체는 보고서에 넣지 않았다.
