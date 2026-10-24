#!/usr/bin/env bash
# Wallpaper-Wechsler mit weichen Uebergaengen.
# Nutzt awww (Nachfolger von swww), sonst swww, sonst swaybg.
#   wallpaper.sh init   -> letztes Wallpaper wiederherstellen (Autostart)
#   wallpaper.sh next   -> zufaelliges neues Wallpaper
#   wallpaper.sh <datei>-> genau dieses Bild setzen

WALLDIR="${WALLDIR:-$HOME/Pictures/Wallpapers}"
STATE="$HOME/.cache/catppuccin-glass-wallpaper"
mkdir -p "$WALLDIR" "$(dirname "$STATE")"

if command -v awww >/dev/null 2>&1; then
    D=awww; DAEMON="awww-daemon"
elif command -v swww >/dev/null 2>&1; then
    D=swww; DAEMON="swww-daemon"
else
    D=swaybg; DAEMON=""
fi

start_daemon() {
    [ -z "$DAEMON" ] && return
    if ! "$D" query >/dev/null 2>&1; then
        "$DAEMON" >/dev/null 2>&1 &
        for _ in $(seq 1 30); do
            "$D" query >/dev/null 2>&1 && break
            sleep 0.1
        done
    fi
}

set_wall() {
    local img="$1"
    [ -f "$img" ] || { notify-send "Wallpaper" "Datei nicht gefunden: $img"; exit 1; }
    if [ "$D" = "swaybg" ]; then
        pkill -x swaybg
        setsid -f swaybg -i "$img" -m fill >/dev/null 2>&1
    else
        start_daemon
        "$D" img "$img" \
            --transition-type grow \
            --transition-pos 0.5,0.5 \
            --transition-duration 1.2 \
            --transition-fps 144
    fi
    echo "$img" > "$STATE"
}

random_wall() {
    find "$WALLDIR" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' -o -iname '*.gif' \) \
        | grep -vxF "$(cat "$STATE" 2>/dev/null)" | shuf -n 1
}

case "$1" in
    init)
        img="$(cat "$STATE" 2>/dev/null)"
        [ -f "$img" ] || img="$(random_wall)"
        [ -n "$img" ] && set_wall "$img"
        ;;
    next|"")
        img="$(random_wall)"
        if [ -z "$img" ]; then
            notify-send "Wallpaper" "Keine Bilder in $WALLDIR"
            exit 1
        fi
        set_wall "$img"
        ;;
    *)
        set_wall "$1"
        ;;
esac
