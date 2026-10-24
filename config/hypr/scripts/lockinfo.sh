#!/usr/bin/env bash
# claudes-glassy: Textbausteine fuer den Sperrbildschirm (hyprlock)
#   lockinfo.sh greet  -> "Guten Abend, Stefan"
#   lockinfo.sh music  -> "<icon>  Titel  -  Kuenstler" (leer, wenn nichts laeuft)
case "$1" in
    greet)
        h=$(date +%H); h=$((10#$h))
        n="$(id -un)"; n="${n^}"
        if   [ "$h" -lt 5 ];  then g="Gute Nacht"
        elif [ "$h" -lt 11 ]; then g="Guten Morgen"
        elif [ "$h" -lt 18 ]; then g="Hallo"
        else                       g="Guten Abend"
        fi
        echo "$g, $n"
        ;;
    music)
        s="$(playerctl metadata --format '{{ title }}  -  {{ artist }}' 2>/dev/null)"
        [ -n "$s" ] && printf '<span foreground="#a6e3a1"></span>   %s\n' "${s:0:70}"
        ;;
esac
