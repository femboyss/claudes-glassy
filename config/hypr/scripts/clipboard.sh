#!/usr/bin/env bash
# Zwischenablage-Verlauf (cliphist) ueber Rofi.
# Enter = einfuegen in Zwischenablage. Verlauf leeren: cliphist wipe

source "$HOME/.config/hypr/scripts/lib.sh"

pidof rofi >/dev/null && { pkill rofi; exit 0; }

sel="$(cliphist list | glassy_rofi -dmenu -p "Ablage" -display-columns 2)" || exit 0
[ -n "$sel" ] && printf '%s' "$sel" | cliphist decode | wl-copy
