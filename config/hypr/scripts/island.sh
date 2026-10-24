#!/usr/bin/env bash
# claudes-glassy: Dynamic Island starten / neu starten
#   island.sh           -> starten (laeuft schon = nichts tun)
#   island.sh restart   -> neu starten
PY="$HOME/.config/hypr/island/island.py"
LOG="$HOME/.cache/claudes-glassy/island.log"
mkdir -p "$(dirname "$LOG")"

running() { pgrep -f "island/island.py" >/dev/null 2>&1; }

# In den Einstellungen (SUPER+I) ausgeschaltet?
if [ -f "$HOME/.config/hypr/island/settings.json" ] && grep -q '"enabled": false' "$HOME/.config/hypr/island/settings.json"; then
    pkill -f "island/island.py"; exit 0
fi

if [ "$1" = "restart" ]; then
    pkill -f "island/island.py"
    sleep 0.3
elif running; then
    exit 0
fi

pre=""
for lib in /usr/lib/libgtk4-layer-shell.so /usr/lib/libgtk4-layer-shell.so.0 /usr/lib64/libgtk4-layer-shell.so; do
    [ -f "$lib" ] && { pre="$lib"; break; }
done
if [ -z "$pre" ]; then
    notify-send -a Island "Dynamic Island" "gtk4-layer-shell fehlt:  sudo pacman -S gtk4-layer-shell" 2>/dev/null
    exit 1
fi
LD_PRELOAD="$pre" setsid -f python3 "$PY" >"$LOG" 2>&1
