#!/usr/bin/env bash
# claudes-glassy: Suche (Suchleiste in der Bar / SUPER+Space)
# Apps, offene Fenster (Tab wechselt den Modus) und Befehle.
# Oeffnet sich direkt unter der Bar, auf dem Monitor unter der Maus.

source "$HOME/.config/hypr/scripts/lib.sh"
glassy_toggle_rofi && exit 0

glassy_rofi -show drun -modi "drun,window,run" \
    -theme-str 'window { location: north west; anchor: north west; x-offset: 14px; y-offset: 54px; width: 620px; }
                listview { lines: 9; }
                entry { placeholder: "Apps, Fenster, Befehle suchen ..."; }'
