#!/usr/bin/env bash
# claudes-glassy: Startmenue auf-/zuklappen (Super antippen / Start-Knopf in der Bar)
# Das Menue laeuft als Hintergrund-Dienst (startet mit Hyprland), dadurch oeffnet
# es sofort. Dieses Script schickt nur "toggle <Monitor>" an den Dienst.
# Laeuft der Dienst nicht, wird er gestartet; geht GTK gar nicht -> Rofi-Menue.

source "$HOME/.config/hypr/scripts/lib.sh"
PY="$HOME/.config/hypr/startmenu/startmenu.py"
CACHE="$HOME/.cache/claudes-glassy"
FIFO="$CACHE/startmenu.fifo"
LOG="$CACHE/startmenu.log"
mkdir -p "$CACHE"

running() { pgrep -f "startmenu.py --daemon" >/dev/null 2>&1; }

layer_lib() {
    for lib in /usr/lib/libgtk4-layer-shell.so /usr/lib/libgtk4-layer-shell.so.0 /usr/lib64/libgtk4-layer-shell.so; do
        [ -f "$lib" ] && { echo "$lib"; return; }
    done
}

# Autostart: Dienst nur im Hintergrund starten (versteckt)
if [ "$1" = "--start-daemon" ]; then
    running && exit 0
    LD_PRELOAD="$(layer_lib)" setsid -f python3 "$PY" --daemon >"$LOG" 2>&1
    exit 0
fi

pkill -x rofi 2>/dev/null
mon="$(glassy_cursor_monitor)"

# Schneller Weg: Dienst laeuft schon
if running && [ -p "$FIFO" ]; then
    timeout 0.5 bash -c 'printf "toggle %s\n" "$1" > "$2"' _ "$mon" "$FIFO" && exit 0
fi

# Dienst (neu) starten und direkt anzeigen
pkill -f "startmenu.py --daemon" 2>/dev/null
LD_PRELOAD="$(layer_lib)" setsid -f python3 "$PY" --daemon --show ${mon:+--monitor "$mon"} >"$LOG" 2>&1

# Faellt der Dienst sofort um (kein GTK4/PyGObject), Rofi-Menue nehmen
sleep 1.5
if ! running; then
    notify-send -a Startmenue "Startmenue konnte nicht starten" "Details: $LOG  -  nutze Rofi-Menue" 2>/dev/null
    exec "$HOME/.config/hypr/scripts/startmenu-rofi.sh"
fi
