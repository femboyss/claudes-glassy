#!/usr/bin/env bash
# ==================================================================
#  Catppuccin Glass - Installer
#  Ausfuehren mit:  bash install.sh
#  - sichert deine alten Configs nach ~/.config-backup-catppuccin-glass-<datum>
#  - installiert die Pakete (pacman, --needed)
#  - kopiert die neuen Configs und startet Bar & Co. neu
# ==================================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$HOME/.config-backup-catppuccin-glass-$STAMP"
DIRS=(hypr waybar rofi swaync kitty)

c_ok()   { printf '\033[38;2;166;227;161m[ok]\033[0m %s\n' "$*"; }
c_info() { printf '\033[38;2;203;166;247m[..]\033[0m %s\n' "$*"; }
c_warn() { printf '\033[38;2;249;226;175m[!!]\033[0m %s\n' "$*"; }

PKGS=(
    hyprland hyprlock hypridle hyprpicker hyprpolkitagent xdg-desktop-portal-hyprland
    waybar rofi swaync kitty
    grim slurp wl-clipboard cliphist jq libnotify playerctl
    pavucontrol network-manager-applet
    ttf-jetbrains-mono-nerd inter-font papirus-icon-theme
    swaybg
)

echo
c_info "Catppuccin Glass wird installiert."
c_info "Backup-Ordner: $BACKUP"
read -r -p "Weiter? [j/N] " ans
[[ "$ans" =~ ^[jJyY]$ ]] || { c_warn "Abgebrochen."; exit 0; }

# ---------- Pakete ----------
c_info "Installiere Pakete ..."
sudo pacman -S --needed "${PKGS[@]}"

# Wallpaper-Daemon mit Uebergaengen: awww (neu) oder swww (alt), optional
if ! command -v awww >/dev/null 2>&1 && ! command -v swww >/dev/null 2>&1; then
    if sudo pacman -S --needed --noconfirm awww 2>/dev/null; then
        c_ok "awww installiert"
    elif sudo pacman -S --needed --noconfirm swww 2>/dev/null; then
        c_ok "swww installiert"
    else
        c_warn "awww/swww nicht in den Repos gefunden - nutze swaybg (ohne Uebergaenge)."
        c_warn "Optional spaeter:  yay -S awww"
    fi
fi

# ---------- Backup ----------
mkdir -p "$BACKUP"
for d in "${DIRS[@]}"; do
    if [ -e "$HOME/.config/$d" ]; then
        mv "$HOME/.config/$d" "$BACKUP/"
        c_ok "gesichert: ~/.config/$d"
    fi
done
# quickshell (end-4) nur sichern/deaktivieren, nicht loeschen
if [ -e "$HOME/.config/quickshell" ]; then
    cp -a "$HOME/.config/quickshell" "$BACKUP/"
    c_ok "kopiert (bleibt aber liegen): ~/.config/quickshell"
fi

# ---------- Configs kopieren ----------
for d in "${DIRS[@]}"; do
    cp -a "$HERE/config/$d" "$HOME/.config/$d"
    c_ok "installiert: ~/.config/$d"
done
chmod +x "$HOME/.config/hypr/scripts/"*.sh
mkdir -p "$HOME/Pictures/Wallpapers" "$HOME/Pictures/Screenshots"

# eigene Ergaenzungen aus alter Config uebernehmen? -> Platzhalter anlegen
[ -f "$HOME/.config/hypr/custom.lua" ] || cat > "$HOME/.config/hypr/custom.lua" <<'EOF'
-- Eigene Ergaenzungen. Diese Datei wird am Ende von hyprland.lua geladen.
-- Beispiel:
-- hl.bind("SUPER + G", hl.dsp.exec_cmd("steam"))
EOF

# ---------- Laufende Sitzung umstellen ----------
if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    c_info "Stelle laufende Sitzung um ..."
    pkill -x qs 2>/dev/null || true
    pkill -x quickshell 2>/dev/null || true
    pkill -x waybar 2>/dev/null || true
    pkill -x swaync 2>/dev/null || true
    pkill -x mako 2>/dev/null || true
    pkill -x dunst 2>/dev/null || true
    pkill -x hypridle 2>/dev/null || true
    hyprctl reload >/dev/null 2>&1 || true
    sleep 0.5
    setsid -f waybar   >/dev/null 2>&1
    setsid -f swaync   >/dev/null 2>&1
    setsid -f hypridle >/dev/null 2>&1
    setsid -f bash -c 'wl-paste --type text  --watch cliphist store' >/dev/null 2>&1
    setsid -f bash -c 'wl-paste --type image --watch cliphist store' >/dev/null 2>&1
    "$HOME/.config/hypr/scripts/wallpaper.sh" init || true
fi

echo
c_ok "Fertig."
echo "  - Wallpaper in ~/Pictures/Wallpapers legen, dann SUPER+SHIFT+W"
echo "  - Monitore pruefen:  hyprctl monitors   (Abschnitt MONITORE in ~/.config/hypr/hyprland.lua)"
echo "  - Zurueck zum alten Setup:  bash $HERE/restore.sh $BACKUP"
echo "  - Am saubersten: einmal ab- und wieder anmelden."
