#!/usr/bin/env bash
# ==================================================================
#  claudes-glassy (Catppuccin Glass) - Installer
#  Ausfuehren mit:  bash install.sh
#  Optionen:
#    bash install.sh            -> Menue
#    bash install.sh --install  -> direkt installieren (fragt nach Backup)
#    bash install.sh --restore  -> Backup wiederherstellen
# ==================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_PREFIX="$HOME/.config-backup-catppuccin-glass-"
BACKUP="${BACKUP_PREFIX}${STAMP}"
DIRS=(hypr waybar rofi swaync kitty)

c_ok()   { printf '\033[38;2;166;227;161m[ok]\033[0m %s\n' "$*"; }
c_info() { printf '\033[38;2;203;166;247m[..]\033[0m %s\n' "$*"; }
c_warn() { printf '\033[38;2;249;226;175m[!!]\033[0m %s\n' "$*"; }
c_err()  { printf '\033[38;2;243;139;168m[xx]\033[0m %s\n' "$*"; }

# ja/nein-Frage; $2 = Standard (j oder n)
ask() {
    local q="$1" def="${2:-n}" hint ans
    [ "$def" = "j" ] && hint="[J/n]" || hint="[j/N]"
    read -r -p "$q $hint " ans
    ans="${ans:-$def}"
    [[ "$ans" =~ ^[jJyY]$ ]]
}

PKGS=(
    hyprland hyprlock hypridle hyprpicker hyprpolkitagent xdg-desktop-portal-hyprland
    waybar rofi swaync kitty
    grim slurp wl-clipboard cliphist jq libnotify playerctl
    pavucontrol network-manager-applet btop xdg-utils
    python-gobject gtk4 gtk4-layer-shell libpulse wf-recorder ffmpeg hyprpicker
    ttf-jetbrains-mono-nerd inter-font papirus-icon-theme
    swaybg
)

# ------------------------------------------------------------------
restart_session() {
    [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
    c_info "Stelle laufende Sitzung um ..."
    for p in qs quickshell waybar swaync mako dunst hypridle; do
        pkill -x "$p" 2>/dev/null || true
    done
    hyprctl reload >/dev/null 2>&1 || true
    sleep 0.5
    setsid -f waybar   >/dev/null 2>&1
    setsid -f swaync   >/dev/null 2>&1
    setsid -f hypridle >/dev/null 2>&1
    setsid -f bash -c 'wl-paste --type text  --watch cliphist store' >/dev/null 2>&1
    setsid -f bash -c 'wl-paste --type image --watch cliphist store' >/dev/null 2>&1
    "$HOME/.config/hypr/scripts/wallpaper.sh" init || true
    pkill -f "startmenu.py --daemon" 2>/dev/null; sleep 0.3      # alte Version beenden
    "$HOME/.config/hypr/scripts/startmenu.sh" --start-daemon || true
    "$HOME/.config/hypr/scripts/island.sh" restart || true
    pkill -f "clipman.py --daemon" 2>/dev/null; "$HOME/.config/hypr/scripts/clipboard.sh" --start-daemon || true
}

# ------------------------------------------------------------------
do_install() {
    echo
    c_info "claudes-glassy wird installiert."
    echo "  Ersetzt: ${DIRS[*]/#/~/.config/}"
    echo

    local make_backup=0
    if ask "Backup deiner aktuellen Configs anlegen? (empfohlen)" j; then
        make_backup=1
        c_info "Backup-Ordner: $BACKUP"
    else
        c_warn "Kein Backup - deine aktuellen Configs werden UEBERSCHRIEBEN."
        ask "Wirklich ohne Backup weitermachen?" n || { c_warn "Abgebrochen."; exit 0; }
    fi

    ask "Pakete installieren/aktualisieren (sudo pacman)?" j && {
        c_info "Installiere Pakete ..."
        sudo pacman -S --needed "${PKGS[@]}"

        if ! command -v awww >/dev/null 2>&1 && ! command -v swww >/dev/null 2>&1; then
            if sudo pacman -S --needed --noconfirm awww 2>/dev/null; then
                c_ok "awww installiert"
            elif sudo pacman -S --needed --noconfirm swww 2>/dev/null; then
                c_ok "swww installiert"
            else
                local aur=""
                command -v paru >/dev/null 2>&1 && aur=paru
                command -v yay  >/dev/null 2>&1 && aur=yay
                if [ -n "$aur" ] && ask "awww (Wallpaper mit Uebergaengen) aus dem AUR mit $aur installieren?" j; then
                    "$aur" -S --needed awww || c_warn "awww-Installation fehlgeschlagen - nutze swaybg."
                else
                    c_warn "Kein awww/swww - nutze swaybg (ohne Uebergaenge). Spaeter:  yay -S awww"
                fi
            fi
        fi
    }

    # Backup oder entfernen
    if [ "$make_backup" = 1 ]; then
        mkdir -p "$BACKUP"
        for d in "${DIRS[@]}"; do
            if [ -e "$HOME/.config/$d" ]; then
                mv "$HOME/.config/$d" "$BACKUP/"
                c_ok "gesichert: ~/.config/$d"
            fi
        done
        if [ -e "$HOME/.config/quickshell" ]; then
            cp -a "$HOME/.config/quickshell" "$BACKUP/"
            c_ok "kopiert (bleibt liegen): ~/.config/quickshell"
        fi
    else
        for d in "${DIRS[@]}"; do
            rm -rf "$HOME/.config/$d"
        done
    fi

    # Neue Configs
    mkdir -p "$HOME/.config"
    for d in "${DIRS[@]}"; do
        cp -a "$HERE/config/$d" "$HOME/.config/$d"
        c_ok "installiert: ~/.config/$d"
    done
    chmod +x "$HOME/.config/hypr/scripts/"*.sh
    mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots"

    # Mitgelieferte Wallpaper (eigener Unterordner, ueberschreibt nichts von dir)
    mkdir -p "$HOME/Pictures/Wallpapers/claudes-glassy"
    cp -n "$HERE/wallpapers/"*.jpg "$HOME/Pictures/Wallpapers/claudes-glassy/" 2>/dev/null || true
    c_ok "Wallpaper: ~/Pictures/Wallpapers/claudes-glassy"

    # Avatar fuer den Sperrbildschirm: ~/.face wenn vorhanden, sonst Standardbild
    if [ -f "$HOME/.face" ]; then
        ln -sfn "$HOME/.face" "$HOME/.config/hypr/avatar.png"
        c_ok "Avatar: ~/.face"
    else
        cp "$HERE/assets/avatar.png" "$HOME/.config/hypr/avatar.png"
        c_info "Avatar: Standardbild (eigenes Bild als ~/.face ablegen und Installer erneut starten)"
    fi

    # Erstes Wallpaper setzen, damit auch der Sperrbildschirm eins hat
    mkdir -p "$HOME/.cache/claudes-glassy"
    [ -f "$HOME/.cache/claudes-glassy/wallpaper-path" ] || \
        echo "$HOME/Pictures/Wallpapers/claudes-glassy/01-aurora.jpg" > "$HOME/.cache/claudes-glassy/wallpaper-path" 2>/dev/null || true
    ln -sfn "$(cat "$HOME/.cache/claudes-glassy/wallpaper-path")" "$HOME/.cache/claudes-glassy/wallpaper" 2>/dev/null || true

    [ -f "$HOME/.config/hypr/custom.lua" ] || cat > "$HOME/.config/hypr/custom.lua" <<'EOF'
-- Eigene Ergaenzungen. Diese Datei wird am Ende von hyprland.lua geladen.
-- Beispiel:
-- hl.bind("SUPER + G", hl.dsp.exec_cmd("steam"))
EOF

    restart_session

    echo
    c_ok "Fertig."
    echo "  - Wallpaper: SUPER+W (Auswahl), SUPER+SHIFT+W (zufaellig). Eigene Bilder nach ~/Pictures/Wallpapers"
    echo "  - Strg+Alt+Entf: Sitzungs-Bildschirm  |  Super antippen: Launcher  |  Strg+Super+Pfeile: Workspace"
    echo "  - Monitore pruefen:  hyprctl monitors   (Abschnitt MONITORE in ~/.config/hypr/hyprland.lua)"
    if [ "$make_backup" = 1 ]; then
        echo "  - Zurueck zum alten Setup:  bash $HERE/install.sh --restore"
    fi
    echo "  - Am saubersten: einmal ab- und wieder anmelden."
}

# ------------------------------------------------------------------
do_restore() {
    local backups=()
    mapfile -t backups < <(ls -d "${BACKUP_PREFIX}"* 2>/dev/null | sort -r)

    if [ "${#backups[@]}" -eq 0 ]; then
        c_err "Keine Backups gefunden (${BACKUP_PREFIX}*)."
        exit 1
    fi

    echo
    c_info "Vorhandene Backups (neuestes zuerst):"
    local i=1
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
        local safety="${BACKUP_PREFIX}${STAMP}-vor-restore"
        mkdir -p "$safety"
        for d in "${DIRS[@]}"; do
            [ -e "$HOME/.config/$d" ] && cp -a "$HOME/.config/$d" "$safety/"
        done
        c_ok "Aktueller Stand gesichert: $safety"
    }

    for d in "${DIRS[@]}" quickshell; do
        if [ -e "$src/$d" ]; then
            rm -rf "$HOME/.config/$d"
            cp -a "$src/$d" "$HOME/.config/$d"
            c_ok "wiederhergestellt: ~/.config/$d"
        elif [ "$d" != quickshell ]; then
            # war vor der Installation nicht vorhanden -> entfernen
            rm -rf "$HOME/.config/$d"
            c_info "entfernt (gab es vorher nicht): ~/.config/$d"
        fi
    done

    for p in waybar swaync; do pkill -x "$p" 2>/dev/null || true; done
    echo
    c_ok "Wiederhergestellt aus $(basename "$src")."
    echo "  Jetzt ab- und wieder anmelden, damit dein altes Setup (z. B. end-4/Quickshell) startet."
}

# ------------------------------------------------------------------
case "${1:-}" in
    --install|-i) do_install ;;
    --restore|-r) do_restore ;;
    "")
        echo
        echo "  claudes-glassy  -  Catppuccin Glass fuer Hyprland"
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
        echo "Benutzung: bash install.sh [--install | --restore]"
        exit 1
        ;;
esac
