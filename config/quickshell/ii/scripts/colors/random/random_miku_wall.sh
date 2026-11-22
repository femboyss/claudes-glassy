#!/usr/bin/env bash
# ==================================================================
#  claudes-glassy: zufaelliges Hatsune-Miku-Wallpaper von wallhaven.cc
#
#    random_miku_wall.sh               jetzt ein neues holen und setzen
#    random_miku_wall.sh --startup     beim Hyprland-Start (nur wenn in den
#                                      Einstellungen eingeschaltet, wartet auf Netz)
#    random_miku_wall.sh --res 2560x1440   Aufloesung erzwingen
#
#  Es werden NUR Bilder in exakt der Bildschirm-Aufloesung geholt
#  (wallhaven "resolutions=WxH"), also kein Hoch- oder Runterskalieren.
#  Nur SFW (purity=100), Kategorie Anime.
#
#  Einstellungen in ~/.config/illogical-impulse/config.json -> .glassy:
#    mikuWallpaperOnStart  true/false   bei jedem Start ein neues
#    mikuResolution        "auto" oder z.B. "1920x1080"
#    mikuKeep              wie viele alte Miku-Wallpaper behalten (Standard 15)
# ==================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHELL_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/illogical-impulse/config.json"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/claudes-glassy"
API="https://wallhaven.cc/api/v1/search"

pictures_dir() {
    if command -v xdg-user-dir >/dev/null 2>&1; then xdg-user-dir PICTURES; else echo "$HOME/Pictures"; fi
}
WALL_DIR="$(pictures_dir)/Wallpapers/miku"

setting() {   # $1 = Schluessel unter .glassy, $2 = Standardwert
    local v
    v="$(jq -r --arg k "$1" '.glassy[$k] // empty' "$SHELL_CONFIG" 2>/dev/null)"
    [ -n "$v" ] && echo "$v" || echo "$2"
}

say() {
    echo "$*"
    command -v notify-send >/dev/null 2>&1 && notify-send -a "Miku-Wallpaper" -i preferences-desktop-wallpaper "Miku-Wallpaper" "$*" >/dev/null 2>&1 &
}

# Aufloesung des groessten Monitors (gedrehte Monitore: Breite/Hoehe getauscht)
detect_res() {
    hyprctl monitors -j 2>/dev/null | jq -r '
        map(if (.transform % 2) == 1 then {w: .height, h: .width} else {w: .width, h: .height} end)
        | max_by(.w * .h) | "\(.w)x\(.h)"' 2>/dev/null
}

startup=0
res=""
while [ $# -gt 0 ]; do
    case "$1" in
        --startup) startup=1 ;;
        --res)     res="${2:-}"; shift ;;
    esac
    shift
done

if [ "$startup" = 1 ]; then
    [ "$(setting mikuWallpaperOnStart false)" = true ] || exit 0
fi

mkdir -p "$STATE_DIR" "$WALL_DIR"
exec 9>"$STATE_DIR/miku-wall.lock"
flock -n 9 || exit 0   # laeuft schon

[ -z "$res" ] && res="$(setting mikuResolution auto)"
if [ "$res" = auto ] || ! [[ "$res" =~ ^[0-9]+x[0-9]+$ ]]; then
    # beim Start kann Hyprland die Monitore noch nicht melden -> kurz warten
    for _ in $(seq 1 20); do
        res="$(detect_res)"
        [[ "$res" =~ ^[0-9]+x[0-9]+$ ]] && break
        sleep 0.5
    done
fi
if ! [[ "$res" =~ ^[0-9]+x[0-9]+$ ]]; then
    say "Konnte die Bildschirm-Aufloesung nicht erkennen. Setz sie fest: glassy --miku-res 1920x1080"
    exit 1
fi

# beim Start: auf Netz warten (max. ~60 s)
if [ "$startup" = 1 ]; then
    for _ in $(seq 1 30); do
        curl -s -m 3 -o /dev/null "https://wallhaven.cc" && break
        sleep 2
    done
fi

userAgent="$(jq -r '.networking.userAgent // empty' "$SHELL_CONFIG" 2>/dev/null)"
[ -z "$userAgent" ] && userAgent="claudes-glassy"

response="$(curl -s -m 20 -A "$userAgent" -G "$API" \
    --data-urlencode "q=hatsune miku" \
    --data-urlencode "categories=010" \
    --data-urlencode "purity=100" \
    --data-urlencode "resolutions=$res" \
    --data-urlencode "sorting=random")"

count="$(echo "$response" | jq -r '.data | length' 2>/dev/null)"
if ! [[ "$count" =~ ^[0-9]+$ ]]; then
    say "wallhaven.cc nicht erreichbar - Wallpaper bleibt wie es ist."
    exit 1
fi
if [ "$count" -eq 0 ]; then
    say "Keine Miku-Wallpaper in genau $res gefunden - Wallpaper bleibt wie es ist."
    exit 1
fi

current="$(jq -r '.background.wallpaperPath // empty' "$SHELL_CONFIG" 2>/dev/null)"

# zufaellig eins nehmen, das nicht gerade aktiv ist
pick=""
for i in $(shuf -i 0-$((count - 1))); do
    id="$(echo "$response" | jq -r ".data[$i].id")"
    url="$(echo "$response" | jq -r ".data[$i].path")"
    [ "$(echo "$response" | jq -r ".data[$i].resolution")" = "$res" ] || continue
    case "$current" in *"miku-$id."*) continue ;; esac
    pick="$id"
    break
done
if [ -z "$pick" ]; then
    say "Kein neues Miku-Wallpaper gefunden - Wallpaper bleibt wie es ist."
    exit 1
fi

ext="${url##*.}"
dest="$WALL_DIR/miku-$pick.$ext"
if [ ! -s "$dest" ]; then
    curl -s -f -m 60 -A "$userAgent" "$url" -o "$dest.part" && mv "$dest.part" "$dest" || {
        rm -f "$dest.part"
        say "Download fehlgeschlagen - Wallpaper bleibt wie es ist."
        exit 1
    }
fi

# Sicherheitscheck: wirklich exakt die Aufloesung?
if command -v identify >/dev/null 2>&1; then
    real="$(identify -format '%wx%h' "$dest[0]" 2>/dev/null)"
    if [ -n "$real" ] && [ "$real" != "$res" ]; then
        rm -f "$dest"
        say "Bild hatte $real statt $res - verworfen."
        exit 1
    fi
fi

bash "$SCRIPT_DIR/../switchwall.sh" --image "$dest" >/dev/null 2>&1
echo "Miku-Wallpaper gesetzt: $dest ($res)  https://wallhaven.cc/w/$pick"

# alte aufraeumen (aktuelles bleibt immer)
keep="$(setting mikuKeep 15)"
[[ "$keep" =~ ^[0-9]+$ ]] || keep=15
ls -1t "$WALL_DIR"/miku-* 2>/dev/null | tail -n +"$((keep + 1))" | while read -r f; do
    [ "$f" = "$dest" ] || rm -f "$f"
done
exit 0
