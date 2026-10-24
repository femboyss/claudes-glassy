#!/usr/bin/env bash
# claudes-glassy: Einstellungen-Menue (aus dem Startmenue)

source "$HOME/.config/hypr/scripts/lib.sh"
glassy_toggle_rofi && exit 0

S="$HOME/.config/hypr/scripts"
has() { command -v "$1" >/dev/null 2>&1; }

opts=()
add() { opts+=("$1|$2|$3"); }        # Label | Icon | Befehl

add "Wallpaper waehlen"         "preferences-desktop-wallpaper" "$S/wallpaper.sh pick"
add "Sound"                     "audio-volume-high"             "pavucontrol"
add "Netzwerk"                  "preferences-system-network"    "nm-connection-editor"
has blueman-manager && add "Bluetooth" "bluetooth"              "blueman-manager"
has nwg-displays    && add "Monitore"  "preferences-desktop-display" "nwg-displays"
has nwg-look        && add "GTK-Design" "preferences-desktop-theme"  "nwg-look"
add "Task-Manager"              "utilities-system-monitor"      "$S/taskmanager.sh"
add "Benachrichtigungen"        "preferences-desktop-notification" "swaync-client -t -sw"
add "Hyprland-Config oeffnen"   "text-editor"                   "xdg-open $HOME/.config/hypr/glassy"
add "Angeheftete Apps bearbeiten" "starred"                     "xdg-open $HOME/.config/hypr/pinned-apps"
add "Bar neu starten"           "view-refresh"                  "pkill -x waybar; setsid -f waybar"

sel="$(for o in "${opts[@]}"; do
          IFS='|' read -r l i _ <<< "$o"; printf '%s\0icon\x1f%s\n' "$l" "$i"
       done | glassy_rofi -dmenu -i -show-icons -no-custom -format i -p "Einstellungen" \
          -theme-str 'window { location: north west; anchor: north west; x-offset: 14px; y-offset: 54px; width: 460px; }
                      listview { lines: 11; }')" || exit 0

IFS='|' read -r _ _ cmd <<< "${opts[$sel]}"
setsid -f sh -c "$cmd" >/dev/null 2>&1
