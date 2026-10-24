#!/usr/bin/env bash
# claudes-glassy: Zwischenablage auf-/zuklappen (SUPER+V)
# Laeuft als Dienst (startet mit Hyprland) -> oeffnet sofort.
#   clipboard.sh                 -> auf/zu
#   clipboard.sh --start-daemon  -> nur Dienst im Hintergrund starten (Autostart)
# Faellt auf das Rofi-Menue zurueck, wenn GTK4/PyGObject fehlen.

source "$HOME/.config/hypr/scripts/lib.sh"
PY="$HOME/.config/hypr/clipboard/clipman.py"
CACHE="$HOME/.cache/claudes-glassy"
FIFO="$CACHE/clipboard.fifo"
LOG="$CACHE/clipboard.log"
mkdir -p "$CACHE"

command -v cliphist >/dev/null 2>&1 || { notify-send "Zwischenablage" "cliphist fehlt:  sudo pacman -S cliphist"; exit 1; }

running() { pgrep -f "clipman.py --daemon" >/dev/null 2>&1; }
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

pkill -x rofi 2>/dev/null
mon="$(glassy_cursor_monitor)"

if running && [ -p "$FIFO" ]; then
    timeout 0.5 bash -c 'printf "toggle %s\n" "$1" > "$2"' _ "$mon" "$FIFO" && exit 0
fi

pkill -f "clipman.py --daemon" 2>/dev/null
LD_PRELOAD="$(layer_lib)" setsid -f python3 "$PY" --daemon --show ${mon:+--monitor "$mon"} >"$LOG" 2>&1
sleep 1.5
if ! running; then
    notify-send -a Zwischenablage "Zwischenablage konnte nicht starten" "Details: $LOG  -  nutze Rofi-Version" 2>/dev/null
    exec "$HOME/.config/hypr/scripts/clipboard-rofi.sh"
fi
