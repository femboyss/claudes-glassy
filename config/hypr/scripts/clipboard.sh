#!/usr/bin/env bash
# Zwischenablage-Verlauf (cliphist) ueber Rofi.
# Enter = einfuegen in Zwischenablage. Verlauf leeren: cliphist wipe

pidof rofi >/dev/null && { pkill rofi; exit 0; }

sel="$(cliphist list | rofi -dmenu -p "Ablage" -display-columns 2)" || exit 0
[ -n "$sel" ] && printf '%s' "$sel" | cliphist decode | wl-copy
