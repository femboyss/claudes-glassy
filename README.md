# claudes-glassy (Catppuccin Glass)

Catppuccin Mocha + Glas-Look (Transparenz, starker Blur, runde Ecken,
rotierender Mauve/Blau/Pink-Rahmen, federnde Animationen).
Gebaut fuer Hyprland 0.55+ mit Lua-Config.

## Bestandteile

| Teil            | Programm  | Datei                                   |
|-----------------|-----------|-----------------------------------------|
| Compositor      | Hyprland  | ~/.config/hypr/hyprland.lua             |
| Bar             | Waybar    | ~/.config/waybar/config.jsonc, style.css|
| Launcher/Menues | Rofi 2.x  | ~/.config/rofi/config.rasi              |
| Benachrichtig.  | SwayNC    | ~/.config/swaync/config.json, style.css |
| Sperrbildschirm | Hyprlock  | ~/.config/hypr/hyprlock.conf            |
| Idle            | Hypridle  | ~/.config/hypr/hypridle.conf            |
| Terminal        | Kitty     | ~/.config/kitty/kitty.conf              |
| Wallpaper       | awww/swww/swaybg | ~/.config/hypr/scripts/wallpaper.sh |

## Installation

Ein Befehl (klont nach ~/.local/share/claudes-glassy und startet den Installer):

    bash -c "$(curl -fsSL https://raw.githubusercontent.com/femboyss/claudes-glassy/main/get.sh)"

Oder manuell:

    git clone https://github.com/femboyss/claudes-glassy
    cd claudes-glassy
    bash install.sh

Sichert vorher alles nach ~/.config-backup-catppuccin-glass-<datum>.
Zurueck: `bash restore.sh <backup-ordner>`

Update: denselben Ein-Befehl nochmal ausfuehren.

## Tastenkuerzel

| Kuerzel              | Aktion                          |
|----------------------|---------------------------------|
| SUPER + Return       | Kitty                           |
| SUPER + Space        | App-Launcher                    |
| SUPER + E / B        | Dateimanager / Firefox          |
| SUPER + Q            | Fenster schliessen              |
| SUPER + F            | Vollbild                        |
| SUPER + SHIFT + F    | Maximieren                      |
| SUPER + T            | Schwebend an/aus                |
| SUPER + C            | Fenster zentrieren              |
| SUPER + SHIFT + P    | Fenster anpinnen                |
| SUPER + J            | Split drehen                    |
| SUPER + Pfeile       | Fokus                           |
| SUPER + SHIFT + Pfeile | Fenster verschieben           |
| SUPER + CTRL + Pfeile| Groesse aendern                 |
| SUPER + 1..0         | Workspace                       |
| SUPER + SHIFT + 1..0 | Fenster auf Workspace (folgen)  |
| SUPER + ALT + 1..0   | Fenster auf Workspace (bleiben) |
| SUPER + S            | Scratchpad                      |
| SUPER + V            | Zwischenablage-Verlauf          |
| SUPER + N            | Benachrichtigungs-Zentrum       |
| SUPER + L            | Sperren                         |
| SUPER + Escape       | Power-Menue                     |
| SUPER + SHIFT + W    | Naechstes Wallpaper             |
| SUPER + SHIFT + B    | Bar ein/aus                     |
| SUPER + SHIFT + R    | Bar neu starten                 |
| SUPER + SHIFT + C    | Farbpipette                     |
| Print / SHIFT+Print  | Screenshot Bereich / Monitor    |
| SUPER + SHIFT + M    | Hyprland beenden                |

## Anpassen

- Eigene Sachen in ~/.config/hypr/custom.lua, dann bleibt hyprland.lua updatefaehig.
- Monitore: Abschnitt MONITORE in hyprland.lua (Ausgabe von `hyprctl monitors`).
- Weniger GPU-Last: in hyprland.lua `blur.passes` auf 2 und die `borderangle`-Animation auf `enabled = false`.
- Mehr/weniger Glas: `background_opacity` in kitty.conf, `opacity` in der Regel `glass-apps`,
  `alpha(@base, 0.45)` in waybar/style.css.

## Quellen

- Hyprland Lua-Config: https://wiki.hypr.land/Configuring/Start/
- Variablen (Blur usw.): https://wiki.hypr.land/Configuring/Basics/Variables/
- Fensterregeln: https://wiki.hypr.land/Configuring/Basics/Window-Rules/
- Layer-Regeln: https://wiki.hypr.land/configuring/core/rules/layer-rules/
- Dispatcher: https://wiki.hypr.land/Configuring/Basics/Dispatchers/
- Catppuccin Farben: https://catppuccin.com/palette
