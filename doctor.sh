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
KEEP_RE='(hypr/custom\.lua|hypr/pinned-apps|hypr/avatar\.png|hypr/startmenu/settings\.json)$'

ok()   { printf '\033[38;2;158;206;106m[ok]\033[0m %s\n' "$*"; }
warn() { printf '\033[38;2;224;175;104m[!!]\033[0m %s\n' "$*"; }
bad()  { printf '\033[38;2;247;118;142m[xx]\033[0m %s\n' "$*"; }

exec > >(tee "$OUT") 2>&1
echo "claudes-glassy Doktor  -  $(date)"
echo "Repo: $HERE ($(git -C "$HERE" rev-parse --short HEAD 2>/dev/null || echo '?'))"
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
pgrep -x qs >/dev/null || pgrep -x quickshell >/dev/null && warn "Quickshell (end-4) laeuft noch parallel"
echo

echo "== Pakete =="
missing=()
for p in hyprland hyprlock hypridle waybar rofi swaync kitty grim slurp wl-clipboard cliphist jq playerctl \
         python-gobject gtk4 gtk4-layer-shell libpulse ttf-jetbrains-mono-nerd inter-font papirus-icon-theme; do
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
for d in hypr/glassy hypr/scripts hypr/startmenu hypr/island waybar rofi swaync; do
    [ -d "$HOME/.config/$d" ] || continue
    while IFS= read -r -d '' f; do
        rel="${f#$HOME/.config/}"
        [[ "$rel" =~ $KEEP_RE ]] && continue
        [ -e "$REPO_CFG/$rel" ] || extra+=("$rel")
    done < <(find "$HOME/.config/$d" -type f -not -name '*.pyc' -not -path '*__pycache__*' -print0)
done
[ -f "$HOME/.config/hypr/hyprland.conf" ] && warn "hypr/hyprland.conf existiert (alte hyprlang-Config). Hyprland nimmt hyprland.lua, solange die da ist."

if [ ${#changed[@]} -eq 0 ] && [ ${#absent[@]} -eq 0 ]; then ok "alle Dateien wie im Repo"; fi
for r in "${changed[@]}"; do warn "veraendert: ~/.config/$r"; done
for r in "${absent[@]}";  do bad  "fehlt:      ~/.config/$r"; done
for r in "${extra[@]}";   do warn "fremd:      ~/.config/$r (nicht aus dem Repo)"; done
echo

echo "== Logs (letzte Zeilen) =="
for l in startmenu island screenshot; do
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
