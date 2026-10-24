#!/usr/bin/env bash
# Power-Menue ueber Rofi.

source "$HOME/.config/hypr/scripts/lib.sh"

pidof rofi >/dev/null && { pkill rofi; exit 0; }

# Nerd-Font-Icons als Escapes (bash 4.2+)
lock=$'  Sperren'
logout=$'  Abmelden'
suspend=$'  Energiesparen'
reboot=$'  Neustart'
shutdown=$'  Herunterfahren'

choice="$(printf '%s\n' "$lock" "$suspend" "$logout" "$reboot" "$shutdown" \
    | glassy_rofi -dmenu -i -p "Power" \
        -theme-str 'window { width: 340px; } listview { lines: 5; } inputbar { children: [prompt]; }')" || exit 0

case "$choice" in
    "$lock")     pidof hyprlock || hyprlock ;;
    "$suspend")  systemctl suspend ;;
    "$logout")   command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()' ;;
    "$reboot")   systemctl reboot ;;
    "$shutdown") systemctl poweroff ;;
esac
