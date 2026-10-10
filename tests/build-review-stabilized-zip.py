"""Package the current review state without touching the original Roblox place."""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
archive = root / "IdleRaid-review-stabilized.zip"
readme = root / "REVIEW_STABILIZED_README.md"
manifest = root / "docs/review-stabilized-package-manifest.json"
build = root / "build/IdleRaid-review-stabilized.rbxlx"
expected = json.loads((root / "docs/review-build-manifest.json").read_text(encoding="utf-8"))
def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()
def git(*args):
    return subprocess.check_output(["git", *args], cwd=root, text=True, encoding="utf-8").rstrip("\r\n")
def rel(path):
    return path.relative_to(root).as_posix()

assert sha(build) == expected["buildSha256"], "review build changed"
assert not git("diff", "--name-only", "--", "src"), "src has unstaged changes"
assert not git("diff", "--cached", "--name-only", "--", "src"), "src has staged changes"
branch = git("branch", "--show-current")
head = git("rev-parse", "HEAD")
status = git("-c", "core.quotePath=false", "status", "--porcelain=v1", "--untracked-files=all")
dirty = sorted({line[3:].strip('"') for line in status.splitlines() if line})
for path in (rel(readme), rel(manifest), rel(archive)):
    if path not in dirty:
        dirty.append(path)
dirty.sort()
readme.write_text(f"""# IdleRaid 안정화 검토 ZIP

- 현재 브랜치: `{branch}`
- 정확한 HEAD: `{head}`
- 제출 빌드: `build/IdleRaid-review-stabilized.rbxlx`
- 빌드 SHA-256: `{expected['buildSha256']}`
- `src` 입력 SHA-256: `{expected['sourceInputSha256']}`. 43개 내장 스크립트가 현재 `src`와 일치한다. `src`는 HEAD 이후 수정되지 않았다. 빌드는 이 HEAD의 소스 상태와 대응한다. 검증용 테스트·문서·로그의 미커밋 변경은 아래 목록에 별도 기록한다.
- 의존성: 저장소에 별도 패키지 매니저/잠금 파일이 없다. Roblox Studio 0.742.0과 외부 설치된 Rojo 7.7.1을 사용했다.
- 저장: Studio는 메모리 모의 저장소. 게시 서버 DataStore 경로는 이 ZIP에서 운영 검증하지 않았다.
- 판매: ProductId·가격 미설정, 실제 판매 OFF. +5권·10분권 비교는 Studio 격리 모의 권리이며 결제하지 않았다.
- `main` 병합: 수행하지 않음.

최신 검증 보고서는 `docs/review-stabilized-verification.md`다. `docs/oneshot-review-stabilization.md`는 이전 단계 기준 보고서이므로 검사 수와 실측 범위가 갱신 전일 수 있다.

## 재현

1. Rojo 7.7.1: `rojo build default.project.json -o build/IdleRaid-review-stabilized-rebuilt.rbxlx`
2. 빌드 대조: `python tests/review-build-source.py build/IdleRaid-review-stabilized.rbxlx`
3. Roblox Studio 0.742.0에서 제출 rbxlx를 **File → Open from File**로 열어 Play.
4. 가상입력 자동 테스트 예: `& tests/run-review-play.ps1 -TestName review-matched-free.luau -Marker IR_MATCH_SERVER_RESULT -LogName local-free.studio.log -TimeoutSeconds 1100`. 같은 방식으로 `review-matched-ticket5.luau`, `review-matched-voucher10.luau` 실행. 실행 간 Studio를 분리하고 각 실행은 새 메모리 모의 프로필을 만든다.
5. 로그 수치 재추출: `python tests/review-extract-matched.py`. 검사표는 `docs/oneshot-checks.md`와 `docs/review-stabilized-checks.md` 참조.

## 미커밋 상태

패키징 시 Git status와 ZIP 출력 파일을 합친 경로 목록이다. 사용자 기존 파일은 삭제·덮어쓰지 않았다. 이 검토 ZIP의 `src`와 빌드는 같은 상태이며, 아래 미커밋 테스트·문서는 빌드에 포함되지 않는 검증 자료다.

""" + "".join(f"- `{path}`\n" for path in dirty) + """
## 제외

- `IdleRaid.rbxl` 원본과 `IdleRaid.rbxl.lock`: 사용자 Place 보호.
- 변경된 `build/IdleRaid-oneshot.rbxlx`, 이전 `IdleRaid-review.zip`: 다른 빌드·기존 제출물과 혼동 방지.
- `IdleRaid_OneShot_Build.md`, `IdleRaid_Codex_Integration_v2.md`, `docs/reviews/`: 사용자 원문/외부 검토 자료. 이번 검토의 실행 필수 입력은 아님.
- `.git`, Python 캐시, 대형 의존성 폴더, `.env`, 인증정보, 실제 플레이어 저장 데이터: 포함하지 않음.
- 이전 스크린샷은 현재 안정화 빌드의 화면 증거로 재사용하지 않음.

로그 분류: `review-before-*`는 수정 전 기준 빌드, `review-final-*`·`review-matched-*`·`review-ui-click-*`는 안정화 빌드, `oneshot-*`는 이전 단계 참고 자료다. 서로 다른 빌드 결과를 같은 실행의 증거로 합치지 않는다.

Studio 전체 로그 사본은 로컬 사용자 경로, 플레이어 이름/ID, URL, 이메일, 인증·토큰·쿠키 값을 비식별화했다. 실제 값은 보관하지 않는다. 장비 클릭 실패 실행과 성공 실행을 모두 포함한다.
""", encoding="utf-8")

files = []
for base in ("src", "tests"):
    files.extend(p for p in (root / base).rglob("*") if p.is_file()
                 and "__pycache__" not in p.parts and p.suffix != ".pyc")
files.extend((root / name) for name in
             ("AGENTS.md", "default.project.json", ".gitattributes", ".gitignore"))
files.extend((root / "docs").glob("*.md"))
files.extend((root / "docs").glob("*.csv"))
files.extend((root / "docs").glob("*.json"))
files.extend((root / "docs/test-logs").glob("*.studio.log"))
files.extend((build, readme))
files.extend(p for p in root.rglob("AGENTS.md")
             if ".git" not in p.parts and "reviews" not in p.parts)
files = sorted({p for p in files if p.is_file() and p != manifest and p != archive}, key=rel)
for p in files:
    if p.name.startswith(".env") or p.suffix in (".pyc", ".lock") or "reviews" in p.parts:
        raise RuntimeError(f"forbidden file {p}")
    if p.suffix == ".log":
        content = p.read_text(encoding="utf-8", errors="replace")
        if re.search(r"\[IdleRaid\] [A-Za-z0-9_]+ (?:dealt|killed|gained|obtained|reached)|Players\.[A-Za-z0-9_]+\.(?:PlayerScripts|PlayerGui)|C:\\Users\\(?!<REDACTED_USER>)[^\\\s]+|https?://|Bearer [A-Za-z0-9]", content, re.I):
            raise RuntimeError(f"unredacted log {p}")
entries = [{"path": rel(p), "bytes": p.stat().st_size, "sha256": sha(p)} for p in files]
data = {
    "branch": branch, "head": head, "dirtyPathsAtPackage": dirty,
    "build": rel(build), "buildSha256": sha(build),
    "sourceInputSha256": expected["sourceInputSha256"],
    "embeddedScriptsMatch": expected["embeddedSourceMatch"],
    "storage": "Studio memory mock; published DataStore unverified",
    "salesEnabled": False, "mainMerged": False,
    "logRedaction": ["local user path", "player name and UserId", "URL", "email",
                     "authorization/cookie/token/key values"],
    "files": entries,
}
manifest.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as out:
    for p in files + [manifest]:
        out.write(p, rel(p))
with zipfile.ZipFile(archive) as check:
    expected_paths = {rel(p) for p in files + [manifest]}
    assert set(check.namelist()) == expected_paths
    for name in expected_paths:
        assert hashlib.sha256(check.read(name)).hexdigest() == sha(root / name)
print(json.dumps({"zip": str(archive), "sha256": sha(archive), "files": len(expected_paths),
                  "head": head, "dirty": dirty}, ensure_ascii=False, indent=2))
