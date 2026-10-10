"""Write an auditable manifest for the UI-fix Rojo build and its Studio logs."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
build_rel = "build/IdleRaid-review-ui-fixed.rbxlx"
manifest_rel = "docs/review-ui-fixed-manifest.json"
def sha(relative):
    return hashlib.sha256((root / relative).read_bytes()).hexdigest()
def git(*args):
    return subprocess.check_output(["git", *args], cwd=root, text=True).strip()

verified = json.loads(subprocess.check_output(
    [sys.executable, str(root / "tests/review-build-source.py"), build_rel],
    cwd=root, text=True))
assert verified["embeddedScripts"] == verified["matchingScripts"] == verified["sourceFiles"] == 43
source_commit = git("log", "-1", "--format=%H", "--", "src/client/ui/InventoryController.luau")
build_commit = git("log", "-1", "--format=%H", "--", build_rel)
assert source_commit == build_commit, "source and build are from different commits"
logs = sorted((root / "docs/test-logs").glob("review-ui-fixed-*.studio.log"))
log_hashes = {p.relative_to(root).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in logs}
legacy = [
    "docs/test-logs/review-final-ui-full.studio.log",
    "docs/test-logs/review-ui-click-run10.studio.log",
    "docs/test-logs/review-ui-click-race-run03.studio.log",
    "docs/test-logs/review-ui-click-race-run04.studio.log",
]
for path in legacy:
    assert (root / path).exists()
for path in (
    "docs/test-logs/review-ui-fixed-race-run06.studio.log",
    "docs/test-logs/review-ui-fixed-race-run07.studio.log",
    "docs/test-logs/review-ui-fixed-lifecycle-run02.studio.log",
    "docs/test-logs/review-ui-fixed-gate10-free.studio.log",
    "docs/test-logs/review-ui-fixed-gate10-ticket5.studio.log",
    "docs/test-logs/review-ui-fixed-gate10-voucher10.studio.log",
):
    log = (root / path).read_text(encoding="utf-8", errors="replace")
    marker = "IR_MATCH_SERVER_RESULT" if "gate10" in path else (
        "IR_UI_LIFECYCLE_RESULT true" if "lifecycle" in path else "IR_UI_FIXED_RESULT true")
    assert marker in log, (path, marker)
    if "gate10" in path:
        assert "IR_MATCH_GATE_CLEAR" in log and " true nil 10" in log, path
assert "MonetizationEnabled = false" in (root / "src/shared/GrowthConfig.luau").read_text(encoding="utf-8")
assert (root / "src/shared/GrowthConfig.luau").read_text(encoding="utf-8").count("ProductId = nil") == 6

status = []
for line in git("status", "--short").splitlines():
    if "docs/review-ui-fixed-" in line or line.endswith("tests/generate-review-ui-fixed-manifest.py"):
        continue
    status.append(line)
result = {
    "name": "IdleRaid Inventory UI race stabilization",
    "generatedAtUtc": datetime.now(timezone.utc).isoformat(),
    "branch": git("branch", "--show-current"),
    "sourceCommit": source_commit,
    "buildCommit": build_commit,
    "build": build_rel,
    "buildSha256": verified["buildSha256"],
    "sourceInputSha256": verified["sourceInputSha256"],
    "sourceInputHashAlgorithm": verified["sourceInputHashAlgorithm"],
    "sourceFiles": verified["sourceFiles"],
    "embeddedScripts": verified["embeddedScripts"],
    "matchingScripts": verified["matchingScripts"],
    "sourceFileSha256": verified["sourceFileSha256"],
    "tools": {"Rojo": "7.7.1", "RobloxStudio": "0.742.0"},
    "storageMode": "Roblox Studio isolated in-memory mock profiles; published DataStore untested",
    "salesEnabled": False,
    "productIdsConfigured": False,
    "mainMerged": False,
    "originalPlaceIncluded": False,
    "originalPlaceSha256": sha("IdleRaid.rbxl"),
    "comparisonCsv": "docs/review-ui-fixed-matched.csv",
    "comparisonCsvSha256": sha("docs/review-ui-fixed-matched.csv"),
    "checks": "docs/review-ui-fixed-checks.md",
    "checksSha256": sha("docs/review-ui-fixed-checks.md"),
    "report": "docs/review-ui-fixed-report.md",
    "reportSha256": sha("docs/review-ui-fixed-report.md"),
    "logsSha256": log_hashes,
    "legacyFailureLogsSha256": {path: sha(path) for path in legacy},
    "testSourceVersions": "Current tests/review-ui-fixed-race.luau reproduces run06/07; run01-05 used intermediate unpreserved instrumentation variants. All result logs are retained.",
    "screenshots": {"pc": None, "narrow": None, "status": "not captured in this UI-fix run"},
    "redaction": ["local paths", "player names and UserIds", "URLs", "email", "authorization, cookie, token and key values"],
    "preexistingUncommittedChanges": status,
}
(root / manifest_rel).write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(manifest_rel, result["buildSha256"], result["sourceInputSha256"], len(log_hashes))
