#!/usr/bin/env bash
# claudes-glassy - Online-Installer
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/femboyss/claudes-glassy/main/get.sh)"
set -euo pipefail

DEST="$HOME/.local/share/claudes-glassy"

command -v git >/dev/null 2>&1 || sudo pacman -S --needed git

if [ -d "$DEST/.git" ]; then
    echo "[..] Aktualisiere $DEST"
    git -C "$DEST" pull --ff-only
else
    rm -rf "$DEST"
    git clone --depth 1 https://github.com/femboyss/claudes-glassy "$DEST"
fi

bash "$DEST/install.sh"
