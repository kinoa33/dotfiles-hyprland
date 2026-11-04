#!/usr/bin/env bash
journalctl --list-boots -o json 2>/dev/null | python3 -c '
import sys, json
try:
    boots = json.load(sys.stdin)
    t = sum(b["last_entry"] - b["first_entry"] for b in boots) / 1e6
    print(f"{int(t // 3600)}h {int(t % 3600 // 60)}m")
except Exception:
    print("N/A")
' || echo "N/A"
