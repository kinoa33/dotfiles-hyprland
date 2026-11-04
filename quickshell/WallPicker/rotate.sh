#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  wallpicker · rotation                                       ║
# ║    rotate.sh start <minutes> <listfile> [rice|wall]          ║
# ║    rotate.sh stop | status | next                            ║
# ╚══════════════════════════════════════════════════════════════╝
# a tiny background loop: every <minutes> it picks a random wallpaper
# from <listfile> (one path per line — the picker writes it) and rices
# it (or sets the wallpaper only). it outlives the picker; it does not
# survive a logout. status prints "<minutes> <mode> <source-count>" or "off".

run="${XDG_RUNTIME_DIR:-/tmp}/wallpicker-rotate"
pidf="$run/pid" conf="$run/conf" list="$run/list"
mkdir -p "$run"

alive() { [[ -f $pidf ]] && kill -0 "$(cat "$pidf")" 2>/dev/null; }

pick() {
    local cur; cur=$(cat "$HOME/.cache/wallpicker/current" 2>/dev/null)
    grep -v -x -F -- "$cur" "$list" | grep . | shuf -n 1 || shuf -n 1 "$list"
}

apply() {
    local p; p=$(pick)
    [[ -n $p && -f $p ]] || return 0
    printf '%s' "$p" >"$HOME/.cache/wallpicker/current"
    if [[ $(cut -d' ' -f2 "$conf" 2>/dev/null) == wall ]]; then
        awww img "$p" --transition-type grow --transition-duration 1.2
    else
        "$HOME/.config/hypr/scripts/rice-apply.sh" "$p" >/dev/null
    fi
}

case "$1" in
start)
    "$0" stop
    min=${2:-30}; mode=${4:-rice}
    cp -f "$3" "$list" || exit 1
    printf '%s %s\n' "$min" "$mode" >"$conf"
    setsid bash -c '
        while sleep "$(( $1 * 60 ))"; do "$0" next; done
    ' "$0" "$min" </dev/null >/dev/null 2>&1 &
    echo $! >"$pidf"
    ;;
stop)
    alive && kill "$(cat "$pidf")" 2>/dev/null
    rm -f "$pidf"
    ;;
next)
    apply
    ;;
status | *)
    if alive; then
        printf '%s %s\n' "$(cat "$conf")" "$(grep -c . "$list")"
    else
        echo off
    fi
    ;;
esac
