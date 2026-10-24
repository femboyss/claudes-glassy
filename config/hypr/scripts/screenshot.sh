#!/usr/bin/env bash
# claudes-glassy: Screenshot -> Zwischenablage + Datei in ~/Pictures/Screenshots
#   screenshot.sh area      -> Bereich auswaehlen        (Print, SUPER+SHIFT+S, Strg+Alt+Entf)
#   screenshot.sh full      -> Monitor unter der Maus    (SHIFT+Print)
#   screenshot.sh delay 5   -> Monitor nach 5 Sekunden   (Strg+Alt+Entf: "Screenshot in 5 s")
# Fehler landen in ~/.cache/claudes-glassy/screenshot.log und als Benachrichtigung.

source "$HOME/.config/hypr/scripts/lib.sh" 2>/dev/null

DIR="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"
[ "$DIR" = "/Screenshots" ] && DIR="$HOME/Pictures/Screenshots"
LOG="$HOME/.cache/claudes-glassy/screenshot.log"
mkdir -p "$DIR" "$(dirname "$LOG")"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

notify() { command -v notify-send >/dev/null 2>&1 && notify-send -a Screenshot "$@"; }
fail()   { echo "$(date '+%F %T') $*" >> "$LOG"; notify -u critical "Screenshot fehlgeschlagen" "$*"; exit 1; }

for bin in grim wl-copy; do
    command -v "$bin" >/dev/null 2>&1 || fail "$bin fehlt - installieren:  sudo pacman -S grim slurp wl-clipboard"
done

# Menues (Rofi, Startmenue) erst verschwinden lassen, sonst sind sie mit drauf
if pgrep -x rofi >/dev/null || pgrep -f startmenu.py >/dev/null; then
    pkill -x rofi 2>/dev/null
    sleep 0.4
else
    sleep 0.15
fi

current_monitor() {
    local m
    m="$(glassy_cursor_monitor 2>/dev/null)"
    [ -z "$m" ] && m="$(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null)"
    echo "$m"
}

shoot_monitor() {
    local mon; mon="$(current_monitor)"
    if [ -n "$mon" ]; then
        grim -o "$mon" "$FILE" 2>>"$LOG" || fail "grim konnte Monitor $mon nicht aufnehmen (siehe $LOG)"
    else
        grim "$FILE" 2>>"$LOG" || fail "grim konnte nicht aufnehmen (siehe $LOG)"
    fi
}

case "${1:-area}" in
    full)
        shoot_monitor
        ;;
    delay)
        n="${2:-5}"
        notify -t 1500 "Screenshot in $n Sekunden" "Mach jetzt auf, was drauf soll."
        sleep "$n"
        shoot_monitor
        ;;
    area|*)
        command -v slurp >/dev/null 2>&1 || fail "slurp fehlt - installieren:  sudo pacman -S slurp"
        GEOM="$(slurp -b 1a1b2688 -c 7aa2f7ff -s 7aa2f722 -w 2 -d 2>>"$LOG")" || exit 0   # Esc = abbrechen
        grim -g "$GEOM" "$FILE" 2>>"$LOG" || fail "grim konnte den Bereich nicht aufnehmen (siehe $LOG)"
        ;;
esac

wl-copy --type image/png < "$FILE" 2>>"$LOG"
notify -i "$FILE" "Screenshot gespeichert" "In der Zwischenablage und in\n$FILE"
