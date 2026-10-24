#!/usr/bin/env bash
# claudes-glassy: einfaches Rofi-Startmenue (Fallback, falls das GTK-Startmenue nicht startet)
# Angeheftete Apps + System-Kacheln. Oeffnet sich auf dem Monitor unter der Maus.
#
# Angeheftete Apps aendern:  ~/.config/hypr/pinned-apps
#   eine Zeile pro App, Name der .desktop-Datei ohne Endung,
#   Alternativen mit | (die erste, die installiert ist, gewinnt)

source "$HOME/.config/hypr/scripts/lib.sh"
glassy_toggle_rofi && exit 0

PINNED="$HOME/.config/hypr/pinned-apps"
THEME="$HOME/.config/rofi/startmenu.rasi"
SCRIPTS="$HOME/.config/hypr/scripts"

APPDIRS=(
    "$HOME/.local/share/applications"
    "$HOME/.local/share/flatpak/exports/share/applications"
    "/var/lib/flatpak/exports/share/applications"
    "/usr/local/share/applications"
    "/usr/share/applications"
)

find_desktop() {   # $1 = id -> Pfad
    local d
    for d in "${APPDIRS[@]}"; do
        [ -f "$d/$1.desktop" ] && { echo "$d/$1.desktop"; return 0; }
    done
    return 1
}

desktop_key() {    # $1 = Datei, $2 = Key  (nur [Desktop Entry]-Abschnitt, ohne Uebersetzung)
    awk -v k="$2" -F= '
        /^\[/ { sec = $0 }
        sec == "[Desktop Entry]" && $1 == k { sub(/^[^=]*=/, ""); print; exit }' "$1"
}

ids=(); names=(); icons=(); files=()
if [ -f "$PINNED" ]; then
    while IFS= read -r line; do
        line="${line%%#*}"; line="${line// /}"
        [ -z "$line" ] && continue
        IFS='|' read -ra alts <<< "$line"
        for id in "${alts[@]}"; do
            if f="$(find_desktop "$id")"; then
                ids+=("$id"); files+=("$f")
                names+=("$(desktop_key "$f" Name)")
                icons+=("$(desktop_key "$f" Icon)")
                break
            fi
        done
    done < "$PINNED"
fi

# System-Kacheln (immer am Ende)
sys_names=( "Alle Apps" "Dateien" "Einstellungen" "Sperren" "Ein/Aus" )
sys_icons=( "applications-other" "system-file-manager" "preferences-system" "system-lock-screen" "system-shutdown" )

h=$(date +%H); h=$((10#$h))
if   [ "$h" -lt 5 ];  then greet="Gute Nacht"
elif [ "$h" -lt 11 ]; then greet="Guten Morgen"
elif [ "$h" -lt 18 ]; then greet="Hallo"
else                       greet="Guten Abend"
fi
n="$(id -un)"
mesg="<span font_desc='Inter Bold 16'>$greet, ${n^}</span>   <span alpha='60%'>$(LC_TIME=de_AT.UTF-8 date '+%a, %d. %b  %H:%M')</span>"

sel="$(
    {
        for i in "${!names[@]}"; do printf '%s\0icon\x1f%s\n' "${names[$i]}" "${icons[$i]}"; done
        for i in "${!sys_names[@]}"; do printf '%s\0icon\x1f%s\n' "${sys_names[$i]}" "${sys_icons[$i]}"; done
    } | glassy_rofi -dmenu -i -show-icons -no-custom -format i \
            -theme "$THEME" -p "" -mesg "$mesg"
)" || exit 0

count=${#names[@]}
if [ "$sel" -lt "$count" ]; then
    # App starten: gtk-launch, sonst Exec-Zeile selbst ausfuehren
    if command -v gtk-launch >/dev/null 2>&1; then
        setsid -f gtk-launch "${ids[$sel]}" >/dev/null 2>&1
    else
        exec_line="$(desktop_key "${files[$sel]}" Exec | sed -E 's/ ?%[a-zA-Z]//g')"
        setsid -f sh -c "$exec_line" >/dev/null 2>&1
    fi
    exit 0
fi

case $((sel - count)) in
    0) "$SCRIPTS/search.sh" ;;
    1) setsid -f xdg-open "$HOME" >/dev/null 2>&1 ;;
    2) "$SCRIPTS/settings-app.sh" ;;
    3) pidof hyprlock || hyprlock ;;
    4) "$SCRIPTS/sessionscreen.sh" ;;
esac
