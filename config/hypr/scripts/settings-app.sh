#!/usr/bin/env bash
# claudes-glassy: Einstellungen oeffnen (SUPER+I). Laeuft schon -> nach vorne holen.
PY="$HOME/.config/hypr/settings/glassy_settings.py"
LOG="$HOME/.cache/claudes-glassy/settings.log"
mkdir -p "$(dirname "$LOG")"
if ! python3 -c 'import gi; gi.require_version("Gtk", "4.0")' 2>/dev/null; then
    notify-send -a Einstellungen "Einstellungen brauchen GTK4" "sudo pacman -S python-gobject gtk4"
    exit 1
fi
setsid -f python3 "$PY" >"$LOG" 2>&1
