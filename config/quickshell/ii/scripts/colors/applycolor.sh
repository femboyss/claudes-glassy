#!/usr/bin/env bash

QUICKSHELL_CONFIG_NAME="ii"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
CONFIG_DIR="$XDG_CONFIG_HOME/quickshell/$QUICKSHELL_CONFIG_NAME"
CACHE_DIR="$XDG_CACHE_HOME/quickshell"
STATE_DIR="$XDG_STATE_HOME/quickshell"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

term_alpha=100 #Set this to < 100 make all your terminals transparent
# sleep 0 # idk i wanted some delay or colors dont get applied properly
if [ ! -d "$STATE_DIR"/user/generated ]; then
  mkdir -p "$STATE_DIR"/user/generated
fi
cd "$CONFIG_DIR" || exit

colornames=''
colorstrings=''
colorlist=()
colorvalues=()

# claudes-glassy: ohne fertige Farben (z. B. Farb-Erzeugung im venv fehlgeschlagen) NICHTS
# anfassen - sonst landen ungefuellte Platzhalter wie "#$term0 #" in kitty und allen Terminals
if ! grep -q '^\$term0: #' "$STATE_DIR/user/generated/material_colors.scss" 2>/dev/null \
   || ! grep -q '^\$primary: #' "$STATE_DIR/user/generated/material_colors.scss" 2>/dev/null; then
  echo "applycolor: material_colors.scss fehlt oder ist unvollstaendig - Terminal-Farben uebersprungen" >&2
  exit 0
fi

colornames=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f1)
colorstrings=$(cat $STATE_DIR/user/generated/material_colors.scss | cut -d: -f2 | cut -d ' ' -f2 | cut -d ";" -f1)
IFS=$'\n'
colorlist=($colornames)     # Array of color names
colorvalues=($colorstrings) # Array of color values

apply_kitty() {  
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/kitty-theme.conf" ]; then
    echo "Template file not found for Kitty theme. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$STATE_DIR"/user/generated/terminal
  # claudes-glassy: erst in eine Temp-Datei, dann atomar austauschen (kitty liest sonst halbfertige Dateien)
  local out="$STATE_DIR"/user/generated/terminal/kitty-theme.conf
  local tmp="$out.tmp.$$"
  cp "$SCRIPT_DIR/terminal/kitty-theme.conf" "$tmp"
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$tmp"
  done
  if grep -q '#\$' "$tmp"; then
    echo "applycolor: kitty-Farben unvollstaendig, alte Datei bleibt" >&2
    rm -f "$tmp"
    return
  fi
  mv "$tmp" "$out"

  # Reload
  if ! pgrep -f kitty >/dev/null; then
    return
  fi
  kill -SIGUSR1 $(pidof kitty)
}

apply_anyterm() {
  # Check if terminal escape sequence template exists
  if [ ! -f "$SCRIPT_DIR/terminal/sequences.txt" ]; then
    echo "Template file not found for Terminal. Skipping that."
    return
  fi
  # Copy template
  mkdir -p "$STATE_DIR"/user/generated/terminal
  cp "$SCRIPT_DIR/terminal/sequences.txt" "$STATE_DIR"/user/generated/terminal/sequences.txt
  # Apply colors
  for i in "${!colorlist[@]}"; do
    sed -i "s/${colorlist[$i]} #/${colorvalues[$i]#\#}/g" "$STATE_DIR"/user/generated/terminal/sequences.txt
  done

  sed -i "s/\$alpha/$term_alpha/g" "$STATE_DIR/user/generated/terminal/sequences.txt"

  # claudes-glassy: Terminals von KDE-Diensten auslassen. kwrited (laeuft in kded6) haelt
  # ein eigenes pts offen und zeigt alles, was dort ankommt, als Benachrichtigung
  # "Dienst fuer lokale Systemnachrichten" an - voller Escape-Sequenzen.
  local skip=" "
  for pid in $(pgrep -x 'kded6|kded5|kwrited' 2>/dev/null); do
    for fd in /proc/"$pid"/fd/*; do
      t="$(readlink "$fd" 2>/dev/null)"
      [[ $t =~ ^/dev/pts/[0-9]+$ ]] && skip+="$t "
    done
  done

  for file in /dev/pts/*; do
    [[ "$skip" == *" $file "* ]] && continue
    if [[ $file =~ ^/dev/pts/[0-9]+$ ]] && [ -w "$file" ]; then
      {
      cat "$STATE_DIR"/user/generated/terminal/sequences.txt >"$file"
      } & disown || true
    fi
  done
}

apply_term() {
  apply_anyterm &
  apply_kitty &
}

# Check if terminal theming is enabled in config
CONFIG_FILE="$XDG_CONFIG_HOME/illogical-impulse/config.json"
if [ -f "$CONFIG_FILE" ]; then
  enable_terminal=$(jq -r '.appearance.wallpaperTheming.enableTerminal' "$CONFIG_FILE")
  if [ "$enable_terminal" = "true" ]; then
    apply_term &
  fi
else
  echo "Config file not found at $CONFIG_FILE. Applying terminal theming by default."
  apply_term &
fi

# apply_qt & # Qt theming is already handled by kde-material-colors
