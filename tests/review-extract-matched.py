"""Extract only measured timing markers from redacted Studio virtual-input logs."""
from pathlib import Path
import csv
import re

root = Path(__file__).resolve().parents[1]
logs = root / "docs" / "test-logs"
rows = []
scenario_map = {"free": "Free", "ticket5": "Ticket5", "voucher10": "Voucher10"}
for scenario in ("free", "ticket5", "voucher10"):
    path = logs / f"review-matched-{scenario}.studio.log"
    rerun = logs / f"review-matched-{scenario}-rerun.studio.log"
    if rerun.exists() and f"IR_MATCH_SERVER_RESULT {scenario_map[scenario]} true" in rerun.read_text(encoding="utf-8", errors="replace"):
        path = rerun
    record = {"scenario": scenario, "log": str(path.relative_to(root)).replace("\\", "/"),
              "status": "NOT_RUN" if not path.exists() else "INCOMPLETE",
              "use_stage": "", "use_time_s": "", "gate_reached_s": "",
              "raid_click_s": "", "entry_wait_s": "", "boss_fight_s": "", "clear_s": "",
              "initial_stage": "", "initial_gold": "", "initial_facility": "",
              "initial_attack": "", "initial_inventory_count": "",
              "initial_ticket5": "", "initial_voucher10": ""}
    if path.exists():
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            if "IR_MATCH_INITIAL " in line:
                fields = line.split("IR_MATCH_INITIAL ", 1)[1].split()
                if len(fields) >= 8:
                    for key, value in zip(("initial_stage", "initial_gold", "initial_facility",
                                           "initial_attack", "initial_inventory_count",
                                           "initial_ticket5", "initial_voucher10"), fields[1:8]):
                        record[key] = value
            if "IR_MATCH_ENTITLEMENT_USED " in line:
                fields = line.split("IR_MATCH_ENTITLEMENT_USED ", 1)[1].split()
                if len(fields) >= 3:
                    record["use_stage"], record["use_time_s"] = fields[1:3]
            for marker, key in (("GATE_REACHED", "gate_reached_s"), ("RAID_CLICK", "raid_click_s"),
                                ("RAID_ACTIVE", "raid_active_s"), ("GATE_CLEAR", "clear_s")):
                if f"IR_MATCH_{marker} " in line:
                    fields = line.split(f"IR_MATCH_{marker} ", 1)[1].split()
                    if len(fields) >= 2:
                        record[key] = fields[1]
            if "IR_MATCH_SERVER_RESULT " in line:
                fields = line.split("IR_MATCH_SERVER_RESULT ", 1)[1].split()
                if len(fields) >= 2:
                    record["status"] = "PASS" if fields[1] == "true" else "FAIL"
        if record.get("raid_active_s") and record["raid_click_s"]:
            record["entry_wait_s"] = f'{float(record["raid_active_s"]) - float(record["raid_click_s"]):.3f}'
        if record["clear_s"] and record.get("raid_active_s"):
            record["boss_fight_s"] = f'{float(record["clear_s"]) - float(record["raid_active_s"]):.3f}'
    record.pop("raid_active_s", None)
    rows.append(record)
out = root / "docs" / "review-matched-play.csv"
with out.open("w", encoding="utf-8", newline="") as handle:
    writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)
print(out)
for row in rows:
    print(row)
