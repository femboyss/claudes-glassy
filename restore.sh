#!/usr/bin/env bash
# Stellt das alte Setup aus dem Backup wieder her.
# Aufruf:  bash restore.sh ~/.config-backup-catppuccin-glass-<datum>
set -euo pipefail

BACKUP="${1:-}"
if [ -z "$BACKUP" ] || [ ! -d "$BACKUP" ]; then
    echo "Benutzung: bash restore.sh <backup-ordner>"
    echo "Vorhandene Backups:"
    ls -d "$HOME"/.config-backup-catppuccin-glass-* 2>/dev/null || echo "  (keine)"
    exit 1
fi

for d in hypr waybar rofi swaync kitty; do
    if [ -e "$BACKUP/$d" ]; then
        rm -rf "$HOME/.config/$d"
        cp -a "$BACKUP/$d" "$HOME/.config/$d"
        echo "[ok] wiederhergestellt: ~/.config/$d"
    fi
done

pkill -x waybar 2>/dev/null || true
pkill -x swaync 2>/dev/null || true
echo
echo "Fertig. Jetzt ab- und wieder anmelden, damit dein altes Setup (z. B. end-4/Quickshell) wieder startet."
