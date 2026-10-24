#!/usr/bin/env bash
# claudes-glassy: Wallpaper
#   wallpaper.sh init    -> letztes Wallpaper wiederherstellen (Autostart)
#   wallpaper.sh next    -> zufaelliges anderes Wallpaper      (SUPER+SHIFT+W)
#   wallpaper.sh pick    -> Auswahl mit Vorschaubildern        (SUPER+W)
#   wallpaper.sh <datei> -> genau dieses Bild setzen
#
# Bilder:  ~/Pictures/Wallpapers  (Unterordner gehen auch)
# Backend: awww (mit Uebergaengen) -> swww -> swaybg (ohne Uebergaenge)
# Der Sperrbildschirm nutzt automatisch das aktuelle Wallpaper.

source "$HOME/.config/hypr/scripts/lib.sh" 2>/dev/null
WALLDIR="${WALLDIR:-$HOME/Pictures/Wallpapers}"
CACHE="$HOME/.cache/claudes-glassy"
STATE="$CACHE/wallpaper-path"
LINK="$CACHE/wallpaper"          # -> fuer hyprlock
mkdir -p "$WALLDIR" "$CACHE"

notify() { command -v notify-send >/dev/null 2>&1 && notify-send -a Wallpaper "$@"; }

list_walls() {
    find -L "$WALLDIR" -maxdepth 2 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
        2>/dev/null | sort
}

backend() {
    if command -v awww >/dev/null 2>&1; then echo awww
    elif command -v swww >/dev/null 2>&1; then echo swww
    else echo swaybg
    fi
}

ensure_daemon() {   # $1 = awww|swww
    local d="$1"
    "$d" query >/dev/null 2>&1 && return 0
    setsid -f "${d}-daemon" >/dev/null 2>&1
    for _ in $(seq 1 50); do
        "$d" query >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    return 1
}

set_wall() {
    local img="$1" b
    [ -f "$img" ] || { notify "Datei nicht gefunden" "$img"; exit 1; }
    img="$(realpath "$img")"
    b="$(backend)"

    if [ "$b" != swaybg ] && ensure_daemon "$b"; then
        pkill -x swaybg 2>/dev/null
        "$b" img "$img" \
            --transition-type grow \
            --transition-pos center \
            --transition-duration 1.4 \
            --transition-fps 144 \
            --transition-bezier .43,1.19,1,.4 >/dev/null 2>&1 \
        || "$b" img "$img" >/dev/null 2>&1
    else
        pkill -x swaybg 2>/dev/null
        setsid -f swaybg -i "$img" -m fill >/dev/null 2>&1
    fi

    echo "$img" > "$STATE"
    ln -sfn "$img" "$LINK"
}

random_wall() {
    local cur; cur="$(cat "$STATE" 2>/dev/null)"
    list_walls | grep -vxF "${cur:-/nonexistent}" | shuf -n 1
}

pick_wall() {
    pkill -x rofi && exit 0
    local walls sel
    walls="$(list_walls)"
    [ -z "$walls" ] && { notify "Keine Bilder" "Leg Bilder nach $WALLDIR"; exit 1; }
    sel="$(while IFS= read -r f; do
              printf '%s\0icon\x1f%s\n' "$(basename "$f")" "$f"
           done <<< "$walls" | glassy_rofi -dmenu -i -p "Wallpaper" -show-icons -format i \
              -theme-str '
                window   { width: 1100px; }
                listview { columns: 4; lines: 2; spacing: 14px; flow: horizontal; }
                element  { orientation: vertical; padding: 10px; spacing: 8px; border-radius: 16px; }
                element-icon { size: 200px; border-radius: 12px; }
                element-text { horizontal-align: 0.5; }
                inputbar { children: [prompt, entry]; }')" || exit 0
    set_wall "$(sed -n "$((sel + 1))p" <<< "$walls")"
}

case "${1:-next}" in
    init)
        img="$(cat "$STATE" 2>/dev/null)"
        [ -f "$img" ] || img="$(list_walls | head -n 1)"
        if [ -n "$img" ]; then set_wall "$img"; else notify "Keine Bilder" "Leg Bilder nach $WALLDIR"; fi
        ;;
    next)
        img="$(random_wall)"
        [ -z "$img" ] && img="$(list_walls | head -n 1)"
        [ -z "$img" ] && { notify "Keine Bilder" "Leg Bilder nach $WALLDIR"; exit 1; }
        set_wall "$img"
        notify "Wallpaper" "$(basename "$img")"
        ;;
    pick) pick_wall ;;
    *)    set_wall "$1" ;;
esac
