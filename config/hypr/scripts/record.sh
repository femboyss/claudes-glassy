#!/usr/bin/env bash
# claudes-glassy: Bildschirmaufnahme (wf-recorder)          SUPER+ALT+R
#   record.sh           -> laeuft schon? stoppen. Sonst Menue: Bereich/Monitor, mit/ohne Ton
#   record.sh stop      -> Aufnahme beenden (auch: Klick auf die Dynamic Island)
#   record.sh area|area-audio|monitor|monitor-audio  -> direkt starten
# Videos: ~/Videos/Aufnahmen   Log: ~/.cache/claudes-glassy/record.log
# Waehrend der Aufnahme zeigt die Dynamic Island einen roten Punkt + Zeit.

source "$HOME/.config/hypr/scripts/lib.sh" 2>/dev/null

CACHE="$HOME/.cache/claudes-glassy"
PIDF="$CACHE/recording.pid"
STARTF="$CACHE/recording.start"
FILEF="$CACHE/recording.file"
LOG="$CACHE/record.log"
VDIR="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")"
[ "$VDIR" = "$HOME" ] && VDIR="$HOME/Videos"
VDIR="$VDIR/Aufnahmen"
mkdir -p "$CACHE" "$VDIR"

notify() { command -v notify-send >/dev/null 2>&1 && notify-send -a Aufnahme "$@"; }

recording() { [ -f "$PIDF" ] && kill -0 "$(cat "$PIDF")" 2>/dev/null; }

stop_rec() {
    local pid file
    pid="$(cat "$PIDF" 2>/dev/null)"
    file="$(cat "$FILEF" 2>/dev/null)"
    [ -n "$pid" ] && kill -INT "$pid" 2>/dev/null
    for _ in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    kill -0 "$pid" 2>/dev/null && kill -TERM "$pid" 2>/dev/null
    for _ in $(seq 1 30); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    rm -f "$PIDF" "$STARTF" "$FILEF"
    if [ -s "$file" ]; then
        notify -i video-x-generic "Aufnahme gespeichert" "$file"
        printf 'file://%s' "$file" | wl-copy --type text/uri-list 2>/dev/null
    else
        notify -u critical "Aufnahme fehlgeschlagen" "Details: $LOG"
    fi
}

start_rec() {   # $1 = area|monitor   $2 = audio|""
    command -v wf-recorder >/dev/null 2>&1 || { notify -u critical "wf-recorder fehlt" "sudo pacman -S wf-recorder"; exit 1; }
    local file args=()
    file="$VDIR/Aufnahme_$(date +%Y-%m-%d_%H-%M-%S).mp4"

    if [ "$1" = "area" ]; then
        command -v slurp >/dev/null 2>&1 || { notify "slurp fehlt" "sudo pacman -S slurp"; exit 1; }
        local geom
        geom="$(slurp -b 1a1b2688 -c f7768eff -s f7768e18 -w 2 -d)" || exit 0
        args+=(-g "$geom")
    else
        local mon
        mon="$(glassy_cursor_monitor 2>/dev/null)"
        [ -z "$mon" ] && mon="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')"
        args+=(-o "$mon")
    fi

    if [ "$2" = "audio" ]; then
        local sink
        sink="$(pactl get-default-sink 2>/dev/null)"
        [ -n "$sink" ] && args+=(--audio="$sink.monitor") || args+=(--audio)
    fi

    # NVIDIA: Hardware-Encoder nutzen, wenn ffmpeg ihn kennt (schont die CPU)
    if command -v nvidia-smi >/dev/null 2>&1 && ffmpeg -hide_banner -encoders 2>/dev/null | grep -q h264_nvenc; then
        args+=(-c h264_nvenc)
    fi

    launch() {
        echo "$(date '+%F %T') wf-recorder $* -f $file" >> "$LOG"
        # Hintergrund-Jobs erben "SIGINT ignorieren" -> mit env wieder einschalten,
        # damit wf-recorder das Video beim Stoppen sauber abschliesst
        local envdef=()
        env --default-signal=INT true 2>/dev/null && envdef=(env --default-signal=INT,TERM)
        setsid "${envdef[@]}" wf-recorder "$@" -f "$file" >>"$LOG" 2>&1 < /dev/null &
        pid=$!
        sleep 0.7
        kill -0 "$pid" 2>/dev/null
    }
    local pid
    if ! launch "${args[@]}"; then
        # NVENC zickt? Ohne Hardware-Encoder nochmal versuchen
        local plain=()
        for a in "${args[@]}"; do [ "$a" = "-c" ] || [ "$a" = "h264_nvenc" ] || plain+=("$a"); done
        if [ "${#plain[@]}" -ne "${#args[@]}" ] && launch "${plain[@]}"; then
            echo "  -> ohne NVENC gestartet" >> "$LOG"
        else
            notify -u critical "Aufnahme konnte nicht starten" "Details: $LOG"
            exit 1
        fi
    fi
    echo "$pid" > "$PIDF"
    date +%s > "$STARTF"
    echo "$file" > "$FILEF"
    notify -t 1500 "Aufnahme laeuft" "Stoppen: SUPER+ALT+R oder auf die Island klicken"
    disown "$pid" 2>/dev/null
}

case "$1" in
    stop)  recording && stop_rec; exit 0 ;;
    area)          recording || start_rec area ;;
    area-audio)    recording || start_rec area audio ;;
    monitor)       recording || start_rec monitor ;;
    monitor-audio) recording || start_rec monitor audio ;;
    *)
        if recording; then stop_rec; exit 0; fi
        rm -f "$PIDF" "$STARTF" "$FILEF"
        pkill -x rofi && exit 0
        o1=$'  Bereich  (mit Ton)'
        o2=$'  Bereich  (ohne Ton)'
        o3=$'  Ganzer Monitor  (mit Ton)'
        o4=$'  Ganzer Monitor  (ohne Ton)'
        sel="$(printf '%s\n%s\n%s\n%s' "$o1" "$o2" "$o3" "$o4" | glassy_rofi -dmenu -i -p "Aufnahme" -no-custom \
            -mesg "<span alpha='70%'>Stoppen: SUPER+ALT+R oder Klick auf die Island</span>" \
            -theme-str 'window { width: 420px; } listview { lines: 4; } inputbar { children: [prompt]; } prompt { text-color: #f7768e; }')" || exit 0
        case "$sel" in
            "$o1") start_rec area audio ;;
            "$o2") start_rec area ;;
            "$o3") start_rec monitor audio ;;
            "$o4") start_rec monitor ;;
        esac
        ;;
esac
