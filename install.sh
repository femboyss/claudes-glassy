#!/usr/bin/env bash
# ==================================================================
#  claudes-glassy 2 - Installer
#  Hyprland + Quickshell-Shell (illogical-impulse von end-4) im Glassy-Look
#
#  Ausfuehren mit:  bash install.sh
#  Optionen:
#    bash install.sh              -> Menue
#    bash install.sh --install    -> direkt installieren (fragt nach Backup)
#    bash install.sh --auto       -> ohne Fragen (fuer "glassy --update" / "glassy --debug")
#    bash install.sh --background -> ohne Fragen, ohne Pakete/sudo (Auto-Update)
#    bash install.sh --restore    -> Backup wiederherstellen
#    bash install.sh --deploy [install|upgrade|fix]
#                                 -> aus dem Vitra-Paket (/usr/share/glassy) in dein ~/.config
#                                    kopieren, ohne Pakete/sudo. Ruft vtx nach Installation/Update auf.
# ==================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_PREFIX="$HOME/.config-backup-catppuccin-glass-"
BACKUP="${BACKUP_PREFIX}${STAMP}"
CFG="$HOME/.config"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
VENV="$XDG_STATE_HOME/quickshell/.venv"

# Ordner, die komplett von claudes-glassy kommen (werden ersetzt)
DIRS=(hypr kitty matugen fuzzel)
# Reste von claudes-glassy 1 (Waybar & Co.) - werden mit ins Backup verschoben
OLD_DIRS=(waybar rofi swaync)
# Dateien/Ordner, die DIR gehoeren: werden bei Updates nie ueberschrieben
USER_FILES=(
    hypr/custom
    hypr/custom.lua
    hypr/monitors.lua
    hypr/workspaces.lua
    hypr/hyprland/shellOverrides/main.lua
    hypr/avatar.png
    hypr/xdph.conf
)
SHELL_CONFIG="$CFG/illogical-impulse/config.json"
THEME_PY="$CFG/quickshell/ii/scripts/colors/glassy_theme.py"

c_ok()   { printf '\033[38;2;158;206;106m[ok]\033[0m %s\n' "$*"; }
c_info() { printf '\033[38;2;122;162;247m[..]\033[0m %s\n' "$*"; }
c_warn() { printf '\033[38;2;224;175;104m[!!]\033[0m %s\n' "$*"; }
c_err()  { printf '\033[38;2;247;118;142m[xx]\033[0m %s\n' "$*"; }

AUTO=0
SKIP_PKGS=0     # --background: Pakete auslassen (kein sudo moeglich)
DEPLOY=""       # --deploy: install | upgrade | fix  (Vitra-Paket, Pakete kommen von pacman)
ask() {         # ja/nein-Frage; $2 = Standard (j oder n)
    local q="$1" def="${2:-n}" hint ans
    if [ "$AUTO" = 1 ]; then
        echo "$q -> $( [ "$def" = j ] && echo ja || echo nein ) (automatisch)"
        [ "$def" = j ]
        return
    fi
    [ "$def" = "j" ] && hint="[J/n]" || hint="[j/N]"
    read -r -p "$q $hint " ans
    ans="${ans:-$def}"
    [[ "$ans" =~ ^[jJyY]$ ]]
}

# Zusaetzlich zu den illogical-impulse-Paketen (deps/arch)
EXTRA_PKGS=(
    git jq python libnotify xdg-utils
    plasma-integration qt6ct papirus-icon-theme inter-font ttf-jetbrains-mono-nerd
    bluez bluez-utils grim
)

# ------------------------------------------------------------------ Pakete
install_yay() {
    c_info "yay (AUR-Helfer) wird installiert ..."
    sudo pacman -S --needed --noconfirm base-devel git
    local tmp; tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
    (cd "$tmp/yay-bin" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

# Wie bei illogical-impulse: Meta-PKGBUILDs bauen, deren Abhaengigkeiten per yay holen
install_metapkg() {
    local dir="$1" flags=(--needed --asdeps --sudoloop)
    [ "$AUTO" = 1 ] && flags+=(--noconfirm)
    (
        set +u
        cd "$dir"
        # shellcheck disable=SC1091
        source ./PKGBUILD
        if [ "${#depends[@]}" -gt 0 ]; then
            yay -S "${flags[@]}" "${depends[@]}"
        fi
        makepkg -Afsi --noconfirm --needed
    )
}

install_packages() {
    command -v pacman >/dev/null 2>&1 || { c_err "Kein pacman - claudes-glassy ist fuer Arch Linux."; return 1; }
    command -v yay >/dev/null 2>&1 || install_yay

    c_info "System aktualisieren (Hyprland und Quickshell muessen zusammenpassen) ..."
    if [ "$AUTO" = 1 ]; then sudo pacman -Syu --noconfirm; else sudo pacman -Syu; fi

    c_info "Installiere Pakete der Shell (das dauert beim ersten Mal, Quickshell wird gebaut) ..."
    local build; build="$(mktemp -d)"
    cp -a "$HERE/deps/arch/." "$build/"
    local metas=(audio backlight basic fonts-themes kde portal python screencapture toolkit widgets hyprland
                 microtex-git quickshell-git bibata-modern-classic-bin)
    local m
    for m in "${metas[@]}"; do
        # Schon installiert und Version gleich -> nicht neu bauen (spart vor allem den Quickshell-Build)
        local want have
        want="$(cd "$build/illogical-impulse-$m" && set +u && source ./PKGBUILD && echo "${pkgver}-${pkgrel}")"
        have="$(pacman -Q "illogical-impulse-$m" 2>/dev/null | awk '{print $2}')"
        if [ -n "$have" ] && [ "${have#*:}" = "$want" ]; then
            c_ok "  illogical-impulse-$m schon aktuell"
            continue
        fi
        c_info "  illogical-impulse-$m"
        install_metapkg "$build/illogical-impulse-$m" || c_warn "  illogical-impulse-$m: Fehler (weiter mit dem Rest)"
    done
    rm -rf "$build"

    # Darkly (Qt-Stil): Dolphin & Co. durchsichtig mit Blur. Fehlt manchmal trotz Metapaket.
    if ! pacman -Q darkly-bin >/dev/null 2>&1 && ! pacman -Q darkly >/dev/null 2>&1; then
        c_info "  darkly-bin (Glas-Look fuer Dolphin, Kate, Ark ...)"
        if [ "$AUTO" = 1 ]; then yay -S --needed --noconfirm darkly-bin; else yay -S --needed darkly-bin; fi \
            || c_warn "  darkly-bin: Fehler (Qt-Apps bleiben deckend)"
    fi

    if [ "$AUTO" = 1 ]; then
        sudo pacman -S --needed --noconfirm "${EXTRA_PKGS[@]}"
    else
        sudo pacman -S --needed "${EXTRA_PKGS[@]}"
    fi
    c_ok "Pakete fertig"
}

# Einmalige System-Einstellungen (brauchen sudo)
setup_system() {
    c_info "System-Einstellungen (Gruppen, Dienste) ..."
    getent group i2c >/dev/null || sudo groupadd i2c
    sudo usermod -aG video,i2c,input "$(whoami)" || true
    echo i2c-dev | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null || true
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
        systemctl --user enable --now ydotool >/dev/null 2>&1 || true
    fi
    sudo systemctl enable --now bluetooth >/dev/null 2>&1 || true
    c_ok "Gruppen video/i2c/input, ydotool, Bluetooth (Gruppen gelten ab dem naechsten Login)"
}

# Python-Umgebung fuer Farb-Erzeugung, KI-Seitenleiste & Co.
setup_venv() {
    if ! command -v uv >/dev/null 2>&1; then
        c_warn "uv fehlt - Python-Umgebung uebersprungen (sudo pacman -S uv, dann Installer nochmal)"
        return 0
    fi
    c_info "Python-Umgebung: $VENV"
    mkdir -p "$VENV"
    UV_NO_MODIFY_PATH=1 uv venv --allow-existing --prompt .venv "$VENV" -p 3.12 >/dev/null 2>&1 \
        || UV_NO_MODIFY_PATH=1 uv venv --prompt .venv "$VENV" -p 3.12 >/dev/null 2>&1 || true
    if [ -x "$VENV/bin/python" ]; then
        VIRTUAL_ENV="$VENV" uv pip install --python "$VENV/bin/python" -q -r "$HERE/deps/uv/requirements.txt" \
            && c_ok "Python-Umgebung fertig" || c_warn "Python-Pakete: Fehler (Material You / Farb-Erzeugung evtl. kaputt)"
    else
        c_warn "Python-Umgebung konnte nicht erstellt werden"
    fi
}

install_fonts() {
    if fc-list 2>/dev/null | grep -qi "Google Sans Flex"; then return 0; fi
    c_info "Schrift Google Sans Flex ..."
    local dst="$HOME/.local/share/fonts/illogical-impulse-google-sans-flex" tmp
    tmp="$(mktemp -d)"
    if git clone --depth 1 https://github.com/end-4/google-sans-flex "$tmp/gsf" >/dev/null 2>&1; then
        mkdir -p "$dst"
        find "$tmp/gsf" -type f \( -iname '*.ttf' -o -iname '*.otf' \) -exec cp {} "$dst/" \;
        fc-cache -f >/dev/null 2>&1 || true
        c_ok "Google Sans Flex installiert"
    else
        c_warn "Google Sans Flex nicht ladbar (kein Netz?) - Shell nimmt eine Ersatzschrift"
    fi
    rm -rf "$tmp"
}

# ------------------------------------------------------------------ laufende Sitzung umstellen
restart_session() {
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
    c_info "Stelle laufende Sitzung um ..."
    # claudes-glassy 1 (GTK-Apps, Waybar) beenden
    for p in waybar swaync mako dunst hypridle; do pkill -x "$p" 2>/dev/null || true; done
    pkill -f "startmenu.py --daemon" 2>/dev/null || true
    pkill -f "island/island.py" 2>/dev/null || true
    pkill -f "clipman.py --daemon" 2>/dev/null || true
    pkill -f "panel/panel.py" 2>/dev/null || true
    # Shell neu
    pkill -x qs 2>/dev/null || true
    pkill -x quickshell 2>/dev/null || true
    hyprctl reload >/dev/null 2>&1 || true
    systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal >/dev/null 2>&1 || true
    sleep 0.5
    setsid -f qs -c ii </dev/null >/dev/null 2>&1 || true
    "$HOME/.local/bin/glassy" --idle-start >/dev/null 2>&1 || true   # hypridle nur, wenn autoIdle an ist
    pkill -f "wl-paste --type" 2>/dev/null || true
    setsid -f bash -c 'wl-paste --type text --watch cliphist -max-items 400 store' </dev/null >/dev/null 2>&1
    setsid -f bash -c "wl-paste --type image --watch bash -c 'cliphist -max-items 400 store && qs -c ii ipc call cliphistService update'" </dev/null >/dev/null 2>&1
    pgrep -f "glassy --watch" >/dev/null || setsid -f "$HOME/.local/bin/glassy" --watch </dev/null >/dev/null 2>&1 || true
    c_ok "Fertig - alles installiert und neu gestartet. Das Terminal kannst du jetzt schliessen."
}

# ------------------------------------------------------------------ "glassy"-Befehl
install_cli() {
    mkdir -p "$HOME/.local/bin"
    if [ -n "$DEPLOY" ] && [ -x /usr/bin/glassy ]; then
        # Vitra-Paket: der Befehl kommt von pacman, ~/.local/bin/glassy zeigt nur darauf
        ln -sfn /usr/bin/glassy "$HOME/.local/bin/glassy"
    else
        install -m 755 "$HERE/bin/glassy" "$HOME/.local/bin/glassy"
    fi
    if command -v fish >/dev/null 2>&1; then
        fish -c 'contains $HOME/.local/bin $fish_user_paths; or fish_add_path -U $HOME/.local/bin' 2>/dev/null || true
    fi
    if ! grep -qs 'claudes-glassy: ~/.local/bin' "$HOME/.bashrc"; then
        printf '\n# claudes-glassy: ~/.local/bin in den PATH (fuer den Befehl "glassy")\ncase ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac\n' >> "$HOME/.bashrc"
    fi
    c_ok "Befehl installiert:  glassy --help"
}

# ------------------------------------------------------------------ Installation
do_install() {
    echo
    c_info "claudes-glassy 2 wird installiert (Quickshell-Shell im Glassy-Look)."
    echo "  Ersetzt: ${DIRS[*]/#/~/.config/} ~/.config/quickshell/ii"
    echo "  Deine Shell-Einstellungen (~/.config/illogical-impulse/config.json) bleiben, Glassy ergaenzt nur."
    echo

    local make_backup=0
    if [ -n "$DEPLOY" ] && [ "$DEPLOY" != install ]; then
        # Update/Reparatur aus dem Paket: deine Dateien (custom/, Monitore ...) bleiben eh,
        # sonst entstuende bei jedem Update ein neuer Backup-Ordner
        c_info "Paket-Update ($DEPLOY): kein Backup noetig, deine eigenen Dateien bleiben"
    elif ask "Backup deiner aktuellen Configs anlegen? (empfohlen)" j; then
        make_backup=1
        c_info "Backup-Ordner: $BACKUP"
    else
        c_warn "Kein Backup - deine aktuellen Configs werden UEBERSCHRIEBEN."
        ask "Wirklich ohne Backup weitermachen?" n || { c_warn "Abgebrochen."; exit 0; }
    fi

    if [ "$SKIP_PKGS" = 0 ] && ask "Pakete installieren/aktualisieren (pacman + AUR mit yay, baut Quickshell)?" j; then
        install_packages
        ask "System-Einstellungen setzen (Gruppen video/i2c/input, ydotool, Bluetooth)?" j && setup_system
    fi

    # Deine eigenen Dateien merken - die bleiben bei jedem Update erhalten
    local keep; keep="$(mktemp -d)"
    local f
    for f in "${USER_FILES[@]}"; do
        if [ -e "$CFG/$f" ]; then
            mkdir -p "$keep/$(dirname "$f")"
            cp -a "$CFG/$f" "$keep/$f"
        fi
    done

    # Backup oder entfernen
    local d
    if [ "$make_backup" = 1 ]; then
        mkdir -p "$BACKUP"
        for d in "${DIRS[@]}" "${OLD_DIRS[@]}"; do
            if [ -e "$CFG/$d" ]; then
                mv "$CFG/$d" "$BACKUP/"
                c_ok "gesichert: ~/.config/$d"
            fi
        done
        for d in quickshell illogical-impulse; do
            if [ -e "$CFG/$d" ]; then
                cp -a "$CFG/$d" "$BACKUP/"
                c_ok "kopiert (bleibt liegen): ~/.config/$d"
            fi
        done
        [ -f "$CFG/gtk-3.0/gtk.css" ] && { mkdir -p "$BACKUP/gtk-3.0"; cp -a "$CFG/gtk-3.0/gtk.css" "$BACKUP/gtk-3.0/"; }
        [ -f "$CFG/gtk-4.0/gtk.css" ] && { mkdir -p "$BACKUP/gtk-4.0"; cp -a "$CFG/gtk-4.0/gtk.css" "$BACKUP/gtk-4.0/"; }
    else
        for d in "${DIRS[@]}"; do rm -rf "${CFG:?}/$d"; done
    fi

    # Neue Configs
    mkdir -p "$CFG/quickshell"
    for d in "${DIRS[@]}"; do
        cp -a "$HERE/config/$d" "$CFG/$d"
        c_ok "installiert: ~/.config/$d"
    done
    rm -rf "$CFG/quickshell/ii"
    cp -a "$HERE/config/quickshell/ii" "$CFG/quickshell/ii"
    c_ok "installiert: ~/.config/quickshell/ii (illogical-impulse + Glassy-Patches)"
    # Portale (Bildschirm teilen) - nur diese eine Datei, Rest von dir bleibt
    mkdir -p "$CFG/xdg-desktop-portal"
    if [ -f "$CFG/xdg-desktop-portal/hyprland-portals.conf" ] && [ "$make_backup" = 1 ]; then
        mkdir -p "$BACKUP/xdg-desktop-portal"
        cp -a "$CFG/xdg-desktop-portal/hyprland-portals.conf" "$BACKUP/xdg-desktop-portal/"
    fi
    cp "$HERE/config/xdg-desktop-portal/hyprland-portals.conf" "$CFG/xdg-desktop-portal/"
    c_ok "installiert: ~/.config/xdg-desktop-portal/hyprland-portals.conf (Bildschirm teilen)"
    rm -rf "$CFG/hypr/custom-defaults"

    # eigene Dateien zurueck
    local restored=0
    for f in "${USER_FILES[@]}"; do
        if [ -e "$keep/$f" ]; then
            mkdir -p "$CFG/$(dirname "$f")"
            rm -rf "${CFG:?}/$f"
            cp -a "$keep/$f" "$CFG/$f"
            restored=$((restored + 1))
        fi
    done
    rm -rf "$keep"
    [ "$restored" -gt 0 ] && c_ok "deine eigenen Dateien behalten ($restored: custom/, custom.lua, Monitore ...)"

    # Ordner fuer eigene Ergaenzungen (wie bei illogical-impulse)
    mkdir -p "$CFG/hypr/custom/scripts"
    for f in env execs general keybinds rules variables; do
        [ -f "$CFG/hypr/custom/$f.lua" ] || printf -- '-- Eigene Ergaenzungen (%s). Wird bei Updates nie ueberschrieben.\n-- Beispiele: ~/.config/hypr/glassy/%s.lua\n' "$f" "$f" > "$CFG/hypr/custom/$f.lua"
    done
    [ -f "$CFG/hypr/custom/scripts/__restore_video_wallpaper.sh" ] || \
        install -m 755 "$HERE/config/hypr/custom-defaults/scripts/__restore_video_wallpaper.sh" "$CFG/hypr/custom/scripts/"
    [ -f "$CFG/hypr/hyprland/shellOverrides/main.lua" ] || cp "$HERE/config/hypr/hyprland/shellOverrides/main.lua" "$CFG/hypr/hyprland/shellOverrides/main.lua"
    find "$CFG/hypr/hyprland/scripts" "$CFG/quickshell/ii/scripts" -type f \( -name '*.sh' -o -name '*.py' \) -exec chmod +x {} + 2>/dev/null || true

    # Mitgelieferte Wallpaper (eigener Unterordner, ueberschreibt nichts von dir)
    mkdir -p "$HOME/Pictures/Wallpapers/claudes-glassy" "$HOME/Pictures/Screenshots"
    cp -n "$HERE/wallpapers/"*.jpg "$HOME/Pictures/Wallpapers/claudes-glassy/" 2>/dev/null || true
    c_ok "Wallpaper: ~/Pictures/Wallpapers/claudes-glassy (SUPER+W)"

    # Avatar (Sperrbildschirm / Seitenleiste nehmen ~/.face)
    if [ ! -e "$HOME/.face" ] && [ -f "$HERE/assets/avatar.png" ]; then
        cp "$HERE/assets/avatar.png" "$HOME/.face"
    fi

    # Shell-Einstellungen: Glassy-Standardwerte ergaenzen.
    # Kommst du von end-4 (noch kein "glassy"-Eintrag), werden die Glassy-Werte einmal gesetzt.
    mkdir -p "$CFG/illogical-impulse"
    local force=""
    if [ ! -s "$SHELL_CONFIG" ] || ! jq -e '.glassy' "$SHELL_CONFIG" >/dev/null 2>&1; then
        force="--force"
        [ -s "$SHELL_CONFIG" ] && cp -a "$SHELL_CONFIG" "$SHELL_CONFIG.vor-glassy-$STAMP"
    fi
    python3 "$THEME_PY" defaults "$HERE/config/illogical-impulse/glassy-defaults.json" $force \
        && c_ok "Shell-Einstellungen: Glassy-Werte $( [ -n "$force" ] && echo gesetzt || echo ergaenzt)"

    if [ "$SKIP_PKGS" = 0 ]; then
        install_fonts
        # Python-Umgebung: bei automatischen Updates nur, wenn sie noch fehlt
        if [ "$AUTO" = 0 ] || [ ! -x "$VENV/bin/python" ]; then setup_venv; fi
    elif [ -n "$DEPLOY" ]; then
        # Vitra-Paket: Schrift und Python-Umgebung sind pro Benutzer, nur wenn sie fehlen
        install_fonts
        if [ "$DEPLOY" = fix ] || [ ! -x "$VENV/bin/python" ]; then setup_venv; fi
    fi

    install_cli

    # Theme-Farben erzeugen (Shell, GTK, Terminal, Rahmen, hyprlock, fuzzel)
    python3 "$THEME_PY" apply --no-reload >/dev/null 2>&1 \
        && c_ok "Theme: $(python3 "$THEME_PY" current 2>/dev/null)" \
        || c_warn "Theme konnte nicht angewendet werden (glassy --theme zeigt mehr)"

    gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    gsettings set org.gnome.desktop.interface font-name 'Google Sans Flex Medium 11 @opsz=11,wght=500' 2>/dev/null || true

    restart_session

    echo
    c_ok "Fertig."
    echo "  - Super antippen: Startmenue/Suche  |  SUPER+Tab: Uebersicht  |  SUPER+A: Schnelleinstellungen"
    echo "  - SUPER+K: KI-Seitenleiste  |  SUPER+I: Einstellungen (Theme unter 'Glassy')  |  SUPER+H: alle Kuerzel"
    echo "  - Monitore pruefen:  hyprctl monitors   (~/.config/hypr/glassy/monitors.lua)"
    [ "$make_backup" = 1 ] && echo "  - Zurueck zum alten Setup:  glassy --restore"
    echo "  - Am saubersten: einmal ab- und wieder anmelden."
}

# ------------------------------------------------------------------ Wiederherstellen
do_restore() {
    local backups=()
    mapfile -t backups < <(ls -d "${BACKUP_PREFIX}"* 2>/dev/null | sort -r)

    if [ "${#backups[@]}" -eq 0 ]; then
        c_err "Keine Backups gefunden (${BACKUP_PREFIX}*)."
        exit 1
    fi

    echo
    c_info "Vorhandene Backups (neuestes zuerst):"
    local i=1 b
    for b in "${backups[@]}"; do
        printf '  %d) %s  [%s]\n' "$i" "$(basename "$b")" "$(ls "$b" | tr '\n' ' ')"
        i=$((i + 1))
    done
    echo
    local sel
    read -r -p "Welches wiederherstellen? [1] " sel
    sel="${sel:-1}"
    if ! [[ "$sel" =~ ^[0-9]+$ ]] || [ "$sel" -lt 1 ] || [ "$sel" -gt "${#backups[@]}" ]; then
        c_err "Ungueltige Auswahl."; exit 1
    fi
    local src="${backups[$((sel - 1))]}"

    ask "Aktuelle Configs vorher selbst nochmal sichern?" j && {
        local safety="${BACKUP_PREFIX}${STAMP}-vor-restore" d
        mkdir -p "$safety"
        for d in "${DIRS[@]}" quickshell illogical-impulse; do
            [ -e "$CFG/$d" ] && cp -a "$CFG/$d" "$safety/"
        done
        c_ok "Aktueller Stand gesichert: $safety"
    }

    local d
    for d in "${DIRS[@]}" "${OLD_DIRS[@]}" quickshell illogical-impulse gtk-3.0/gtk.css gtk-4.0/gtk.css xdg-desktop-portal/hyprland-portals.conf; do
        if [ -e "$src/$d" ]; then
            rm -rf "${CFG:?}/$d"
            mkdir -p "$(dirname "$CFG/$d")"
            cp -a "$src/$d" "$CFG/$d"
            c_ok "wiederhergestellt: ~/.config/$d"
        elif [[ " ${DIRS[*]} " == *" $d "* ]]; then
            rm -rf "${CFG:?}/$d"
            c_info "entfernt (gab es vorher nicht): ~/.config/$d"
        fi
    done

    pkill -x qs 2>/dev/null || true
    echo
    c_ok "Wiederhergestellt aus $(basename "$src")."
    echo "  Jetzt ab- und wieder anmelden, damit dein altes Setup startet."
}

# ------------------------------------------------------------------
case "${1:-}" in
    --install|-i) do_install ;;
    --auto)       AUTO=1; do_install ;;
    --background) AUTO=1; SKIP_PKGS=1; do_install ;;
    --deploy)     AUTO=1; SKIP_PKGS=1; DEPLOY="${2:-upgrade}"
                  case "$DEPLOY" in install|upgrade|fix) ;; *) c_err "--deploy install|upgrade|fix"; exit 1 ;; esac
                  do_install ;;
    --restore|-r) do_restore ;;
    "")
        echo
        echo "  claudes-glassy 2  -  Glas-Look fuer Hyprland mit Quickshell"
        echo
        echo "  1) Installieren"
        echo "  2) Backup wiederherstellen"
        echo "  3) Abbrechen"
        echo
        read -r -p "Auswahl [1] " choice
        case "${choice:-1}" in
            1) do_install ;;
            2) do_restore ;;
            *) c_warn "Abgebrochen." ;;
        esac
        ;;
    *)
        echo "Benutzung: bash install.sh [--install | --auto | --restore | --deploy [install|upgrade|fix]]"
        exit 1
        ;;
esac
