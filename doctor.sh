#!/usr/bin/env bash
# ==================================================================
#  claudes-glassy - Doktor: findet kaputte / veraenderte Configs
#    bash doctor.sh            -> pruefen, Bericht nach ~/glassy-doctor.txt
#    bash doctor.sh --repair   -> veraenderte/fehlende Dateien aus dem Repo
#                                 zurueckholen (alte Versionen werden gesichert)
#  Eigene Sachen in ~/.config/hypr/custom.lua, pinned-apps und den
#  Startmenue-Einstellungen werden NICHT angefasst.
# ==================================================================
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_CFG="$HERE/config"
OUT="$HOME/glassy-doctor.txt"
STAMP="$(date +%Y%m%d-%H%M%S)"
SAFE="$HOME/.config-backup-catppuccin-glass-$STAMP-doctor"
REPAIR=0; [ "$1" = "--repair" ] && REPAIR=1

# Dateien, die dir gehoeren und nie "repariert" werden
KEEP_RE='(hypr/custom\.lua|hypr/pinned-apps|hypr/avatar\.png|hypr/startmenu/settings\.json|hypr/island/settings\.json|hypr/glassy-settings\.(lua|json))$'
# Von der Einstellungs-App (SUPER+I) erzeugte Dateien nicht als "veraendert" melden
if [ -f "$HOME/.config/hypr/glassy-settings.json" ]; then
    KEEP_RE='(hypr/custom\.lua|hypr/pinned-apps|hypr/avatar\.png|hypr/startmenu/settings\.json|hypr/island/settings\.json|hypr/glassy-settings\.(lua|json)|waybar/config\.jsonc|hypr/hypridle\.conf|hypr/hyprlock\.conf)$'
fi

ok()   { printf '\033[38;2;158;206;106m[ok]\033[0m %s\n' "$*"; }
warn() { printf '\033[38;2;224;175;104m[!!]\033[0m %s\n' "$*"; }
bad()  { printf '\033[38;2;247;118;142m[xx]\033[0m %s\n' "$*"; }

exec > >(tee "$OUT") 2>&1
echo "claudes-glassy Doktor  -  $(date)"
echo "Repo: $HERE ($(git -C "$HERE" rev-parse --short HEAD 2>/dev/null || echo '?'))"
echo

echo "== Repo-Kopie =="
if [ -d "$HERE/.git" ]; then
    if [ -n "$(git -C "$HERE" status --porcelain 2>/dev/null)" ]; then
        bad "In der Repo-Kopie ($HERE) wurde rumgeschrieben -> Updates bleiben haengen."
        echo "   Fix:  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/femboyss/claudes-glassy/main/get.sh)\""
    fi
    if timeout 8 git -C "$HERE" fetch -q --depth 1 origin main 2>/dev/null; then
        if [ "$(git -C "$HERE" rev-parse HEAD)" != "$(git -C "$HERE" rev-parse origin/main)" ]; then
            bad "Repo-Kopie ist NICHT aktuell (lokal $(git -C "$HERE" rev-parse --short HEAD), GitHub $(git -C "$HERE" rev-parse --short origin/main))"
            echo "   Fix:  bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/femboyss/claudes-glassy/main/get.sh)\""
        else
            ok "Repo-Kopie ist aktuell"
        fi
    else
        warn "GitHub nicht erreichbar - Aktualitaet nicht geprueft"
    fi
fi
echo

echo "== Hyprland =="
if command -v hyprctl >/dev/null; then
    hyprctl version 2>/dev/null | head -n 2
    errs="$(hyprctl configerrors 2>/dev/null)"
    if [ -z "$errs" ] || echo "$errs" | grep -qi "no errors"; then ok "keine Config-Fehler"; else bad "Config-Fehler:"; echo "$errs"; fi
else
    bad "hyprctl nicht gefunden"
fi
echo

echo "== Laufende Dienste =="
for p in waybar swaync hypridle; do
    pgrep -x "$p" >/dev/null && ok "$p laeuft" || bad "$p laeuft NICHT"
done
pgrep -f "startmenu.py --daemon" >/dev/null && ok "Startmenue-Dienst laeuft" || warn "Startmenue-Dienst laeuft nicht (startet beim naechsten Super)"
pgrep -f "island/island.py" >/dev/null && ok "Dynamic Island laeuft" || bad "Dynamic Island laeuft NICHT  ->  ~/.config/hypr/scripts/island.sh"
pgrep -f "clipman.py --daemon" >/dev/null && ok "Zwischenablage-Dienst laeuft" || warn "Zwischenablage-Dienst laeuft nicht (startet beim naechsten SUPER+V)"
pgrep -f "glassy --watch" >/dev/null && ok "Update-Suche laeuft (SUPER+I -> Updates)" || warn "Update-Suche laeuft nicht  ->  glassy --reload"
[ -f "$HOME/.cache/claudes-glassy/recording.pid" ] && kill -0 "$(cat "$HOME/.cache/claudes-glassy/recording.pid")" 2>/dev/null && warn "Bildschirmaufnahme laeuft gerade"
pgrep -x qs >/dev/null || pgrep -x quickshell >/dev/null && warn "Quickshell (end-4) laeuft noch parallel"
echo

# Laeuft noch eine alte Version im Hintergrund? (Prozess aelter als die Datei)
stale() {   # $1 = pgrep-Muster  $2 = Datei
    local pid et mt
    pid="$(pgrep -f "$1" | head -n 1)"; [ -z "$pid" ] && return 1
    et="$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ')"; [ -z "$et" ] && return 1
    mt="$(stat -c %Y "$2" 2>/dev/null)"; [ -z "$mt" ] && return 1
    [ "$mt" -gt "$(( $(date +%s) - et ))" ]
}
stale "startmenu.py --daemon" "$HOME/.config/hypr/startmenu/startmenu.py" && bad "Startmenue laeuft noch in ALTER Version  ->  pkill -f startmenu.py"
stale "island/island.py"      "$HOME/.config/hypr/island/island.py"       && bad "Island laeuft noch in ALTER Version  ->  ~/.config/hypr/scripts/island.sh restart"
stale "clipman.py --daemon"   "$HOME/.config/hypr/clipboard/clipman.py"   && bad "Zwischenablage laeuft noch in ALTER Version  ->  pkill -f clipman.py"
echo

echo "== Pakete =="
missing=()
for p in hyprland hyprlock hypridle waybar rofi swaync kitty grim slurp wl-clipboard cliphist jq playerctl \
         python-gobject gtk4 gtk4-layer-shell libpulse wf-recorder hyprpicker ttf-jetbrains-mono-nerd inter-font papirus-icon-theme; do
    pacman -Q "$p" >/dev/null 2>&1 || missing+=("$p")
done
if [ ${#missing[@]} -eq 0 ]; then ok "alle Pakete da"; else bad "fehlt: ${missing[*]}"; echo "   sudo pacman -S --needed ${missing[*]}"; fi
echo

echo "== Configs im Vergleich zum Repo =="
changed=(); absent=()
while IFS= read -r -d '' f; do
    rel="${f#$REPO_CFG/}"
    [[ "$rel" =~ $KEEP_RE ]] && continue
    dst="$HOME/.config/$rel"
    if [ ! -e "$dst" ]; then absent+=("$rel")
    elif ! cmp -s "$f" "$dst"; then changed+=("$rel")
    fi
done < <(find "$REPO_CFG" -type f -not -name '*.pyc' -not -path '*__pycache__*' -print0)
# Dateien in den Glassy-Ordnern, die es im Repo nicht gibt (z. B. von anderen Tools reingeschrieben)
extra=()
for d in hypr/glassy hypr/scripts hypr/startmenu hypr/island hypr/clipboard hypr/settings waybar rofi swaync; do
    [ -d "$HOME/.config/$d" ] || continue
    while IFS= read -r -d '' f; do
        rel="${f#$HOME/.config/}"
        [[ "$rel" =~ $KEEP_RE ]] && continue
        [ -e "$REPO_CFG/$rel" ] || extra+=("$rel")
    done < <(find "$HOME/.config/$d" -type f -not -name '*.pyc' -not -path '*__pycache__*' -print0)
done
if [ -f "$HOME/.config/gtk-4.0/gtk.css" ] && grep -qiE '(^|[ ,])window' "$HOME/.config/gtk-4.0/gtk.css"; then
    warn "~/.config/gtk-4.0/gtk.css setzt Fenster-Hintergruende (kann Island/Startmenue dunkel machen; glassy ueberschreibt das jetzt)"
fi
[ -f "$HOME/.config/hypr/hyprland.conf" ] && warn "hypr/hyprland.conf existiert (alte hyprlang-Config). Hyprland nimmt hyprland.lua, solange die da ist."

if [ ${#changed[@]} -eq 0 ] && [ ${#absent[@]} -eq 0 ]; then ok "alle Dateien wie im Repo"; fi
for r in "${changed[@]}"; do warn "veraendert: ~/.config/$r"; done
for r in "${absent[@]}";  do bad  "fehlt:      ~/.config/$r"; done
for r in "${extra[@]}";   do warn "fremd:      ~/.config/$r (nicht aus dem Repo)"; done
echo

echo "== Logs (letzte Zeilen) =="
for l in startmenu island clipboard screenshot record; do
    f="$HOME/.cache/claudes-glassy/$l.log"
    [ -s "$f" ] && { echo "--- $l.log"; tail -n 5 "$f"; }
done
echo

if [ "$REPAIR" = 1 ]; then
    echo "== Reparatur =="
    todo=("${changed[@]}" "${absent[@]}")
    if [ ${#todo[@]} -eq 0 ]; then
        ok "nichts zu reparieren"
    else
        for r in "${todo[@]}"; do
            if [ -e "$HOME/.config/$r" ]; then
                mkdir -p "$SAFE/$(dirname "$r")"
                cp -a "$HOME/.config/$r" "$SAFE/$r"
            fi
            mkdir -p "$HOME/.config/$(dirname "$r")"
            cp -a "$REPO_CFG/$r" "$HOME/.config/$r"
            ok "wiederhergestellt: ~/.config/$r"
        done
        [ -d "$SAFE" ] && echo "   alte Versionen gesichert in: $SAFE"
        chmod +x "$HOME/.config/hypr/scripts/"*.sh 2>/dev/null
        if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            hyprctl reload >/dev/null 2>&1
            pkill -x waybar; setsid -f waybar >/dev/null 2>&1
            pkill -x swaync; setsid -f swaync >/dev/null 2>&1
            pkill -f startmenu.py
            pkill -f clipman.py
            [ -f "$HOME/.config/hypr/glassy-settings.json" ] && python3 "$HOME/.config/hypr/settings/glassy_settings.py" --apply --quiet >/dev/null 2>&1
            "$HOME/.config/hypr/scripts/island.sh" restart
            ok "Sitzung neu geladen"
        fi
    fi
    if [ ${#extra[@]} -gt 0 ]; then
        warn "Fremde Dateien habe ich NICHT geloescht. Wenn du sie nicht brauchst, schau sie dir an:"
        for r in "${extra[@]}"; do echo "     ~/.config/$r"; done
    fi
    echo
else
    if [ ${#changed[@]} -gt 0 ] || [ ${#absent[@]} -gt 0 ]; then
        echo "Reparieren:  bash $HERE/doctor.sh --repair"
    fi
fi
echo "Bericht gespeichert: $OUT"
