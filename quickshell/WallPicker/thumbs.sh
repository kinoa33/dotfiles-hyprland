#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  wallpicker · wallpaper index + thumbnail cache              ║
# ║    thumbs.sh list   CUR line, then one IMG line per image    ║
# ║    thumbs.sh make   stdin: src<TAB>thumb per line — makes    ║
# ║                     the missing ones, 4 at a time, printing  ║
# ║                     DONE<TAB>src<TAB>WxH as each lands       ║
# ║    thumbs.sh pal    stdin: one thumb per line — reads each   ║
# ║                     one's main colours (for the colour       ║
# ║                     filter), printing PAL<TAB>thumb<TAB>list ║
# ╚══════════════════════════════════════════════════════════════╝
# thumbs live in ~/.cache/wallpicker/thumbs, keyed by path+mtime+size,
# so an edited file gets a fresh thumb and the originals are never touched.
# IMG<TAB>mtime<TAB>path<TAB>thumb<TAB>WxH (empty until made)<TAB>group<TAB>palette
# palette: count#rrggbb,… — six colours with their pixel counts (empty until read)

cache="$HOME/.cache/wallpicker/thumbs"
cfg="$(dirname "$0")/folders.conf"
mkdir -p "$cache"

folders() {
    if [[ -f $cfg ]]; then
        grep -vE '^[[:space:]]*(#|$)' "$cfg" | sed "s|^~|$HOME|"
    else
        printf '%s\n' "$HOME/Pictures" "$HOME/Downloads"
    fi
}

# what's on screen: whichever of "set by the picker" / "riced by walrs"
# happened last — a riced crop maps back to its source via the picker's note
current() {
    local note="$HOME/.cache/wallpicker/current" wal="$HOME/.cache/wal/wal"
    if [[ -f $note && ( ! -f $wal || $note -nt $wal ) ]]; then
        cat "$note"
    elif [[ -f $wal ]]; then
        local w; w=$(cat "$wal")
        [[ $w == "$HOME/.cache/wallpicker/"* && -f $note ]] && cat "$note" || printf '%s' "$w"
    fi
}

case "$1" in
list)
    printf 'CUR\t%s\n' "$(current)"
    folders | while IFS= read -r root; do
        root=${root%/}
        [[ -d $root ]] || continue
        find -L "$root" -maxdepth 4 -type f \
            \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
            -size +100k -printf '%T@\t%s\t%p\n' 2>/dev/null |
        while IFS=$'\t' read -r mt sz p; do
            k=$(printf '%s' "$p:$mt:$sz" | md5sum | cut -c1-20)
            dims="" pal=""
            [[ -s $cache/$k.jpg && -f $cache/$k.dim ]] && dims=$(<"$cache/$k.dim")
            [[ -s $cache/$k.pal ]] && pal=$(<"$cache/$k.pal")
            rel=${p#"$root"/}
            group=${rel%%/*}
            [[ $group == "$rel" ]] && group=""
            printf 'IMG\t%s\t%s\t%s\t%s\t%s\t%s\n' "$mt" "$p" "$cache/$k.jpg" "$dims" "$group" "$pal"
        done
    done | sort -t$'\t' -k2,2 -rn | awk -F'\t' '!seen[$3]++'
    ;;
make)
    gen() {
        local src=$1 out=$2 dims
        # oriented size: a 90°-rotated photo shows (and crops) the other way round
        read -r orient w h < <(magick identify -format '%[orientation] %w %h' "$src[0]" 2>/dev/null)
        case $orient in LeftTop|RightTop|RightBottom|LeftBottom) dims="${h}x${w}" ;; *) dims="${w}x${h}" ;; esac
        [[ $dims == x ]] && dims=""
        if [[ ! -s $out ]]; then
            magick -define jpeg:size=960x640 "$src[0]" -auto-orient \
                -thumbnail '480x320^' -gravity center -extent 480x320 \
                -strip -quality 82 "$out.part.jpg" 2>/dev/null && mv -f "$out.part.jpg" "$out"
        fi
        printf '%s' "$dims" >"${out%.jpg}.dim"
        [[ -s $out ]] && printf 'DONE\t%s\t%s\n' "$src" "$dims"
    }
    export -f gen
    tr '\t' '\n' | xargs -d '\n' -r -n 2 -P 4 bash -c 'gen "$1" "$2"' _
    ;;
pal)
    palette() {
        local t=$1 out=${1%.jpg}.pal
        if [[ ! -s $out ]]; then
            magick "$t" -resize 64x64 -colors 6 -format '%c' histogram:info: 2>/dev/null |
                sed -nE 's/^ *([0-9]+):.*(#[0-9A-Fa-f]{6}).*/\1\2/p' | paste -sd, >"$out.part"
            if [[ -s $out.part ]]; then mv -f "$out.part" "$out"; else rm -f "$out.part"; fi
        fi
        [[ -s $out ]] && printf 'PAL\t%s\t%s\n' "$t" "$(<"$out")"
    }
    export -f palette
    xargs -d '\n' -r -n 1 -P 4 bash -c 'palette "$1"' _
    ;;
esac
