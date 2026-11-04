#!/usr/bin/env python3
"""gen-emoji.py — writes Launcher/emoji.tsv for the launcher's ":" emoji search.

one line per emoji: <char>\t<name, lowercase>. names come from python's
unicodedata, so re-run this after a python update to pick up new emoji:
    tools/gen-emoji.py > Launcher/emoji.tsv
"""
import unicodedata

RANGES = [
    (0x1F600, 0x1F64F),  # faces first: they're what people look for
    (0x1F90C, 0x1F9FF),
    (0x1F300, 0x1F5FF),
    (0x1F680, 0x1F6FF),
    (0x1FA70, 0x1FAFF),
    (0x2600, 0x26FF),
    (0x2700, 0x27BF),
]

for lo, hi in RANGES:
    for cp in range(lo, hi + 1):
        name = unicodedata.name(chr(cp), "")
        if name:
            print(f"{chr(cp)}\t{name.lower()}")
