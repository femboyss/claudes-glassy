#!/usr/bin/env bash
# claudes-glassy: Strg+Alt+Entf-Bildschirm
# Vollbild-Menue mit allen Sitzungs-Optionen (Rofi, Theme sessionscreen.rasi)

THEME="$HOME/.config/rofi/sessionscreen.rasi"
SCRIPTS="$HOME/.config/hypr/scripts"

# Schon offen? Dann schliessen (Toggle)
pkill -x rofi && exit 0

icon() { printf '<span font_desc="JetBrainsMono Nerd Font 38">%s</span>' "$1"; }

# Reihenfolge = Kachel-Reihenfolge (4 pro Zeile)
labels=( "Sperren" "Abmelden" "Energiesparen" "Ruhezustand"
         "Task-Manager" "Neustart" "UEFI / BIOS" "Herunterfahren" )
icons=(  $'' $'' $'' $''
         $'' $'' $'' $'' )

entries=""
for i in "${!labels[@]}"; do
    entries+="$(icon "${icons[$i]}")"$'\n'"${labels[$i]}|"
done
entries="${entries%|}"

# Kopfzeile: Begruessung + Uhrzeit + Uptime
h=$(date +%H)
if   [ "$h" -lt 5 ];  then greet="Gute Nacht"
elif [ "$h" -lt 11 ]; then greet="Guten Morgen"
elif [ "$h" -lt 18 ]; then greet="Hallo"
else                       greet="Guten Abend"
fi
up="$(uptime -p 2>/dev/null | sed 's/^up //; s/hours\?/Std/; s/minutes\?/Min/; s/days\?/Tage/')"
mesg="<span font_desc='Inter Bold 34'>$greet, ${USER^}</span>
<span alpha='70%'>$(date '+%A, %d. %B  -  %H:%M')    -    an seit $up</span>"

sel="$(printf '%s' "$entries" | rofi -dmenu \
    -theme "$THEME" \
    -p "" -mesg "$mesg" \
    -sep '|' -eh 2 -markup-rows \
    -u 7 -a 0 \
    -selected-row 0 -format i \
    -no-custom)" || exit 0

confirm() {
    local q="$1"
    local yes=$'  Ja'
    local no=$'  Nein'
    local ans
    ans="$(printf '%s\n%s' "$no" "$yes" | rofi -dmenu -p "$q" -no-custom \
        -theme-str 'window { width: 420px; } listview { lines: 2; } inputbar { children: [prompt]; } prompt { text-color: #f38ba8; }')"
    [ "$ans" = "$yes" ]
}

logout_cmd() {
    if command -v hyprshutdown >/dev/null 2>&1; then
        hyprshutdown
    else
        hyprctl dispatch 'hl.dsp.exit()'
    fi
}

case "$sel" in
    0) pidof hyprlock || hyprlock ;;
    1) confirm "Wirklich abmelden?"        && logout_cmd ;;
    2) systemctl suspend ;;
    3) systemctl hibernate || notify-send "Ruhezustand" "Nicht verfuegbar (braucht genug Swap + resume-Hook)." ;;
    4) "$SCRIPTS/taskmanager.sh" ;;
    5) confirm "Wirklich neu starten?"     && systemctl reboot ;;
    6) confirm "Neustart ins UEFI/BIOS?"   && systemctl reboot --firmware-setup ;;
    7) confirm "Wirklich herunterfahren?"  && systemctl poweroff ;;
esac
