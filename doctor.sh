#!/usr/bin/env bash
# ==================================================================
#  claudes-glassy - Doktor: findet kaputte / veraenderte Configs und Lag-Ursachen
#    bash doctor.sh            -> pruefen, Bericht nach ~/glassy-doctor.txt
#    bash doctor.sh --repair   -> veraenderte/fehlende Dateien aus dem Repo
#                                 zurueckholen (alte Versionen werden gesichert)
#  Deine Sachen in ~/.config/hypr/custom/, custom.lua, monitors.lua und die
#  Shell-Einstellungen werden NICHT angefasst.
# ==================================================================
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_CFG="$HERE/config"
OUT="$HOME/glassy-doctor.txt"
STAMP="$(date +%Y%m%d-%H%M%S)"
SAFE="$HOME/.config-backup-catppuccin-glass-$STAMP-doctor"
REPAIR=0; [ "${1:-}" = "--repair" ] && REPAIR=1
SHELL_CONFIG="$HOME/.config/illogical-impulse/config.json"

# Dateien, die dir gehoeren oder automatisch erzeugt werden -> nie "reparieren"
KEEP_RE='^(hypr/custom/|hypr/custom\.lua|hypr/monitors\.lua|hypr/workspaces\.lua|hypr/hyprland/shellOverrides/main\.lua|hypr/hyprland/colors\.lua|hypr/hyprlock/colors\.conf|hypr/glassy-generated\.lua|hypr/custom-defaults/|fuzzel/fuzzel_theme\.ini|kitty/glassy-theme\.conf|illogical-impulse/)'

ok()   { printf '\033[38;2;158;206;106m[ok]\033[0m %s\n' "$*"; }
warn() { printf '\033[38;2;224;175;104m[!!]\033[0m %s\n' "$*"; }
bad()  { printf '\033[38;2;247;118;142m[xx]\033[0m %s\n' "$*"; }

exec > >(tee "$OUT") 2>&1
echo "claudes-glassy Doktor  -  $(date)"
echo "Repo: $HERE ($(git -C "$HERE" rev-parse --short HEAD 2>/dev/null || echo '?'), Kanal $(cat "$HOME/.local/state/claudes-glassy/channel" 2>/dev/null || echo main))"
echo

echo "== Repo-Kopie =="
if [ -d "$HERE/.git" ]; then
    if [ -n "$(git -C "$HERE" status --porcelain 2>/dev/null)" ]; then
        bad "In der Repo-Kopie ($HERE) wurde rumgeschrieben -> Updates bleiben haengen."
        echo "   Fix:  glassy --upgrade"
    fi
    ch="$(cat "$HOME/.local/state/claudes-glassy/channel" 2>/dev/null || echo main)"
    if timeout 8 git -C "$HERE" fetch -q --depth 1 origin "$ch" 2>/dev/null; then
        if [ "$(git -C "$HERE" rev-parse HEAD)" != "$(git -C "$HERE" rev-parse FETCH_HEAD)" ]; then
            bad "Repo-Kopie ist NICHT aktuell (lokal $(git -C "$HERE" rev-parse --short HEAD), GitHub $(git -C "$HERE" rev-parse --short FETCH_HEAD))"
            echo "   Fix:  glassy --upgrade"
        else
            ok "Repo-Kopie ist aktuell ($ch)"
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
    [ -f "$HOME/.config/hypr/hyprland.conf" ] && warn "hypr/hyprland.conf existiert (alte hyprlang-Config). Hyprland nimmt hyprland.lua, solange die da ist."
    # Monitore auf voller Hz-Zahl?
    if command -v jq >/dev/null; then
        hyprctl monitors -j 2>/dev/null | jq -r '.[] | "\(.name) \(.width)x\(.height) @ \(.refreshRate|floor) Hz  (transform \(.transform))"' | while read -r line; do
            hz="$(echo "$line" | sed -E 's/.*@ ([0-9]+) Hz.*/\1/')"
            if [ "${hz:-0}" -le 61 ]; then warn "Monitor $line  <- nur 60 Hz? (mode = \"highrr\" in glassy/monitors.lua)"; else ok "Monitor $line"; fi
        done
    fi
else
    bad "hyprctl nicht gefunden"
fi
echo

echo "== Shell (Quickshell / illogical-impulse) =="
if command -v qs >/dev/null 2>&1; then
    ok "quickshell: $(qs --version 2>/dev/null | head -n1)"
else
    bad "quickshell (qs) fehlt  ->  bash $HERE/install.sh --install"
fi
if pgrep -x qs >/dev/null || pgrep -x quickshell >/dev/null; then
    pid="$(pgrep -x qs | head -n1)"; [ -z "$pid" ] && pid="$(pgrep -x quickshell | head -n1)"
    read -r cpu rss et < <(ps -o %cpu=,rss=,etimes= -p "$pid" 2>/dev/null)
    ok "Shell laeuft (PID $pid, CPU ${cpu:-?}%, RAM $(( ${rss:-0} / 1024 )) MB, seit $(( ${et:-0} / 3600 )) h)"
    if [ "${cpu%.*}" -ge 15 ] 2>/dev/null; then
        warn "Shell braucht viel CPU. Oft: zu viele gespeicherte Mitteilungen oder Live-Vorschau an. SUPER+I -> Glassy -> Performance"
    fi
else
    bad "Shell laeuft NICHT  ->  glassy --reload   (Fehler: glassy --logs)"
fi
for p in hypridle; do pgrep -x "$p" >/dev/null && ok "$p laeuft" || warn "$p laeuft nicht"; done
pgrep -f "wl-paste --type text" >/dev/null && ok "Zwischenablage-Verlauf laeuft" || warn "Zwischenablage-Verlauf laeuft nicht  ->  glassy --reload"
pgrep -f "glassy --watch" >/dev/null && ok "Update-Suche laeuft" || warn "Update-Suche laeuft nicht  ->  glassy --reload"
for p in waybar swaync; do pgrep -x "$p" >/dev/null && warn "$p (claudes-glassy 1) laeuft noch parallel  ->  pkill $p"; done
pgrep -f "startmenu.py --daemon|island/island.py|panel/panel.py|clipman.py" >/dev/null && warn "Alte GTK-Apps von claudes-glassy 1 laufen noch  ->  ab- und wieder anmelden"
VENV="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/.venv"
if [ -x "$VENV/bin/python" ]; then
    if "$VENV/bin/python" -c "import materialyoucolor, PIL" 2>/dev/null; then
        ok "Python-Umgebung da und vollstaendig ($VENV)"
    else
        bad "Python-Umgebung unvollstaendig (Material You geht nicht)  ->  glassy --fix-venv"
    fi
else
    bad "Python-Umgebung fehlt (Material You, KI-Sidebar)  ->  glassy --fix-venv"
fi
fc-list 2>/dev/null | grep -qi "Google Sans Flex" && ok "Schrift Google Sans Flex da" || warn "Schrift Google Sans Flex fehlt (Shell sieht anders aus)"
fc-list 2>/dev/null | grep -qi "Material Symbols" && ok "Icon-Schrift Material Symbols da" || bad "Material Symbols fehlt -> Icons sind Kaestchen  (yay -S ttf-material-symbols-variable-git)"
echo

echo "== Einstellungen / Lag =="
if [ -f "$SHELL_CONFIG" ] && command -v jq >/dev/null; then
    echo "   Theme:            $(jq -r '.glassy.theme // "?"' "$SHELL_CONFIG")"
    echo "   Leisten-Stil:     $(jq -r '.panelFamily // "ii"' "$SHELL_CONFIG")"
    echo "   Performance-Modus: $(jq -r '.glassy.performanceMode // false' "$SHELL_CONFIG")"
    [ "$(jq -r '.glassy.borderAnimation // false' "$SHELL_CONFIG")" = true ] && warn "Rotierender Rahmen ist an (kostet bei 240 Hz GPU)" || ok "Rotierender Rahmen aus"
    [ "$(jq -r '.overview.livePreviews // false' "$SHELL_CONFIG")" = true ] && warn "Live-Vorschau in der Uebersicht ist an (kostet GPU)" || ok "Uebersicht: Standbilder (schnell)"
    n="$(jq 'length' "$HOME/.cache/quickshell/notifications/notifications.json" 2>/dev/null || echo 0)"
    ok "Gespeicherte Mitteilungen: $n (max. $(jq -r '.notifications.maxStored // 60' "$SHELL_CONFIG"))"
else
    warn "Shell-Einstellungen fehlen ($SHELL_CONFIG)  ->  glassy --repair"
fi
[ -f "$HOME/.local/state/quickshell/user/generated/colors.json" ] && ok "Theme-Farben erzeugt" || bad "Theme-Farben fehlen  ->  glassy --theme tokyo"
echo

echo "== Configs im Vergleich zum Repo =="
changed=(); absent=()
while IFS= read -r -d '' f; do
    rel="${f#"$REPO_CFG"/}"
    [[ "$rel" =~ $KEEP_RE ]] && continue
    dst="$HOME/.config/$rel"
    if [ ! -e "$dst" ]; then absent+=("$rel")
    elif ! cmp -s "$f" "$dst"; then changed+=("$rel")
    fi
done < <(find "$REPO_CFG" -type f -not -name '*.pyc' -not -path '*__pycache__*' -print0)
extra=()
for d in hypr/glassy; do
    [ -d "$HOME/.config/$d" ] || continue
    while IFS= read -r -d '' f; do
        rel="${f#"$HOME"/.config/}"
        [ -e "$REPO_CFG/$rel" ] || extra+=("$rel")
    done < <(find "$HOME/.config/$d" -type f -print0)
done
if [ ${#changed[@]} -eq 0 ] && [ ${#absent[@]} -eq 0 ]; then ok "alle Dateien wie im Repo"; fi
for r in "${changed[@]}"; do warn "veraendert: ~/.config/$r"; done
for r in "${absent[@]}";  do bad  "fehlt:      ~/.config/$r"; done
for r in "${extra[@]}";   do warn "fremd:      ~/.config/$r (nicht aus dem Repo)"; done
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
    fi
    python3 "$HOME/.config/quickshell/ii/scripts/colors/glassy_theme.py" defaults "$REPO_CFG/illogical-impulse/glassy-defaults.json" >/dev/null 2>&1
    python3 "$HOME/.config/quickshell/ii/scripts/colors/glassy_theme.py" apply --no-reload >/dev/null 2>&1 && ok "Theme neu angewendet"
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
        "$HOME/.local/bin/glassy" --reload
    fi
    if [ ${#extra[@]} -gt 0 ]; then
        warn "Fremde Dateien habe ich NICHT geloescht:"
        for r in "${extra[@]}"; do echo "     ~/.config/$r"; done
    fi
    echo
else
    if [ ${#changed[@]} -gt 0 ] || [ ${#absent[@]} -gt 0 ]; then
        echo "Reparieren:  glassy --repair"
    fi
fi
echo "Bericht gespeichert: $OUT"
