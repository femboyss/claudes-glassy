#!/usr/bin/env bash
# claudes-glassy - Online-Installer / Updater
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/femboyss/claudes-glassy/main/get.sh)"
#   Test-Stand (Branch debug):  ... get.sh)" _ debug
# Danach gibt es den Befehl "glassy" (glassy --update / glassy --debug / glassy --help).
# Holt IMMER den neuesten Stand von GitHub. Lokale Aenderungen an der Repo-Kopie
# (~/.local/share/claudes-glassy) werden vorher gesichert und dann verworfen,
# damit ein Update nie haengen bleibt.
set -euo pipefail

DEST="$HOME/.local/share/claudes-glassy"
URL="https://github.com/femboyss/claudes-glassy"
BRANCH="${1:-main}"

command -v git >/dev/null 2>&1 || sudo pacman -S --needed git

if [ -d "$DEST/.git" ]; then
    echo "[..] Aktualisiere $DEST"
    if [ -n "$(git -C "$DEST" status --porcelain 2>/dev/null)" ]; then
        bak="$HOME/.local/share/claudes-glassy-lokal-$(date +%Y%m%d-%H%M%S).patch"
        git -C "$DEST" diff > "$bak" 2>/dev/null || true
        echo "[!!] Lokale Aenderungen in der Repo-Kopie gefunden -> gesichert in $bak"
    fi
    git -C "$DEST" fetch --depth 1 origin "$BRANCH"
    git -C "$DEST" checkout -q -B "$BRANCH" FETCH_HEAD
    git -C "$DEST" reset -q --hard FETCH_HEAD
    git -C "$DEST" clean -fdq
else
    rm -rf "$DEST"
    git clone --depth 1 --branch "$BRANCH" "$URL" "$DEST"
fi

mkdir -p "$HOME/.config/hypr" && echo "$BRANCH" > "$HOME/.config/hypr/glassy-channel"
echo "[ok] Stand: $BRANCH  $(git -C "$DEST" log -1 --format='%h  %s' 2>/dev/null)"
bash "$DEST/install.sh"
