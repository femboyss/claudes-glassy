# claudes-glassy 2

A glassy Hyprland rice for Arch Linux, now built on **Quickshell** and
[end-4's illogical-impulse](https://github.com/end-4/dots-hyprland) shell:
Overview, AI sidebar, quick settings sidebar, Material You colors - plus the
claudes-glassy look (Tokyo Night / Catppuccin / full glass themes, gradient borders,
lots of blur) and a pile of performance fixes for multi-monitor, high refresh rate setups.
Built for **Hyprland 0.55+ (Lua config)**.

> The interface and all keybind descriptions are in German.
> Deutsche Anleitung: [ganz unten](#deutsch).

## What changed in version 2

Version 1 was Waybar + own GTK4 apps. Version 2 replaces all of that with the
illogical-impulse Quickshell shell (vendored in `config/quickshell/ii`, upstream commit
in `vendor/ii-upstream-commit`) and puts the glassy look and fixes on top:

| | |
|---|---|
| **Overview** (SUPER+Tab) | All workspaces with window previews, drag windows between workspaces |
| **Search / start menu** (tap SUPER) | Apps, calculator, commands, web search, clipboard, emoji |
| **AI sidebar** (SUPER+K) | Chat with Gemini, Ollama (local) or any OpenAI-compatible API, translator |
| **Right sidebar** (SUPER+A / SUPER+N) | Notifications, quick toggles (Wi-Fi, Bluetooth, night light, game mode ...), calendar, to-do, timer |
| **Themes** (SUPER+I -> Glassy) | Tokyo Night, Catppuccin Mocha, Full glass, See-through, Nord, Gruvbox, Rose Pine, Dracula, **Hatsune Miku**, Black/White, **Material You** (colors from the wallpaper) |
| **Miku wallpapers** (SUPER+I -> Glassy) | Optional: a new random Hatsune Miku wallpaper from wallhaven.cc on every start, SFW only, in exactly your screen resolution (no up- or downscaling). Turned on automatically with the Miku theme |
| **Two styles** (CTRL+SUPER+P) | Glassy (illogical-impulse) or Windows 11 (taskbar + start menu at the bottom) |
| **Lock screen, session menu, OSD, media controls, screen snip, OCR, recording** | From the shell |

## Performance fixes (vs. stock illogical-impulse and claudes-glassy 1)

| Problem | Fix |
|---|---|
| Shell CPU grows over hours | Notifications were stored forever (thousands after a day with Discord), every new one regrouped and rewrote the whole list. Now capped (default 60), saving is batched, removed entries are freed. |
| Lag while typing in browsers / terminals, moving windows | Every Hyprland event (including `windowtitle`, which fires constantly) spawned 5 `hyprctl` processes. Now only the data an event can change is refetched, events are coalesced (33 ms), nothing gets lost while a fetch is running. |
| Overview lags (especially with a rotated monitor) | Every window on every workspace had a live video stream. Now still frames, live only for the window under the mouse (switchable). |
| GPU busy at idle on 240 Hz | The rotating border gradient redraws all monitors every frame. Off by default (SUPER+I -> Glassy). |
| Blur cost | 2 passes instead of 3, `xray` (blur computed once and cached), no shadows for tiled windows. |
| Every Ctrl+C started a second Quickshell process | Text copies are picked up by the running shell, only images use IPC. |
| Games | Tearing allowed for `immediate` windows, `direct_scanout = 2`, no dimming/opacity for games. |
| Monitors at 60 Hz | All monitors use `highrr` (max refresh rate). |

Plus an optional **performance mode** (`glassy --perf` or SUPER+I -> Glassy): less blur,
no shadows, shorter animations.

## Install / update

    bash -c "$(curl -fsSL https://raw.githubusercontent.com/femboyss/claudes-glassy/main/get.sh)"

Test version (branch `debug`):

    bash -c "$(curl -fsSL https://raw.githubusercontent.com/femboyss/claudes-glassy/debug/get.sh)" _ debug

This clones (or hard-updates) the repo to `~/.local/share/claudes-glassy` and starts the
installer. It asks whether to back up your configs (default: yes) and whether to install
packages. Packages come from the illogical-impulse meta packages (`deps/arch`), installed
with `yay` (installed automatically if missing). The first install builds Quickshell, that
takes a few minutes.

Coming from stock end-4 dots? Your `~/.config/illogical-impulse/config.json` is kept
(copy saved next to it), glassy only sets its look once.

After the first install you have the `glassy` command:

| Command | What it does |
|---------|--------------|
| `glassy --update` | Get the latest **stable** version (branch `main`) and install it |
| `glassy --debug` | Get the **test** version (branch `debug`) and install it |
| `glassy --upgrade` | Install the update for your current channel |
| `glassy --check` | Look for updates now (`--notify` as a notification) |
| `glassy --whatsnew` | What's new on GitHub |
| `glassy --status` | Installed version, and whether main/debug have something newer |
| `glassy --doctor` / `--repair` | Check / repair configs, shell, fonts, refresh rates, lag settings |
| `glassy --restore` | Restore a backup from before the install |
| `glassy --settings` | Open the settings app (same as SUPER+I) |
| `glassy --reload` | Restart the shell and reload Hyprland |
| `glassy --theme [name]` | List themes / set one (`glassy --theme catppuccin`, `glassy --theme material`) |
| `glassy --miku-wall` | Get a new Miku wallpaper now |
| `glassy --miku-start` | Toggle a new Miku wallpaper on every start |
| `glassy --miku-res [WxH]` | Force a resolution (`glassy --miku-res 2560x1440`), no value = auto (largest monitor) |
| `glassy --perf` | Toggle performance mode |
| `glassy --logs` | Show the shell log |

Bug fixes land on `debug` first. Test them with `glassy --debug`; once they work they go to
`main`, and `glassy --update` brings you back to the stable channel.

## Keybinds

Press **SUPER+H** for the full cheat sheet (generated from the binds).

| Keys | Action |
|------|--------|
| SUPER (tap) / SUPER+Space | Search / start menu |
| SUPER+Tab / SUPER+O | Overview |
| SUPER+A / SUPER+N | Right sidebar (quick settings, notifications) |
| SUPER+K | AI sidebar (SUPER+ALT+K: as a window) |
| SUPER+V | Clipboard |
| SUPER+SHIFT+E | Emoji |
| SUPER+I | Settings |
| SUPER+H | Cheat sheet |
| SUPER+M / SUPER+G | Media controls / widget overlay |
| SUPER+W / SUPER+SHIFT+W | Wallpaper picker / random wallpaper |
| CTRL+ALT+Delete / SUPER+Escape | Session menu |
| CTRL+SHIFT+Esc | Task manager |
| SUPER+Return / SUPER+E / SUPER+B | Terminal / file manager / browser |
| SUPER+Q | Close window |
| SUPER+F / SUPER+SHIFT+F | Fullscreen / maximize |
| SUPER+T | Toggle floating |
| SUPER+C | Center window |
| SUPER+SHIFT+P | Pin window |
| SUPER+J | Toggle split |
| SUPER+Arrows / +SHIFT / +ALT | Focus / move / resize |
| SUPER+1..0 | Workspace 1..10 |
| SUPER+SHIFT+1..0 / SUPER+ALT+1..0 | Move window to workspace (follow / stay) |
| CTRL+SUPER+Left/Right | Previous / next workspace |
| SUPER+^ | Last workspace |
| SUPER+S / SUPER+CTRL+S | Scratchpad / move window there |
| SUPER+F1..F3 (+SHIFT) | Focus monitor DP-3 / HDMI-A-1 / DP-1 (move window) |
| SUPER+. / SUPER+, | Next / previous monitor |
| Print / SUPER+SHIFT+S | Screenshot (area, with window detection) |
| SHIFT+Print | Screenshot (monitor, saved + copied) |
| SUPER+SHIFT+X / +A / +T | OCR / Google Lens / translate screen |
| SUPER+ALT+R | Start / stop screen recording |
| SUPER+SHIFT+C | Color picker |
| SUPER+L | Lock |
| SUPER+SHIFT+B | Toggle bar |
| SUPER+SHIFT+R | Restart shell |
| CTRL+SUPER+P | Switch style (Glassy / Windows 11) |
| SUPER+ALT+F1 | VM mode (all keybinds off/on) |

## Files

| Path | Content |
|------|---------|
| `~/.config/hypr/hyprland.lua` | Loads the modules, each one isolated |
| `~/.config/hypr/glassy/` | claudes-glassy modules (keybinds, look, performance, rules, monitors ...) |
| `~/.config/hypr/custom/*.lua`, `~/.config/hypr/custom.lua` | **Your** additions (never overwritten) |
| `~/.config/quickshell/ii/` | The shell (illogical-impulse + glassy patches) |
| `~/.config/illogical-impulse/config.json` | Shell settings (SUPER+I) |
| `~/.config/hypr/glassy-generated.lua` | Border colors + switches, written by the theme script |

## Anima Engine / desktop pets (Windows apps via Proton)

A black instead of transparent background comes from Wine/Proton, not Hyprland. Use
GE-Proton (GE-Proton11-6 or newer) and set the Steam launch options to:

    WINE_LAYERED_OVERLAY_SHAPE=1 %command%

Window rules for Anima Engine (no border, rounding, shadow) are included.

## Credits and license

- Shell: [illogical-impulse by end-4](https://github.com/end-4/dots-hyprland), GPL-3.0
  (see `LICENSE-illogical-impulse`). The files in `config/quickshell/ii`, `config/matugen`,
  `config/fuzzel`, `config/hypr/hyprland`, `config/hypr/hyprlock*` and `deps/` come from it;
  claudes-glassy changes are marked with `claudes-glassy` comments.
- (c) 34 & Claude

## Sources

- Hyprland Lua config: https://wiki.hypr.land/Configuring/Start/
- Layer rules: https://wiki.hypr.land/configuring/core/rules/layer-rules/
- illogical-impulse wiki: https://end-4.github.io/dots-hyprland-wiki/en/
- Quickshell: https://quickshell.org/
- Tokyo Night: https://github.com/folke/tokyonight.nvim
- Catppuccin: https://catppuccin.com/palette
- GE-Proton overlay patch: https://github.com/GloriousEggroll/proton-ge-custom/pull/553

---

<a id="deutsch"></a>
## Deutsch

Ein Hyprland-Rice im Glas-Look fuer Arch Linux, jetzt auf Basis von **Quickshell** und der
Shell [illogical-impulse von end-4](https://github.com/end-4/dots-hyprland): Uebersicht,
KI-Seitenleiste, Schnelleinstellungen, Material-You-Farben - dazu der claudes-glassy-Look
(Tokyo Night, Catppuccin, Komplett-Glas usw., Verlaufsrahmen, viel Blur) und viele
Lag-Fixes fuer mehrere Monitore mit hoher Hz-Zahl. Fuer **Hyprland 0.55+ (Lua-Config)**.

### Was ist neu in Version 2

Version 1 war Waybar + eigene GTK4-Apps. Version 2 ersetzt das komplett durch die
Quickshell-Shell von illogical-impulse (liegt in `config/quickshell/ii`) mit Glassy-Look obendrauf:

- **Uebersicht (SUPER+Tab):** alle Workspaces mit Fenster-Vorschau, Fenster per Ziehen verschieben
- **Suche / Startmenue (Super antippen):** Apps, Rechner, Befehle, Websuche, Zwischenablage, Emojis
- **KI-Seitenleiste (SUPER+K):** Gemini, Ollama (lokal) oder jede OpenAI-kompatible API, Uebersetzer
- **Seitenleiste rechts (SUPER+A / SUPER+N):** Mitteilungen, Schnellschalter (WLAN, Bluetooth,
  Nachtlicht, Spielmodus ...), Kalender, To-do, Timer
- **Themes (SUPER+I -> Glassy):** Tokyo Night, Catppuccin Mocha, Komplett Glas, Nur Durchsicht,
  Nord, Gruvbox, Rose Pine, Dracula, **Hatsune Miku**, Schwarz/Weiss und **Material You** (Farben aus dem Wallpaper)
- **Miku-Wallpaper (SUPER+I -> Glassy):** auf Wunsch bei jedem Start ein neues, zufaelliges
  Hatsune-Miku-Wallpaper von wallhaven.cc (nur SFW), exakt in deiner Bildschirm-Aufloesung, kein
  Hoch- oder Runterskalieren. Geht beim Miku-Theme automatisch an. Befehle: `glassy --miku-wall`
  (jetzt ein neues), `glassy --miku-start` (an/aus), `glassy --miku-res 1920x1080` (Aufloesung festlegen)
- **Zwei Stile (Strg+Super+P):** Glassy oder Windows 11 (Taskleiste + Startmenue unten)
- Sperrbildschirm, Sitzungsmenue, Lautstaerke-Anzeige, Mediensteuerung, Screenshot mit
  Fenster-Erkennung, Texterkennung (OCR), Bildschirmaufnahme

### Lag-Fixes

- **Shell frisst nach Stunden immer mehr CPU:** Mitteilungen wurden endlos gespeichert und bei
  jeder neuen komplett neu sortiert und geschrieben. Jetzt max. 60 (einstellbar), gebuendeltes
  Speichern, alte Eintraege werden freigegeben.
- **Ruckeln beim Tippen / Fenster schieben:** Jedes Hyprland-Event (auch Fenstertitel-Aenderungen,
  die Browser und Terminals dauernd senden) hat 5 hyprctl-Prozesse gestartet. Jetzt wird nur
  neu geholt, was sich aendern kann, und Events werden gebuendelt.
- **Uebersicht laggt (vor allem mit hochkant gedrehtem Monitor):** Jedes Fenster hatte einen
  Live-Videostream. Jetzt Standbild, live nur unter der Maus (einschaltbar).
- **GPU arbeitet im Leerlauf (240 Hz):** Der rotierende Rahmen zeichnet alle Monitore jeden
  Frame neu. Jetzt standardmaessig aus.
- **Blur:** 2 statt 3 Durchgaenge, xray (einmal berechnet und gecacht), keine Schatten fuer
  gekachelte Fenster.
- **Jedes Strg+C startete einen zweiten Quickshell-Prozess:** Text erkennt die Shell selbst.
- **Spiele:** Tearing fuer "immediate"-Fenster, direct scanout, kein Dimmen.
- **Monitore auf 60 Hz:** alle auf `highrr` (hoechste Hz-Zahl).
- Zusaetzlich **Performance-Modus** (`glassy --perf` oder SUPER+I -> Glassy).

### Installieren / Aktualisieren

    bash -c "$(curl -fsSL https://raw.githubusercontent.com/femboyss/claudes-glassy/main/get.sh)"

Test-Stand (Branch `debug`):

    bash -c "$(curl -fsSL https://raw.githubusercontent.com/femboyss/claudes-glassy/debug/get.sh)" _ debug

Der Installer fragt nach einem Backup (Standard: ja) und ob Pakete installiert werden sollen.
Die Pakete kommen aus den Meta-Paketen von illogical-impulse (`deps/arch`) und werden mit `yay`
installiert (wird bei Bedarf selbst installiert). Beim ersten Mal wird Quickshell gebaut,
das dauert ein paar Minuten.

Kommst du von den normalen end-4-Dots? Deine `~/.config/illogical-impulse/config.json` bleibt
(Kopie daneben), Glassy setzt nur einmal seinen Look.

Befehle: siehe Tabelle oben (`glassy --update`, `--debug`, `--doctor`, `--theme`, `--perf`,
`--reload`, `--logs` ...). Fixes kommen zuerst auf `debug`. Mit `glassy --debug` testen;
wenn alles passt, landen sie auf `main`, und `glassy --update` bringt dich zurueck auf stabil.

- Altes Setup zurueck: `glassy --restore`
- Etwas kaputt? `glassy --doctor` (mit `glassy --repair` reparieren)
- Eigene Hyprland-Sachen: `~/.config/hypr/custom/*.lua` oder `~/.config/hypr/custom.lua`
  (werden nie ueberschrieben)
- Alle Tastenkuerzel: **SUPER+H**

### Anima Engine / Desktop-Pets (Windows-Apps ueber Proton)

Schwarzer statt durchsichtiger Hintergrund kommt von Wine/Proton. GE-Proton (ab 11-6)
verwenden und in Steam bei den Startoptionen eintragen:

    WINE_LAYERED_OVERLAY_SHAPE=1 %command%

### Lizenz

Die Shell ist illogical-impulse von end-4 (GPL-3.0, siehe `LICENSE-illogical-impulse`).
Aenderungen von claudes-glassy sind im Code mit `claudes-glassy` markiert.
(c) 34 & Claude
