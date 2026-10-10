"""Copy a Studio log for review while removing local account and auth data."""
from pathlib import Path
import os
import re
import sys

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
raw = source.read_text(encoding="utf-8", errors="replace")
players = set(re.findall(r"Players\.([A-Za-z0-9_]+)\.PlayerScripts", raw))
players |= set(re.findall(r"Players\.([A-Za-z0-9_]+)\.PlayerGui", raw))
ids = set(re.findall(r"(?i)user[_-]?id[\s\"':=]+(\d{5,})", raw))
players |= {value for value in [os.environ.get("REVIEW_REDACT_PLAYER")] if value}
ids |= {value for value in [os.environ.get("REVIEW_REDACT_USER_ID")] if value}
text = re.sub(r"(?i)C:\\Users\\[^\\\s]+", r"C:\Users\<REDACTED_USER>", raw)
text = re.sub(r"(?i)https?://[^\s\"}]+", "<REDACTED_URL>", text)
text = re.sub(
    r"(?i)(authorization|cookie|access[_-]?token|refresh[_-]?token|api[_-]?key|session[_-]?token)(\s*[:=]\s*)([^\s,&]+)",
    r"\1\2<REDACTED>", text,
)
text = re.sub(r"(?i)[\w.+-]+@[\w.-]+\.[a-z]{2,}", "<REDACTED_EMAIL>", text)
for value in sorted(players, key=len, reverse=True):
    text = re.sub(re.escape(value), "<REDACTED_PLAYER>", text, flags=re.IGNORECASE)
for value in sorted(ids, key=len, reverse=True):
    text = re.sub(rf"(?<!\d){re.escape(value)}(?!\d)", "<REDACTED_USER_ID>", text)
text = "\n".join(line.rstrip() for line in text.splitlines()) + "\n"
destination.write_text(text, encoding="utf-8")
print(f"REDACTED_LOG {destination} bytes={destination.stat().st_size}")
