#!/usr/bin/env bash
# claudes-glassy: Flyouts der Leiste auf-/zuklappen
#   panel.sh [quick|sound|network|bluetooth|calendar]   (Standard: quick)
#   panel.sh --start-daemon                              (Autostart, versteckt vorladen)
source "$HOME/.config/hypr/scripts/lib.sh"
PY="$HOME/.config/hypr/panel/panel.py"
CACHE="$HOME/.cache/claudes-glassy"
FIFO="$CACHE/panel.fifo"
LOG="$CACHE/panel.log"
mkdir -p "$CACHE"

running() { pgrep -f "panel/panel.py.*--daemon" >/dev/null 2>&1; }
layer_lib() {
    for lib in /usr/lib/libgtk4-layer-shell.so /usr/lib/libgtk4-layer-shell.so.0 /usr/lib64/libgtk4-layer-shell.so; do
        [ -f "$lib" ] && { echo "$lib"; return; }
    done
}

if [ "$1" = "--start-daemon" ]; then
    running && exit 0
    LD_PRELOAD="$(layer_lib)" setsid -f python3 "$PY" --daemon >"$LOG" 2>&1
    exit 0
fi

page="${1:-quick}"
pkill -x rofi 2>/dev/null
mon="$(glassy_cursor_monitor)"

if running && [ -p "$FIFO" ]; then
    timeout 0.5 bash -c 'printf "toggle %s %s\n" "$1" "$2" > "$3"' _ "$page" "$mon" "$FIFO" && exit 0
fi

pkill -f "panel/panel.py" 2>/dev/null
LD_PRELOAD="$(layer_lib)" setsid -f python3 "$PY" "$page" --daemon --show ${mon:+--monitor "$mon"} >"$LOG" 2>&1
sleep 1.5
running || notify-send -a claudes-glassy "Panel konnte nicht starten" "Details: $LOG" 2>/dev/null
