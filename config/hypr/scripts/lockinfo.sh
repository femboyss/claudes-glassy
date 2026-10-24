#!/usr/bin/env bash
# claudes-glassy: Bausteine fuer den Sperrbildschirm (hyprlock)
#   lockinfo.sh greet   -> "Guten Abend"           (ohne Namen)
#   lockinfo.sh date    -> "Sonntag, 25. Oktober"
#   lockinfo.sh title   -> Songtitel               (leer, wenn nichts laeuft)
#   lockinfo.sh artist  -> Kuenstler
#   lockinfo.sh status  -> Play/Pause-Symbol
#   lockinfo.sh cover   -> Pfad zum Cover-Bild     (durchsichtiges Bild, wenn nichts laeuft)
#   lockinfo.sh uptime  -> "an seit 3 Std 12 Min"

CACHE="$HOME/.cache/claudes-glassy"
EMPTY="$HOME/.config/hypr/lock/empty.png"
mkdir -p "$CACHE"

playing() {
    local st
    st="$(playerctl status 2>/dev/null)"
    [ "$st" = "Playing" ] || [ "$st" = "Paused" ]
}

case "$1" in
    greet)
        h=$(date +%H); h=$((10#$h))
        if   [ "$h" -lt 5 ];  then echo "Gute Nacht"
        elif [ "$h" -lt 11 ]; then echo "Guten Morgen"
        elif [ "$h" -lt 18 ]; then echo "Hallo"
        else                       echo "Guten Abend"
        fi
        ;;
    date)
        # Deutsch, unabhaengig davon, ob die de_AT-Locale installiert ist
        days=(Sonntag Montag Dienstag Mittwoch Donnerstag Freitag Samstag)
        months=(Jaenner Februar Maerz April Mai Juni Juli August September Oktober November Dezember)
        months[0]=$'J\u00e4nner'; months[2]=$'M\u00e4rz'
        echo "${days[$(date +%w)]}, $(date +%-d). ${months[$((10#$(date +%m) - 1))]}"
        ;;
    title)
        playing && playerctl metadata --format '{{ title }}' 2>/dev/null | cut -c1-48
        ;;
    artist)
        playing && playerctl metadata --format '{{ artist }}' 2>/dev/null | cut -c1-56
        ;;
    status)
        st="$(playerctl status 2>/dev/null)"
        if   [ "$st" = "Playing" ]; then printf ''
        elif [ "$st" = "Paused" ];  then printf ''
        fi
        ;;
    cover)
        if ! playing; then echo "$EMPTY"; exit 0; fi
        url="$(playerctl metadata mpris:artUrl 2>/dev/null)"
        case "$url" in
            file://*)
                p="${url#file://}"; p="$(printf '%b' "${p//%/\\x}")"
                [ -f "$p" ] && echo "$p" || echo "$EMPTY"
                ;;
            http://*|https://*)
                f="$CACHE/lock-cover-$(printf '%s' "$url" | md5sum | cut -c1-12).jpg"
                if [ ! -s "$f" ]; then
                    rm -f "$CACHE"/lock-cover-*.jpg
                    curl -fsSL --max-time 4 "$url" -o "$f" 2>/dev/null || { echo "$EMPTY"; exit 0; }
                fi
                echo "$f"
                ;;
            *) echo "$EMPTY" ;;
        esac
        ;;
    uptime)
        up="$(uptime -p 2>/dev/null | sed 's/^up //; s/ days\?/ T/; s/ hours\?/ Std/; s/ minutes\?/ Min/; s/,//g')"
        echo "an seit $up"
        ;;
esac
