#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  check.sh [Widget …]  — the smoke test                       ║
# ║  starts each widget for a few seconds in a sandbox (its own  ║
# ║  state, theme, draft, export and todo files: nothing real    ║
# ║  changes, waybar and dunst are left alone) and prints every  ║
# ║  qml warning or error it logged. windows flash up briefly.   ║
# ║    tools/check.sh                    every widget            ║
# ║    tools/check.sh TodoWidget         just that one           ║
# ╚══════════════════════════════════════════════════════════════╝
here="$(cd "$(dirname "$0")/.." && pwd)"
widgets=("$@")
[[ ${#widgets[@]} -eq 0 ]] && widgets=(Launcher TodoWidget ControlCenter WallPicker ThemeStudio)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/state" "$tmp/export" "$tmp/data"
# a private XDG_DATA_HOME keeps the todo database (LocalStorage) out of
# reach; icons, apps and fonts are linked in so lookups still work
for d in icons applications fonts; do
    [[ -e ${XDG_DATA_HOME:-$HOME/.local/share}/$d ]] && ln -s "${XDG_DATA_HOME:-$HOME/.local/share}/$d" "$tmp/data/$d"
done
cp "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell-theme.json" "$tmp/state/" 2>/dev/null
cp "$HOME/.config/quickshell/user-themes.json" "$tmp/user-themes.json" 2>/dev/null

bad=0
for w in "${widgets[@]}"; do
    if [[ ! -f $here/$w/shell.qml ]]; then
        echo "✗ $w: no $here/$w/shell.qml"
        bad=1
        continue
    fi
    log="$tmp/$w.log"
    XDG_STATE_HOME="$tmp/state" XDG_DATA_HOME="$tmp/data" QS_EXPORT_DIR="$tmp/export" QS_EXPORT_POKE="$tmp/export/poke.css" \
    QS_USER_THEMES="$tmp/user-themes.json" QS_THEME_DRAFT="$tmp/draft.json" \
        timeout 5 quickshell -p "$here/$w" --no-color >"$log" 2>&1
    issues="$(grep -E '(WARN|ERROR)' "$log" | grep -v 'Configuration Loaded')"
    if [[ -n $issues ]]; then
        echo "✗ $w"
        sed 's/^/    /' <<<"$issues" | sort | uniq -c | sort -rn | head -20
        bad=1
    else
        echo "✓ $w"
    fi
done
exit $bad
