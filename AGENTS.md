# IdleRaid 개발 지침

이 폴더는 Roblox Studio + Rojo + Luau로 개발하는 `IdleRaid` 프로젝트의 루트다. 작업 전 기존 파일과 Git 상태를 확인하고, 사용자 파일을 임의로 삭제하거나 덮어쓰지 않는다.

## 게임 방향

- 애니메이션 스타일의 단일 캐릭터 방치형 성장 + 레이드 RPG다.
- 플레이어는 하나의 캐릭터를 레벨, 장비, 스킬로 지속적으로 성장시킨다.
- 여러 무기를 획득하고 교체할 수 있게 설계한다. 장기적으로 빠른 무기 전환도 고려한다.
- EXP는 방치 플레이와 직접 전투 양쪽에서 얻되, 직접 전투가 더 효율적이어야 한다.
- 레이드는 1인 또는 협동 플레이가 가능해야 하며, 핵심 장비와 성장 재료의 주요 획득처다.
- 향후 편의 기능은 Robux 즉시 해금과 긴 플레이를 통한 해금의 두 경로를 고려한다. 현재 과금 기능은 구현하지 않는다.

## 프로젝트 구조

- `src/server`: 서버 전용 Script와 ModuleScript. 전투, 보상, 저장 등 권한이 필요한 판정을 둔다.
- `src/client`: 클라이언트 전용 LocalScript와 ModuleScript. 입력, 화면 표시, 연출을 둔다.
- `src/shared`: 서버와 클라이언트가 함께 참조하는 상수, Config, 순수 로직, 통신 계약을 둔다.
- `default.project.json`: 위 폴더를 Roblox 서비스에 연결하는 Rojo 설정이다.
- `assets/place`: 기존 `IdleRaid.rbxl`에서 추출한 Baseplate, SpawnLocation, Terrain, Camera, Lighting 오브젝트다.
- `IdleRaid.rbxl`: 사용자가 Roblox Studio에서 열어 플레이하는 단일 로컬 Place 파일이다.

## 개발 규칙

- Damage, Gold, EXP, Level, Item Drop, Equipment, Raid Reward의 최종 판정은 서버가 한다. 클라이언트가 보낸 수치나 결과를 신뢰하지 않는다.
- 클라이언트 요청은 행동 의도로 취급하고, 서버에서 유효성과 권한을 확인한 뒤 결과를 계산한다.
- 기능은 가능한 한 역할별 ModuleScript로 분리한다. 현재 필요하지 않은 프레임워크나 과도한 추상화는 만들지 않는다.
- 밸런스 수치가 생기면 Config 모듈에 모아 관리한다. 공유 Config를 사용하더라도 최종 판정은 서버에서 수행한다.
- 입력과 화면은 모바일 사용을 고려한다.
- 문제가 발견되면 원인과 영향을 먼저 설명한다. 기존 파일을 보존하고 임의로 우회하지 않는다.
- 코드 변경 후에는 원본 Place의 Studio 전용 변경 여부를 확인하고 백업한 뒤 `IdleRaid.rbxl`에 최신 Rojo 소스를 반영한다. 사용자가 확인할 파일은 이 원본 하나로 안내하고, 실제 원본 파일을 Studio Play로 검증한다. 원본의 월드 오브젝트가 `assets/place`와 달라졌다면 먼저 보존·동기화한다.
- 출시 전 Studio 자동 테스트도 `IdleRaid.rbxl`을 대상으로 실행한다. 임시 Place 사본을 Studio에서 열어 최근 체험 목록을 늘리지 않는다. 테스트 중 원본 파일을 저장·게시하지 않고, 전후 파일 해시를 확인한다.

## 현재 단계

현재는 서버 PlayerData, 레벨/EXP, SpawnPoint 기반 다중 Enemy, 수동 공격, T 키 및 UI 자동사냥, Gold와 장비 드롭, 서버 Inventory/Equipment, 기본 HUD를 통해 성장 루프를 테스트한다. 첫 레이드 프로토타입은 같은 서버의 RaidArena에서 최대 4명이 Slime King을 상대한다. 서버 RaidService가 참가자, Boss 패턴, 피격, 성공/실패와 보상을 결정한다. Raid 전투 Health는 PlayerData가 원본이며 Humanoid Health는 이동/캐릭터 생존 판정에만 사용한다. Boss HP는 EnemyService의 서버 상태가 원본이다. BasicAttack의 서버 검증은 Raid에서도 재사용한다. 레이드 중 AutoCombat은 Boss만 탐색하며, 수동 이동과 Q 키 또는 모바일 버튼 Dash 입력은 자동 이동과 자동 공격보다 우선한다. Dash의 이동 거리, 쿨다운, 짧은 무적 시간은 서버 RaidService가 판정한다. Ground Slam과 Charge의 피격 판정도 서버가 맡고 UI의 예고 표시는 시각적 안내다. 레이드 종료 시 참가자 복구와 Boss 정리를 수행하고 RaidMetrics로 테스트 결과를 기록한다. 코드가 생성하는 필드와 아레나 장식은 전용 Folder에 두고 기존 Studio 오브젝트를 삭제하지 않는다. EnemyAppearance는 판정용 Enemy 상태와 분리하며, 타격·피격 연출은 서버가 확정한 결과를 받은 클라이언트가 짧게 표시한다. UI의 성장·장비 표시는 서버 상태 동기화를 사용한다. 성장 통합 v2에서는 수련력(사용 가능/누적), 돌파 단계, Gold 시설, 10/20/30 관문, 수련 시간권과 돌파권을 도입했다. Level은 누적 수련력에서 계산하고 별도 EXP 장부를 두지 않는다. PlayerData, Inventory, Equipment, RaidToken, 관문 기록과 구매 기록은 ProfileStore의 단일 v2 프로필에 보관한다. Studio에서는 메모리 모의 저장소를 사용하고, 게시 서버용 DataStore 코드는 아직 실제 게시 환경에서 검증되지 않았다. 오프라인 수련은 저장된 속도와 최대 8시간·25% 효율로 서버에서 정산한다. ProductId와 가격은 모두 미설정이며 실제 판매·Robux 지출은 비활성이다. 개발용 지급과 모의 영수증은 Studio에서만 제공한다. 적 일반 AI, 랜덤 장비 옵션/강화, 무기 모델/전환, 스킬, 레이드 매칭 및 별도 Place, 최종 UI/보스 모델/애니메이션/VFX는 별도 요청 전까지 구현하지 않는다.
