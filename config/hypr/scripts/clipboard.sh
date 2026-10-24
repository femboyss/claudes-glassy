#!/usr/bin/env bash
# claudes-glassy: Zwischenablage-Verlauf (cliphist) ueber Rofi   (SUPER+V)
#   Enter        -> Eintrag wieder in die Zwischenablage
#   Entf         -> diesen Eintrag loeschen (Menue bleibt offen)
#   Shift+Entf   -> ALLES loeschen (mit Nachfrage)
#   oder oben den Eintrag "Verlauf leeren" waehlen

source "$HOME/.config/hypr/scripts/lib.sh"
pkill -x rofi && exit 0

command -v cliphist >/dev/null 2>&1 || { notify-send "Zwischenablage" "cliphist fehlt:  sudo pacman -S cliphist"; exit 1; }

WIPE=$'  Verlauf leeren'
row=0

wipe_all() {
    local yes=$'  Ja, alles loeschen' no=$'  Nein'
    local ans
    ans="$(printf '%s\n%s' "$no" "$yes" | glassy_rofi -dmenu -p "Ganzen Verlauf loeschen?" -no-custom \
        -theme-str 'window { width: 420px; } listview { lines: 2; } inputbar { children: [prompt]; } prompt { text-color: #f7768e; }')"
    if [ "$ans" = "$yes" ]; then
        cliphist wipe
        wl-copy --clear 2>/dev/null
        notify-send -a Zwischenablage "Zwischenablage" "Verlauf geloescht"
        return 0
    fi
    return 1
}

while true; do
    list="$(cliphist list)"
    if [ -z "$list" ]; then
        notify-send -a Zwischenablage "Zwischenablage" "Verlauf ist leer"
        exit 0
    fi

    sel="$( { printf '%s\n' "$WIPE"; printf '%s\n' "$list"; } | glassy_rofi -dmenu -i \
        -p "Ablage" -display-columns 2 -no-custom \
        -selected-row "$row" -format 'i	s' \
        -mesg "<span alpha='70%'>Enter: einfuegen   -   Entf: Eintrag loeschen   -   Shift+Entf: alles loeschen</span>" \
        -kb-remove-char-forward "Control+d" \
        -kb-delete-entry "" \
        -kb-custom-1 "Delete" \
        -kb-custom-2 "Shift+Delete" )"
    code=$?
    idx="${sel%%	*}"
    line="${sel#*	}"

    case "$code" in
        0)      # Enter
            if [ "$line" = "$WIPE" ]; then
                wipe_all && exit 0
                continue
            fi
            printf '%s' "$line" | cliphist decode | wl-copy
            exit 0
            ;;
        10)     # Entf: einzelnen Eintrag loeschen
            if [ "$line" != "$WIPE" ] && [ -n "$line" ]; then
                printf '%s' "$line" | cliphist delete
            fi
            row="$idx"
            ;;
        11)     # Shift+Entf: alles
            wipe_all && exit 0
            ;;
        *)      exit 0 ;;   # Esc
    esac
done
