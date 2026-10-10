"""Check all local Markdown evidence links in the review documents."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
documents = (
    "docs/oneshot-checks.md",
    "docs/review-stabilized-checks.md",
    "docs/review-ui-click-diagnostic.md",
    "docs/review-matched-play.md",
    "docs/review-stabilized-verification.md",
    "docs/review-equal-compare.md",
)
missing = []
for name in documents:
    path = root / name
    links = re.findall(r"\]\(([^)]+)\)", path.read_text(encoding="utf-8"))
    for link in links:
        target = link.split("#", 1)[0]
        if not target or "://" in target:
            continue
        if not (path.parent / target).exists():
            missing.append((name, link))
print("REVIEW_LINKS", "PASS" if not missing else "FAIL", "documents", len(documents),
      "missing", len(missing))
for pair in missing:
    print(pair[0], pair[1])
raise SystemExit(1 if missing else 0)
