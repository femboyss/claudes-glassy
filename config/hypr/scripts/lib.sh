#!/usr/bin/env bash
# claudes-glassy: gemeinsame Helfer fuer die Scripts (wird per "source" geladen)

# Name des Monitors, auf dem gerade die Maus ist (z. B. DP-3).
# Damit oeffnen sich Menues dort, wo du in die Bar geklickt hast.
glassy_cursor_monitor() {
    local pos cx cy
    pos="$(hyprctl -j cursorpos 2>/dev/null)" || return 1
    cx="$(jq -r '.x' <<< "$pos")"; cy="$(jq -r '.y' <<< "$pos")"
    hyprctl -j monitors 2>/dev/null | jq -r --argjson cx "$cx" --argjson cy "$cy" '
        .[] | ( if (.transform % 2) == 1
                then {w: (.height / .scale), h: (.width / .scale)}
                else {w: (.width / .scale),  h: (.height / .scale)} end ) as $s
        | select($cx >= .x and $cx < (.x + $s.w) and $cy >= .y and $cy < (.y + $s.h))
        | .name' | head -n 1
}

# "MONITOR X Y": Monitor unter der Maus + Mausposition relativ zu diesem Monitor (logische Pixel)
glassy_cursor_local() {
    local pos cx cy
    pos="$(hyprctl -j cursorpos 2>/dev/null)" || return 1
    cx="$(jq -r '.x' <<< "$pos")"; cy="$(jq -r '.y' <<< "$pos")"
    hyprctl -j monitors 2>/dev/null | jq -r --argjson cx "$cx" --argjson cy "$cy" '
        .[] | ( if (.transform % 2) == 1
                then {w: (.height / .scale), h: (.width / .scale)}
                else {w: (.width / .scale),  h: (.height / .scale)} end ) as $s
        | select($cx >= .x and $cx < (.x + $s.w) and $cy >= .y and $cy < (.y + $s.h))
        | "\(.name) \(($cx - .x) | floor) \(($cy - .y) | floor)"' | head -n 1
}

# rofi auf dem Monitor unter der Maus starten (Fallback: fokussierter Monitor)
glassy_rofi() {
    local mon
    mon="$(glassy_cursor_monitor)"
    if [ -n "$mon" ]; then
        rofi -m "$mon" "$@"
    else
        rofi "$@"
    fi
}

# Menue schliessen, wenn schon eins offen ist (Toggle). Gibt 0 zurueck, wenn geschlossen wurde.
glassy_toggle_rofi() {
    pkill -x rofi >/dev/null 2>&1
}
