"""Compare every Rojo-embedded script against the current src tree."""
from pathlib import Path
import hashlib
import json
import sys
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
build = Path(sys.argv[1]) if len(sys.argv) > 1 else root / "build/IdleRaid-review-stabilized.rbxlx"
if not build.is_absolute():
    build = root / build
prefixes = {
    "ReplicatedStorage/Shared/": "src/shared/",
    "ServerScriptService/Server/": "src/server/",
    "StarterPlayer/StarterPlayerScripts/Client/": "src/client/",
}
suffixes = {"Script": ".server.luau", "LocalScript": ".client.luau", "ModuleScript": ".luau"}
seen = []

def walk(item, parent=""):
    props = item.find("Properties")
    name_el = None if props is None else props.find("./string[@name='Name']")
    name = name_el.text if name_el is not None else item.get("class", "?")
    logical = f"{parent}/{name}".strip("/")
    kind = item.get("class")
    if kind in suffixes:
        mapped = next((base + logical[len(prefix):] + suffixes[kind]
                       for prefix, base in prefixes.items() if logical.startswith(prefix)), None)
        source_el = None if props is None else props.find(".//*[@name='Source']")
        embedded = "" if source_el is None else source_el.text or ""
        disk = (root / mapped).read_text(encoding="utf-8") if mapped and (root / mapped).exists() else None
        normalize = lambda value: value.replace("\r\n", "\n").strip("\n")
        seen.append((mapped, disk is not None and normalize(disk) == normalize(embedded)))
    for child in item.findall("Item"):
        walk(child, logical)

for item in ET.parse(build).getroot().findall("Item"):
    walk(item)
source_files = sorted((root / "src").rglob("*.luau"))
digest = hashlib.sha256()
for file in source_files:
    relative = file.relative_to(root).as_posix()
    digest.update(relative.encode("utf-8") + b"\0" + file.read_bytes())
result = {
    "build": str(build),
    "buildSha256": hashlib.sha256(build.read_bytes()).hexdigest(),
    "sourceFiles": len(source_files),
    "sourceInputSha256": digest.hexdigest(),
    "embeddedScripts": len(seen),
    "matchingScripts": sum(ok for _, ok in seen),
    "mismatches": [path for path, ok in seen if not ok],
}
print(json.dumps(result, ensure_ascii=False, indent=2))
if result["embeddedScripts"] != len(source_files) or result["mismatches"]:
    raise SystemExit(1)
