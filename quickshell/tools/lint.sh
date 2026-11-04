#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  lint.sh [file.qml …]  — qmllint every widget's qml          ║
# ║  (or just the files given). quickshell-specific noise is     ║
# ║  switched off in ../.qmllint.ini; what's left is worth a     ║
# ║  look: layout misuse, missing properties, type coercion …    ║
# ╚══════════════════════════════════════════════════════════════╝
here="$(cd "$(dirname "$0")/.." && pwd)"
cd "$here" || exit 1
qmllint=/usr/lib/qt6/bin/qmllint

files=("$@")
if [[ ${#files[@]} -eq 0 ]]; then
    # widget dirs hold a `common` symlink: find doesn't follow it, so each file is linted once
    mapfile -t files < <(find common Launcher TodoWidget ControlCenter WallPicker ThemeStudio tools \
                              -name '*.qml' -type f | sort)
fi

bad=0
for f in "${files[@]}"; do
    out="$("$qmllint" -I /usr/lib/qt6/qml "$f" 2>&1)"
    if [[ -n $out ]]; then
        echo "── $f"
        echo "$out"
        bad=1
    fi
done
[[ $bad -eq 0 ]] && echo "✓ ${#files[@]} files, nothing to report"
exit $bad
