#!/usr/bin/env bash
# Screenshot -> Zwischenablage + Datei in ~/Pictures/Screenshots
#   screenshot.sh area  -> Bereich auswaehlen (Print)
#   screenshot.sh full  -> Monitor unter der Maus (Shift+Print)

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

case "$1" in
    full)
        MON="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')"
        grim -o "$MON" "$FILE" || exit 1
        ;;
    *)
        GEOM="$(slurp -b 1e1e2e88 -c cba6f7ff -s cba6f722 -w 2 -d)" || exit 0
        grim -g "$GEOM" "$FILE" || exit 1
        ;;
esac

wl-copy < "$FILE"
notify-send -i "$FILE" "Screenshot" "Gespeichert und kopiert:\n$(basename "$FILE")"
