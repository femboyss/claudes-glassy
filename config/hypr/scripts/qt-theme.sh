#!/usr/bin/env bash
# claudes-glassy: Farbschema fuer Qt/KDE-Apps (Dolphin, Kate, Ark, Gwenview ...)
#   qt-theme.sh apply     Farben des aktiven glassy-Themes setzen
#   qt-theme.sh restore   vorheriges Farbschema zurueck (Backup von vor dem ersten apply)
# Aendert ~/.config/kdeglobals - vorher wird einmalig ein Backup gemacht.
SCHEMES="$HOME/.local/share/color-schemes"
SCHEME="$SCHEMES/Glassy.colors"
KG="$HOME/.config/kdeglobals"
BAK="$HOME/.config/kdeglobals.glassy-backup"
QUIET=0; [ "$2" = "--quiet" ] && QUIET=1
say() { [ "$QUIET" = 1 ] || echo "$@"; }

case "${1:-apply}" in
    apply)
        if [ ! -f "$SCHEME" ]; then
            python3 "$HOME/.config/hypr/theme/theme.py" apply --no-reload >/dev/null 2>&1
            exit 0     # theme.py ruft uns danach selbst wieder auf
        fi
        if [ ! -f "$BAK" ]; then
            if [ -f "$KG" ]; then cp -a "$KG" "$BAK"; else : > "$BAK"; fi
        fi
        # Farbgruppen direkt in kdeglobals eintragen (geht ohne Plasma; plasma-apply-colorscheme
        # erkennt ein geaendertes Schema mit gleichem Namen nicht immer)
        python3 - "$KG" "$SCHEME" <<'PY'
import re, sys
kg, scheme = sys.argv[1], sys.argv[2]

def groups(text):
    out, name, lines = [], None, []
    for line in text.splitlines():
        m = re.match(r"^\[(.+)\]\s*$", line)
        if m:
            if name is not None or lines:
                out.append((name, lines))
            name, lines = m.group(1), []
        else:
            lines.append(line)
    out.append((name, lines))
    return out

try:
    cur = open(kg, encoding="utf-8").read()
except OSError:
    cur = ""
new = groups(open(scheme, encoding="utf-8").read())
replace = {n for n, _ in new if n and (n.startswith("Colors:") or n.startswith("ColorEffects:") or n == "WM")}
kept = [(n, l) for n, l in groups(cur) if n not in replace]
gen = next((l for n, l in kept if n == "General"), None)
if gen is None:
    kept.append(("General", []))
    gen = kept[-1][1]
gen[:] = [x for x in gen if not x.startswith("ColorScheme=")] + ["ColorScheme=Glassy"]
res = []
for n, l in kept + [(n, l) for n, l in new if n in replace]:
    body = [x for x in l if x.strip()]
    if n is None:
        res += body
    else:
        res.append(f"[{n}]")
        res += body
        res.append("")
open(kg, "w", encoding="utf-8").write("\n".join(res).rstrip() + "\n")
PY
        say "Farben fuer Qt/KDE-Apps gesetzt. Offene Apps (z. B. Dolphin) einmal neu starten."
        ;;
    restore)
        if [ -f "$BAK" ]; then
            if [ -s "$BAK" ]; then cp -a "$BAK" "$KG"; else rm -f "$KG"; fi
            rm -f "$BAK"
            say "Vorheriges Farbschema wiederhergestellt."
        else
            say "Kein Backup vorhanden - nichts zu tun."
        fi
        ;;
esac
