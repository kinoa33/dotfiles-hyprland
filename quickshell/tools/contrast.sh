#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  contrast.sh [widget]                                        ║
# ║  readability audit of every theme (built-in and yours) over  ║
# ║  the test palettes in tools/palettes — dark, light, grey,    ║
# ║  warm, cool. run it after adding or changing a theme.        ║
# ║    widget   audit as that widget wears them (its overrides)  ║
# ╚══════════════════════════════════════════════════════════════╝
here="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

for p in "$here"/tools/palettes/*.json; do
    name="$(basename "$p" .json)"
    QS_WAL_JSON="$p" QS_DUMP_WIDGET="${1:-}" timeout 20 quickshell -p "$here/tools/tokdump" --no-color 2>&1 \
        | grep -o 'TOKENS .*' | sed 's/^TOKENS //' >"$tmp/$name.json"
    if [[ ! -s $tmp/$name.json ]]; then
        echo "tokdump printed nothing for $name — run: QS_WAL_JSON=$p quickshell -p $here/tools/tokdump" >&2
        exit 2
    fi
done
python3 "$here/tools/contrast.py" "$tmp"/*.json
