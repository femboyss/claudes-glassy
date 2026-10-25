#!/usr/bin/env python3
# ==================================================================
#  claudes-glassy  -  Themes
#  Ein Theme = Farbpalette + "Glas" (wie durchsichtig alle Flaechen sind).
#
#    theme.py list                 alle Themes anzeigen
#    theme.py apply [name]         Theme setzen (ohne Name: das aus den Einstellungen)
#    theme.py current              aktives Theme
#
#  Erzeugt:
#    ~/.config/hypr/theme/colors.css     GTK4-Apps (Startmenue, Island, Panel, Zwischenablage, Einstellungen)
#    ~/.config/waybar/colors.css         Leiste
#    ~/.config/swaync/colors.css         Mitteilungen
#    ~/.config/rofi/glassy-colors.rasi   Suche, Strg+Alt+Entf
#    ~/.config/kitty/glassy-theme.conf   Terminal
#    ~/.config/hypr/glassy-theme.lua     Fensterrahmen
#    ~/.local/share/color-schemes/Glassy.colors  Qt/KDE-Apps (Dolphin ...), wenn eingeschaltet
# ==================================================================
import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
HYPR = os.path.join(HOME, ".config", "hypr")
STORE = os.path.join(HYPR, "glassy-settings.json")
GTK_OUT = os.path.join(HYPR, "theme", "colors.css")

# glass:   1.0 = normale Deckkraft der Flaechen, 0.5 = halb so viel, 0.2 = fast unsichtbar
# island:  Hintergrund der Dynamic Island (bei Glas-Themes durchsichtig statt schwarz)
# term:    Deckkraft des Terminals
# Farben:  bg/bg_dark/hl = Flaechen, fg/fg_dark/comment = Text, Rest = Akzente
THEMES = {
    "tokyo": {
        "label": "Tokyo Night", "desc": "Standard - dunkelblau, Blau/Lila",
        "bg": "1a1b26", "bg_dark": "16161e", "hl": "292e42", "fg": "c0caf5", "fg_dark": "a9b1d6",
        "comment": "565f89", "blue": "7aa2f7", "cyan": "7dcfff", "purple": "bb9af7", "pink": "ff79c6",
        "green": "9ece6a", "red": "f7768e", "yellow": "e0af68", "orange": "ff9e64", "teal": "1abc9c",
        "on_accent": "16161e", "glass": 1.0, "island": ("06060a", 0.92), "term": 0.72,
    },
    "catppuccin": {
        "label": "Catppuccin Mocha", "desc": "Weich, Pastell, Lila/Pink",
        "bg": "1e1e2e", "bg_dark": "181825", "hl": "313244", "fg": "cdd6f4", "fg_dark": "a6adc8",
        "comment": "6c7086", "blue": "89b4fa", "cyan": "89dceb", "purple": "cba6f7", "pink": "f5c2e7",
        "green": "a6e3a1", "red": "f38ba8", "yellow": "f9e2af", "orange": "fab387", "teal": "94e2d5",
        "on_accent": "11111b", "glass": 1.0, "island": ("11111b", 0.92), "term": 0.72,
    },
    "glass": {
        "label": "Komplett Glas", "desc": "Alles milchiges Glas, wenig Farbe",
        "bg": "20242e", "bg_dark": "181b22", "hl": "ffffff", "fg": "ffffff", "fg_dark": "e6e9f0",
        "comment": "aab2c0", "blue": "dfe8ff", "cyan": "c8f1ff", "purple": "e6dcff", "pink": "ffd9ec",
        "green": "c9f2c7", "red": "ff9aa8", "yellow": "ffe9a8", "orange": "ffcfa3", "teal": "bff5ea",
        "on_accent": "151820", "glass": 0.45, "hl_alpha": 0.14, "island": ("10131a", 0.38), "term": 0.45,
    },
    "clear": {
        "label": "Nur Durchsicht", "desc": "Fast unsichtbar - nur Unschaerfe und Text",
        "bg": "10121a", "bg_dark": "0c0e14", "hl": "ffffff", "fg": "ffffff", "fg_dark": "f0f2f8",
        "comment": "c4cad6", "blue": "ffffff", "cyan": "e8f8ff", "purple": "f1eaff", "pink": "ffe6f2",
        "green": "dcffd9", "red": "ffb0bb", "yellow": "fff1c2", "orange": "ffdcbc", "teal": "d8fff6",
        "on_accent": "0c0e14", "glass": 0.18, "hl_alpha": 0.10, "island": ("000000", 0.16), "term": 0.25,
    },
    "nord": {
        "label": "Nord", "desc": "Kuehl, arktisch, Blaugrau",
        "bg": "2e3440", "bg_dark": "272c36", "hl": "3b4252", "fg": "eceff4", "fg_dark": "d8dee9",
        "comment": "7b88a1", "blue": "88c0d0", "cyan": "8fbcbb", "purple": "b48ead", "pink": "d5a6c8",
        "green": "a3be8c", "red": "bf616a", "yellow": "ebcb8b", "orange": "d08770", "teal": "8fbcbb",
        "on_accent": "2e3440", "glass": 0.95, "island": ("1f232b", 0.92), "term": 0.75,
    },
    "gruvbox": {
        "label": "Gruvbox", "desc": "Warm, retro, Orange/Gelb",
        "bg": "282828", "bg_dark": "1d2021", "hl": "3c3836", "fg": "ebdbb2", "fg_dark": "d5c4a1",
        "comment": "928374", "blue": "83a598", "cyan": "8ec07c", "purple": "d3869b", "pink": "d3869b",
        "green": "b8bb26", "red": "fb4934", "yellow": "fabd2f", "orange": "fe8019", "teal": "8ec07c",
        "on_accent": "1d2021", "glass": 1.0, "island": ("141414", 0.92), "term": 0.78,
    },
    "rosepine": {
        "label": "Rose Pine", "desc": "Gedeckt, Rose/Gold",
        "bg": "191724", "bg_dark": "13111e", "hl": "26233a", "fg": "e0def4", "fg_dark": "c4c0dd",
        "comment": "6e6a86", "blue": "c4a7e7", "cyan": "9ccfd8", "purple": "c4a7e7", "pink": "ebbcba",
        "green": "9ccfd8", "red": "eb6f92", "yellow": "f6c177", "orange": "ebbcba", "teal": "31748f",
        "on_accent": "191724", "glass": 1.0, "island": ("0d0c14", 0.92), "term": 0.72,
    },
    "dracula": {
        "label": "Dracula", "desc": "Kontrastreich, Lila/Pink",
        "bg": "282a36", "bg_dark": "21222c", "hl": "44475a", "fg": "f8f8f2", "fg_dark": "dcdcd4",
        "comment": "6272a4", "blue": "bd93f9", "cyan": "8be9fd", "purple": "bd93f9", "pink": "ff79c6",
        "green": "50fa7b", "red": "ff5555", "yellow": "f1fa8c", "orange": "ffb86c", "teal": "8be9fd",
        "on_accent": "21222c", "glass": 1.0, "island": ("15161d", 0.92), "term": 0.75,
    },
    "mono": {
        "label": "Schwarz/Weiss", "desc": "Minimal, keine Farben",
        "bg": "141414", "bg_dark": "0e0e0e", "hl": "2a2a2a", "fg": "f2f2f2", "fg_dark": "cfcfcf",
        "comment": "7a7a7a", "blue": "f2f2f2", "cyan": "d6d6d6", "purple": "bdbdbd", "pink": "e0e0e0",
        "green": "d0d0d0", "red": "ff6b6b", "yellow": "e8e8e8", "orange": "dcdcdc", "teal": "cfcfcf",
        "on_accent": "0e0e0e", "glass": 0.9, "island": ("000000", 0.9), "term": 0.75,
    },
}
DEFAULT = "tokyo"
NAMES = list(THEMES)


def current():
    try:
        with open(STORE, encoding="utf-8") as f:
            n = json.load(f).get("theme", DEFAULT)
    except (OSError, ValueError):
        n = DEFAULT
    return n if n in THEMES else DEFAULT


def get(name=None):
    t = dict(THEMES.get(name or current(), THEMES[DEFAULT]))
    t.setdefault("hl_alpha", 1.0)
    return t


def rgb(h):
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def rgba(h, a):
    r, g, b = rgb(h)
    return f"rgba({r}, {g}, {b}, {round(max(0.0, min(1.0, a)), 3)})"


# ------------------------------------------------------------------ GTK (Python-Apps)
def gtk_css(name=None):
    """@define-color-Block. Flaechen tragen die Glas-Deckkraft schon in sich:
    alpha(@tn_bg, 0.86) ergibt bei Glas 0.45 nur noch 0.39."""
    t = get(name)
    gl = t["glass"]
    surf = {"tn_bg": rgba(t["bg"], gl), "tn_bg_dark": rgba(t["bg_dark"], gl),
            "tn_hl": rgba(t["hl"], t["hl_alpha"] if t["hl_alpha"] < 1 else gl),
            "tn_bg_hl": rgba(t["hl"], t["hl_alpha"] if t["hl_alpha"] < 1 else gl),
            "tn_island": rgba(t["island"][0], 1.0)}
    solid = {"tn_fg": t["fg"], "tn_fg_dark": t["fg_dark"], "tn_comment": t["comment"],
             "tn_blue": t["blue"], "tn_cyan": t["cyan"], "tn_purple": t["purple"], "tn_pink": t["pink"],
             "tn_green": t["green"], "tn_red": t["red"], "tn_yellow": t["yellow"], "tn_orange": t["orange"],
             "tn_teal": t["teal"], "tn_on_accent": t["on_accent"], "tn_solid_bg": t["bg"]}
    lines = [f"/* claudes-glassy Theme: {t['label']} (automatisch erzeugt) */"]
    lines += [f"@define-color {k} {v};" for k, v in surf.items()]
    lines += [f"@define-color {k} #{v};" for k, v in solid.items()]
    # Island-Deckkraft separat (alpha(@tn_island, x) * Faktor geht in GTK nicht -> fertige Farbe)
    lines.append(f"@define-color tn_island_bg {rgba(t['island'][0], t['island'][1])};")
    return "\n".join(lines) + "\n"


def gtk_css_cached():
    """Fuer die Apps: erzeugte Datei lesen (schnell), sonst direkt erzeugen."""
    try:
        with open(GTK_OUT, encoding="utf-8") as f:
            return f.read()
    except OSError:
        return gtk_css()


# ------------------------------------------------------------------ Waybar / swaync (GTK3, Catppuccin-Namen)
def bar_css(t):
    gl = t["glass"]
    hl_a = t["hl_alpha"] if t["hl_alpha"] < 1 else gl
    m = {
        "base": rgba(t["bg"], gl), "mantle": rgba(t["bg_dark"], gl), "crust": rgba(t["bg_dark"], gl),
        "surface0": rgba(t["hl"], hl_a), "surface1": rgba(t["hl"], min(1.0, hl_a * 1.25)),
        "overlay0": "#" + t["comment"], "text": "#" + t["fg"], "subtext": "#" + t["fg_dark"],
        "mauve": "#" + t["purple"], "blue": "#" + t["blue"], "pink": "#" + t["pink"],
        "teal": "#" + t["teal"], "green": "#" + t["green"], "yellow": "#" + t["yellow"],
        "peach": "#" + t["orange"], "red": "#" + t["red"], "on_accent": "#" + t["on_accent"],
    }
    return m


def waybar_css(name=None):
    t = get(name)
    return (f"/* claudes-glassy Theme: {t['label']} (automatisch erzeugt) */\n"
            + "".join(f"@define-color {k} {v};\n" for k, v in bar_css(t).items()))


def swaync_css(name=None):
    t = get(name)
    gl = t["glass"]
    hl_a = t["hl_alpha"] if t["hl_alpha"] < 1 else gl
    m = bar_css(t)
    m.update({
        "base": rgba(t["bg"], 0.55 * gl),
        "card": rgba(t["hl"], 0.55 * hl_a), "cardhov": rgba(t["hl"], min(1.0, 0.75 * hl_a)),
        "edge": rgba(t["fg"], 0.08), "inner": rgba(t["bg_dark"], 0.55 * gl),
    })
    return (f"/* claudes-glassy Theme: {t['label']} (automatisch erzeugt) */\n"
            + "".join(f"@define-color {k} {v};\n" for k, v in m.items()))


# ------------------------------------------------------------------ rofi
def rofi_rasi(name=None):
    t = get(name)
    gl = t["glass"]
    hl_a = t["hl_alpha"] if t["hl_alpha"] < 1 else gl

    def ra(h, a):
        r, g, b = rgb(h)
        return f"rgba({r}, {g}, {b}, {round(max(0, min(1, a)) * 100)}%)"
    p = {
        "base": ra(t["bg"], 0.55 * gl), "surface": ra(t["hl"], 0.55 * hl_a), "text": "#" + t["fg"],
        "subtext": "#" + t["fg_dark"], "mauve": "#" + t["purple"], "pink": "#" + t["pink"],
        "red": "#" + t["red"], "border-c": ra(t["fg"], 0.10), "on-accent": "#" + t["on_accent"],
        "sel-bg": ra(t["purple"], 0.22), "tile": ra(t["hl"], 0.45 * hl_a), "tileedge": ra(t["fg"], 0.10),
        "dim": ra(t["bg_dark"], 0.62 * max(gl, 0.4)), "tile-sel": ra(t["purple"], 0.28),
        "tile-sel-edge": ra(t["purple"], 0.70), "tile-urg": ra(t["red"], 0.30), "tile-urg-edge": ra(t["red"], 0.80),
    }
    return (f"/* claudes-glassy Theme: {t['label']} (automatisch erzeugt) */\n* {{\n"
            + "".join(f"    {k}: {v};\n" for k, v in p.items()) + "}\n")


# ------------------------------------------------------------------ kitty
def kitty_conf(name=None):
    t = get(name)
    c = lambda k: "#" + t[k]  # noqa: E731
    return f"""# claudes-glassy Theme: {t['label']} (automatisch erzeugt)
background_opacity {t['term']}
foreground {c('fg')}
background {c('bg')}
selection_foreground {c('on_accent')}
selection_background {c('blue')}
cursor {c('fg')}
cursor_text_color {c('bg')}
url_color {c('cyan')}
active_border_color {c('purple')}
inactive_border_color {c('comment')}
active_tab_foreground {c('on_accent')}
active_tab_background {c('purple')}
inactive_tab_foreground {c('fg_dark')}
inactive_tab_background {c('bg_dark')}
color0 {c('hl')}
color8 {c('comment')}
color1 {c('red')}
color9 {c('red')}
color2 {c('green')}
color10 {c('green')}
color3 {c('yellow')}
color11 {c('yellow')}
color4 {c('blue')}
color12 {c('blue')}
color5 {c('purple')}
color13 {c('pink')}
color6 {c('cyan')}
color14 {c('teal')}
color7 {c('fg_dark')}
color15 {c('fg')}
"""


# ------------------------------------------------------------------ Hyprland-Rahmen
def hypr_lua(name=None):
    t = get(name)
    gl = t["glass"]
    ina = max(0x22, int(0x88 * min(1.0, gl + 0.2)))
    return f"""-- claudes-glassy Theme: {t['label']} (automatisch erzeugt, nicht von Hand aendern)
return {{
    border_a = "rgba({t['purple']}ee)",
    border_b = "rgba({t['blue']}ee)",
    border_c = "rgba({t['pink']}ee)",
    border_inactive = "rgba({t['hl']}{ina:02x})",
}}
"""


# ------------------------------------------------------------------ Qt / KDE
def kde_colors(name=None):
    t = get(name)
    c = lambda k: ",".join(str(x) for x in rgb(t[k]))  # noqa: E731
    bg, bgd, hl, fg = c("bg"), c("bg_dark"), c("hl"), c("fg")
    com, blue, red, green, yel, pur, oa = c("comment"), c("blue"), c("red"), c("green"), c("yellow"), c("purple"), c("on_accent")
    def grp(name, back, alt, norm=fg):
        return f"""[{name}]
BackgroundAlternate={alt}
BackgroundNormal={back}
DecorationFocus={blue}
DecorationHover={pur}
ForegroundActive={blue}
ForegroundInactive={com}
ForegroundLink={blue}
ForegroundNegative={red}
ForegroundNeutral={yel}
ForegroundNormal={norm}
ForegroundPositive={green}
ForegroundVisited={pur}

"""
    out = ["[ColorEffects:Disabled]\nColor=56,56,56\nColorAmount=0\nColorEffect=0\nContrastAmount=0.65\n"
           "ContrastEffect=1\nIntensityAmount=0.1\nIntensityEffect=2\n\n",
           "[ColorEffects:Inactive]\nChangeSelectionColor=true\nColor=112,111,110\nColorAmount=0.025\n"
           "ColorEffect=2\nContrastAmount=0.1\nContrastEffect=2\nEnable=false\nIntensityAmount=0\nIntensityEffect=0\n\n"]
    out.append(grp("Colors:Button", hl, bg))
    out.append(grp("Colors:Complementary", bgd, bg))
    out.append(grp("Colors:Header", bgd, bg))
    out.append(grp("Colors:Header][Inactive", bgd, bg))
    sel = f"""[Colors:Selection]
BackgroundAlternate={pur}
BackgroundNormal={blue}
DecorationFocus={blue}
DecorationHover={pur}
ForegroundActive={oa}
ForegroundInactive={oa}
ForegroundLink={oa}
ForegroundNegative={oa}
ForegroundNeutral={oa}
ForegroundNormal={oa}
ForegroundPositive={oa}
ForegroundVisited={oa}

"""
    out.append(sel)
    out.append(grp("Colors:Tooltip", bgd, bg))
    out.append(grp("Colors:View", bg, bgd))
    out.append(grp("Colors:Window", bgd, bg))
    out.append(f"""[General]
ColorScheme=Glassy
Name=claudes-glassy ({t['label']})
shadeSortColumn=true

[KDE]
contrast=4

[WM]
activeBackground={bgd}
activeBlend={fg}
activeForeground={fg}
inactiveBackground={bgd}
inactiveBlend={com}
inactiveForeground={com}
""")
    return "".join(out)


# ------------------------------------------------------------------ Anwenden
def _write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def _qt_enabled():
    try:
        with open(STORE, encoding="utf-8") as f:
            return json.load(f).get("qt_theme", True)
    except (OSError, ValueError):
        return True


def write_files(name=None):
    name = name if name in THEMES else current()
    _write(GTK_OUT, gtk_css(name))
    _write(os.path.join(HOME, ".config", "waybar", "colors.css"), waybar_css(name))
    _write(os.path.join(HOME, ".config", "swaync", "colors.css"), swaync_css(name))
    _write(os.path.join(HOME, ".config", "rofi", "glassy-colors.rasi"), rofi_rasi(name))
    _write(os.path.join(HOME, ".config", "kitty", "glassy-theme.conf"), kitty_conf(name))
    _write(os.path.join(HYPR, "glassy-theme.lua"), hypr_lua(name))
    _write(os.path.join(HOME, ".local", "share", "color-schemes", "Glassy.colors"), kde_colors(name))
    if _qt_enabled():
        qt = os.path.join(HYPR, "scripts", "qt-theme.sh")
        if os.path.exists(qt):
            subprocess.run(["bash", qt, "apply", "--quiet"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return name


def _bg(cmd):
    env = dict(os.environ)
    env.pop("LD_PRELOAD", None)
    try:
        subprocess.Popen(["sh", "-c", cmd], env=env, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


def reload_running():
    """Laufende Teile neu einlesen lassen."""
    s = os.path.join(HYPR, "scripts")
    _bg("pkill -SIGUSR2 -x waybar")                     # Waybar: CSS neu laden
    _bg("swaync-client -rs")                            # Mitteilungen: CSS neu laden
    _bg("pkill -SIGUSR1 -x kitty")                      # kitty: Konfiguration neu laden
    _bg("hyprctl reload")                               # Fensterrahmen
    # GTK4-Dienste lesen die Farben beim Start -> neu starten (dauert < 1 s)
    _bg(f"pkill -f 'startmenu/startmenu.py' ; sleep 0.3; {s}/startmenu.sh --start-daemon")
    _bg(f"pkill -f 'clipboard/clipman.py' ; sleep 0.3; {s}/clipboard.sh --start-daemon")
    _bg(f"pkill -f 'panel/panel.py' ; sleep 0.3; {s}/panel.sh --start-daemon")
    _bg(f"{s}/island.sh restart")


def set_theme(name):
    try:
        with open(STORE, encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, ValueError):
        data = {}
    data["theme"] = name
    _write(STORE, json.dumps(data, indent=2, ensure_ascii=False))


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "apply"
    if cmd == "list":
        cur = current()
        for k, t in THEMES.items():
            print(f"{'*' if k == cur else ' '} {k:<11} {t['label']:<18} {t['desc']}")
        return 0
    if cmd == "current":
        print(current())
        return 0
    if cmd in ("apply", "set"):
        name = argv[2] if len(argv) > 2 else None
        if name and name not in THEMES:
            print(f"Unbekanntes Theme: {name}. Verfuegbar: {', '.join(NAMES)}")
            return 1
        if name:
            set_theme(name)
        n = write_files(name)
        if "--no-reload" not in argv:
            reload_running()
        print(f"Theme: {THEMES[n]['label']}")
        return 0
    print(__doc__ or "theme.py list | apply [name] | current")
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
