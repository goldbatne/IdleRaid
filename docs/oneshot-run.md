# IdleRaid OneShot 빌드 실행

1. Roblox Studio에서 `build/IdleRaid-oneshot.rbxlx`를 연다. 원본 `IdleRaid.rbxl`을 열거나 저장하지 않아도 된다.
2. **Play**를 누른다. SpawnLocation이 없는 별도 Rojo Place에는 코드가 `Workspace.IdleRaidVisuals.GeneratedPlayerSpawn`을 만든다. 기존 SpawnLocation이 있으면 새로 만들지 않는다.
3. 화면 오른쪽 `AUTO` 또는 T 키로 사냥을 켠다. 사냥 보상은 HUD에 반영되고 장비 획득 알림을 누르면 가방에서 현재/장착 후 스탯을 비교할 수 있다.
4. `성장`에서 Gold 시설을 구매하고 보유 수련력으로 무료 +1 돌파한다. 10단계에서는 `레이드`에서 Gate10에 직접 입장한다. Q 또는 화면 `DASH`로 예고 공격을 피한다.
5. Studio 테스트 전용 `DEV` 메뉴의 지급 버튼은 `개발 Sandbox`로 전환해야 보인다. 정상 프로필에는 개발 지급을 사용할 수 없고 실제 결제도 비활성이다.

이 파일은 Rojo가 별도로 생성한 Place다. 원본 `IdleRaid.rbxl`의 월드나 현재 Rojo 연결 상태를 검증한 결과로 해석하면 안 된다. Studio에서는 메모리 mock 프로필을 사용하므로 Studio 프로세스를 닫았다 다시 열 때 데이터가 영구 복원되지 않는다. 게시 서버 DataStore 접속·종료·재접속은 이번 작업에서 운영 데이터 보호를 위해 실행하지 않았다.

재빌드: `rojo build default.project.json -o build/IdleRaid-oneshot.rbxlx`. 제출 파일의 SHA-256과 소스 식별값은 [build-manifest.json](build-manifest.json)에 있다. 이 재빌드 명령은 동일 경로의 제출 파일을 덮어쓰므로 현재 파일을 보존하려면 다른 출력 이름을 사용한다.
