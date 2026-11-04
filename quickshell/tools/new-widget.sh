#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  new-widget.sh <Name> <key> [label]                          ║
# ║  makes ~/.config/quickshell/<Name> from tools/widget-template║
# ║  a themed overlay with a theme tab, ready to fill in.        ║
# ║    Name   the config dir (TitleCase, like TodoWidget)        ║
# ║    key    its theme key (lowercase, like todo)               ║
# ╚══════════════════════════════════════════════════════════════╝
here="$(cd "$(dirname "$0")/.." && pwd)"
name="$1" key="$2" label="${3:-$2}"

if [[ -z $name || -z $key ]]; then
    sed -n '2,8p' "$0" | sed 's/^# \?//'
    exit 1
fi
if [[ ! $key =~ ^[a-z][a-z0-9]*$ ]]; then
    echo "key: lowercase letters and digits only (got '$key')" >&2
    exit 1
fi
dir="$here/$name"
if [[ -e $dir ]]; then
    echo "$dir already exists" >&2
    exit 1
fi

mkdir -p "$dir"
ln -s ../common "$dir/common"
sed -e "s/__NAME__/$name/g" -e "s/__KEY__/$key/g" -e "s/__LABEL__/$label/g" \
    "$here/tools/widget-template/shell.qml" >"$dir/shell.qml"

cat <<EOF
made $dir
next:
  1. common/Theme.qml → widgets: add  { key: "$key", label: "$label", glyph: "…" }
     (theme tabs and the theme studio list it; per-widget overrides work)
  2. hypr/conf/keybinds.conf → bind = \$mainMod, <key>, exec, ~/.config/hypr/scripts/qs-toggle.sh $name
  3. hypr/conf/windowrules.conf → add $key to the quickshell-(…) blur layerrules
  4. tools/check.sh $name      (should print ✓)
EOF
