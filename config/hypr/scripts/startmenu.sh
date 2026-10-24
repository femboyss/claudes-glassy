#!/usr/bin/env bash
# claudes-glassy: Startmenue starten (Super antippen / Start-Knopf in der Bar)
# GTK4-Startmenue im Tokyo-Night-Look; nochmal aufrufen = schliessen.
# Faellt auf das Rofi-Menue zurueck, wenn GTK4/PyGObject fehlen.

source "$HOME/.config/hypr/scripts/lib.sh"
PY="$HOME/.config/hypr/startmenu/startmenu.py"
LOG="$HOME/.cache/claudes-glassy/startmenu.log"
mkdir -p "$(dirname "$LOG")"

# Rofi-Menues schliessen, falls offen
pkill -x rofi 2>/dev/null

if ! python3 -c 'import gi; gi.require_version("Gtk", "4.0")' 2>/dev/null; then
    exec "$HOME/.config/hypr/scripts/startmenu-rofi.sh"
fi

mon="$(glassy_cursor_monitor)"

# gtk4-layer-shell muss vor libwayland geladen werden (nur fuer das Menue selbst)
pre=""
for lib in /usr/lib/libgtk4-layer-shell.so /usr/lib/libgtk4-layer-shell.so.0 /usr/lib64/libgtk4-layer-shell.so; do
    [ -f "$lib" ] && { pre="$lib"; break; }
done

if [ -n "$pre" ]; then
    LD_PRELOAD="$pre" setsid -f python3 "$PY" ${mon:+--monitor "$mon"} >"$LOG" 2>&1
else
    setsid -f python3 "$PY" ${mon:+--monitor "$mon"} >"$LOG" 2>&1
fi
