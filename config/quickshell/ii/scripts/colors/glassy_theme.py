#!/usr/bin/env python3
# ==================================================================
#  claudes-glassy  -  Themes fuer die Quickshell-Shell (illogical-impulse)
#
#    glassy_theme.py list              alle Themes
#    glassy_theme.py current           aktives Theme
#    glassy_theme.py apply [name]      Theme setzen (ohne Name: das aus der Config)
#    glassy_theme.py sync              nur Hyprland-Werte (Rahmen, Animation, Performance) neu schreiben
#    glassy_theme.py defaults FILE     Glassy-Standardwerte in die Shell-Config uebernehmen
#                                      (nur Werte, die du noch nicht selbst gesetzt hast;
#                                       --force: alle Glassy-Werte setzen, z. B. beim Umstieg von end-4)
#
#  Feste Themes (Tokyo Night, Catppuccin, ...) werden in Material-3-Farbrollen
#  uebersetzt und genau dorthin geschrieben, wo sonst matugen hinschreibt.
#  Dadurch faerben sich Shell, GTK-Apps, fuzzel, hyprlock und Terminal mit.
#  "material" = Material You: Farben automatisch aus dem Wallpaper (wie end-4).
#
#  Nur Python-Standardbibliothek, laeuft ohne venv.
# ==================================================================
import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
XDG_CONFIG = os.environ.get("XDG_CONFIG_HOME", os.path.join(HOME, ".config"))
XDG_STATE = os.environ.get("XDG_STATE_HOME", os.path.join(HOME, ".local", "state"))
SHELL_CONFIG = os.path.join(XDG_CONFIG, "illogical-impulse", "config.json")
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
MATUGEN_DIR = os.path.join(XDG_CONFIG, "matugen")
GEN_DIR = os.path.join(XDG_STATE, "quickshell", "user", "generated")
HYPR_GEN = os.path.join(XDG_CONFIG, "hypr", "glassy-generated.lua")
KITTY_THEME = os.path.join(XDG_CONFIG, "kitty", "glassy-theme.conf")

# primary/secondary/tertiary = welche Akzentfarbe welche Rolle bekommt
# glass: 1.0 = normale Glas-Deckkraft, kleiner = durchsichtiger
# term:  Deckkraft des Terminals
THEMES = {
    "tokyo": {
        "label": "Tokyo Night", "desc": "Standard - dunkelblau, Blau/Lila",
        "bg": "1a1b26", "bg_dark": "16161e", "hl": "292e42", "fg": "c0caf5", "fg_dark": "a9b1d6",
        "comment": "565f89", "blue": "7aa2f7", "cyan": "7dcfff", "purple": "bb9af7", "pink": "ff79c6",
        "green": "9ece6a", "red": "f7768e", "yellow": "e0af68", "orange": "ff9e64", "teal": "1abc9c",
        "on_accent": "16161e", "glass": 1.0, "term": 0.72,
        "roles": ("blue", "purple", "pink"),
    },
    "catppuccin": {
        "label": "Catppuccin Mocha", "desc": "Weich, Pastell, Lila/Pink",
        "bg": "1e1e2e", "bg_dark": "181825", "hl": "313244", "fg": "cdd6f4", "fg_dark": "a6adc8",
        "comment": "6c7086", "blue": "89b4fa", "cyan": "89dceb", "purple": "cba6f7", "pink": "f5c2e7",
        "green": "a6e3a1", "red": "f38ba8", "yellow": "f9e2af", "orange": "fab387", "teal": "94e2d5",
        "on_accent": "11111b", "glass": 1.0, "term": 0.72,
        "roles": ("purple", "blue", "pink"),
    },
    "glass": {
        "label": "Komplett Glas", "desc": "Alles milchiges Glas, wenig Farbe",
        "bg": "20242e", "bg_dark": "181b22", "hl": "ffffff", "hl_alpha": 0.14, "fg": "ffffff", "fg_dark": "e6e9f0",
        "comment": "aab2c0", "blue": "dfe8ff", "cyan": "c8f1ff", "purple": "e6dcff", "pink": "ffd9ec",
        "green": "c9f2c7", "red": "ff9aa8", "yellow": "ffe9a8", "orange": "ffcfa3", "teal": "bff5ea",
        "on_accent": "151820", "glass": 0.45, "term": 0.45,
        "roles": ("blue", "purple", "pink"),
    },
    "clear": {
        "label": "Nur Durchsicht", "desc": "Fast unsichtbar - nur Unschaerfe und Text",
        "bg": "10121a", "bg_dark": "0c0e14", "hl": "ffffff", "hl_alpha": 0.10, "fg": "ffffff", "fg_dark": "f0f2f8",
        "comment": "c4cad6", "blue": "ffffff", "cyan": "e8f8ff", "purple": "f1eaff", "pink": "ffe6f2",
        "green": "dcffd9", "red": "ffb0bb", "yellow": "fff1c2", "orange": "ffdcbc", "teal": "d8fff6",
        "on_accent": "0c0e14", "glass": 0.18, "term": 0.25,
        "roles": ("blue", "purple", "pink"),
    },
    "nord": {
        "label": "Nord", "desc": "Kuehl, arktisch, Blaugrau",
        "bg": "2e3440", "bg_dark": "272c36", "hl": "3b4252", "fg": "eceff4", "fg_dark": "d8dee9",
        "comment": "7b88a1", "blue": "88c0d0", "cyan": "8fbcbb", "purple": "b48ead", "pink": "d5a6c8",
        "green": "a3be8c", "red": "bf616a", "yellow": "ebcb8b", "orange": "d08770", "teal": "8fbcbb",
        "on_accent": "2e3440", "glass": 0.95, "term": 0.75,
        "roles": ("blue", "teal", "purple"),
    },
    "gruvbox": {
        "label": "Gruvbox", "desc": "Warm, retro, Orange/Gelb",
        "bg": "282828", "bg_dark": "1d2021", "hl": "3c3836", "fg": "ebdbb2", "fg_dark": "d5c4a1",
        "comment": "928374", "blue": "83a598", "cyan": "8ec07c", "purple": "d3869b", "pink": "d3869b",
        "green": "b8bb26", "red": "fb4934", "yellow": "fabd2f", "orange": "fe8019", "teal": "8ec07c",
        "on_accent": "1d2021", "glass": 1.0, "term": 0.78,
        "roles": ("yellow", "orange", "green"),
    },
    "rosepine": {
        "label": "Rose Pine", "desc": "Gedeckt, Rose/Gold",
        "bg": "191724", "bg_dark": "13111e", "hl": "26233a", "fg": "e0def4", "fg_dark": "c4c0dd",
        "comment": "6e6a86", "blue": "c4a7e7", "cyan": "9ccfd8", "purple": "c4a7e7", "pink": "ebbcba",
        "green": "9ccfd8", "red": "eb6f92", "yellow": "f6c177", "orange": "ebbcba", "teal": "31748f",
        "on_accent": "191724", "glass": 1.0, "term": 0.72,
        "roles": ("pink", "purple", "yellow"),
    },
    "dracula": {
        "label": "Dracula", "desc": "Kontrastreich, Lila/Pink",
        "bg": "282a36", "bg_dark": "21222c", "hl": "44475a", "fg": "f8f8f2", "fg_dark": "dcdcd4",
        "comment": "6272a4", "blue": "bd93f9", "cyan": "8be9fd", "purple": "bd93f9", "pink": "ff79c6",
        "green": "50fa7b", "red": "ff5555", "yellow": "f1fa8c", "orange": "ffb86c", "teal": "8be9fd",
        "on_accent": "21222c", "glass": 1.0, "term": 0.75,
        "roles": ("purple", "pink", "cyan"),
    },
    "mono": {
        "label": "Schwarz/Weiss", "desc": "Minimal, keine Farben",
        "bg": "141414", "bg_dark": "0e0e0e", "hl": "2a2a2a", "fg": "f2f2f2", "fg_dark": "cfcfcf",
        "comment": "7a7a7a", "blue": "f2f2f2", "cyan": "d6d6d6", "purple": "bdbdbd", "pink": "e0e0e0",
        "green": "d0d0d0", "red": "ff6b6b", "yellow": "e8e8e8", "orange": "dcdcdc", "teal": "cfcfcf",
        "on_accent": "0e0e0e", "glass": 0.9, "term": 0.75,
        "roles": ("blue", "cyan", "purple"),
    },
}
MATERIAL = "material"
DEFAULT = "tokyo"
ALL_NAMES = list(THEMES) + [MATERIAL]
LABELS = {**{k: v["label"] for k, v in THEMES.items()}, MATERIAL: "Material You (aus dem Wallpaper)"}


# ------------------------------------------------------------------ Farb-Helfer
def rgb(h):
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def hexc(r, g, b):
    return "#{:02x}{:02x}{:02x}".format(*(max(0, min(255, round(x))) for x in (r, g, b)))


def mix(a, b, t):
    """t = 0 -> a, t = 1 -> b"""
    ra, ga, ba = rgb(a)
    rb, gb, bb = rgb(b)
    return hexc(ra + (rb - ra) * t, ga + (gb - ga) * t, ba + (bb - ba) * t)


# ------------------------------------------------------------------ Config
def load_config():
    try:
        with open(SHELL_CONFIG, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save_config(cfg):
    os.makedirs(os.path.dirname(SHELL_CONFIG), exist_ok=True)
    tmp = SHELL_CONFIG + ".glassy-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=4, ensure_ascii=False)
    os.replace(tmp, SHELL_CONFIG)


def deep_set(cfg, path, value):
    node = cfg
    for key in path[:-1]:
        if not isinstance(node.get(key), dict):
            node[key] = {}
        node = node[key]
    node[path[-1]] = value


def deep_get(cfg, path, default=None):
    node = cfg
    for key in path:
        if not isinstance(node, dict) or key not in node:
            return default
        node = node[key]
    return node


def current():
    n = deep_get(load_config(), ["glassy", "theme"], DEFAULT)
    return n if n in ALL_NAMES else DEFAULT


# ------------------------------------------------------------------ Material-3-Rollen aus einer festen Palette
def m3_from_palette(t):
    bg, bgd, fg, fgd, cm = t["bg"], t["bg_dark"], t["fg"], t["fg_dark"], t["comment"]
    hl_alpha = t.get("hl_alpha", 1.0)
    # Bezugsfarbe fuer die Flaechen-Stufen (bei Glas-Themes ist hl weiss)
    hl = t["hl"] if hl_alpha >= 1.0 else mix(bg, t["hl"], min(0.5, hl_alpha * 1.6))
    p, s, te = (t[r] for r in t["roles"])
    on = t["on_accent"]
    red, green = t["red"], t["green"]

    c = {
        "source_color": p,
        "background": bg,
        "on_background": fg,
        "surface": bg,
        "surface_dim": bgd,
        "surface_bright": mix(bg, fg, 0.16),
        "surface_container_lowest": mix(bgd, "000000", 0.25),
        "surface_container_low": mix(bg, hl, 0.30),
        "surface_container": mix(bg, hl, 0.55),
        "surface_container_high": mix(bg, hl, 0.85),
        "surface_container_highest": mix(hl, fg, 0.07),
        "on_surface": fg,
        "surface_variant": mix(bg, hl, 0.85),
        "on_surface_variant": fgd,
        "inverse_surface": fg,
        "inverse_on_surface": bg,
        "outline": cm,
        "outline_variant": mix(bg, cm, 0.45),
        "shadow": "#000000",
        "scrim": "#000000",
        "surface_tint": p,
        "primary": p,
        "on_primary": on,
        "primary_container": mix(bg, p, 0.32),
        "on_primary_container": mix(fg, p, 0.35),
        "inverse_primary": mix(p, bg, 0.45),
        "secondary": s,
        "on_secondary": on,
        "secondary_container": mix(bg, s, 0.26),
        "on_secondary_container": mix(fg, s, 0.30),
        "tertiary": te,
        "on_tertiary": on,
        "tertiary_container": mix(bg, te, 0.26),
        "on_tertiary_container": mix(fg, te, 0.30),
        "error": red,
        "on_error": on,
        "error_container": mix(bg, red, 0.30),
        "on_error_container": mix(fg, red, 0.30),
        "success": green,
        "on_success": on,
        "success_container": mix(bg, green, 0.28),
        "on_success_container": mix(fg, green, 0.30),
    }
    for role, col in (("primary", p), ("secondary", s), ("tertiary", te)):
        c[f"{role}_fixed"] = mix(col, fg, 0.45)
        c[f"{role}_fixed_dim"] = col
        c[f"on_{role}_fixed"] = bgd
        c[f"on_{role}_fixed_variant"] = mix(bg, col, 0.45)
    return {k: (v if v.startswith("#") else "#" + v) for k, v in c.items()}


def term_from_palette(t):
    bright = lambda x: mix(t[x], "ffffff", 0.12)
    return {
        "term0": "#" + t["bg"], "term1": "#" + t["red"], "term2": "#" + t["green"], "term3": "#" + t["yellow"],
        "term4": "#" + t["blue"], "term5": "#" + t["purple"], "term6": "#" + t["cyan"], "term7": "#" + t["fg"],
        "term8": "#" + t["comment"], "term9": bright("red"), "term10": bright("green"), "term11": bright("yellow"),
        "term12": bright("blue"), "term13": bright("purple"), "term14": bright("cyan"), "term15": "#" + t["fg"],
    }


# ------------------------------------------------------------------ Mini-matugen: Templates rendern
TOKEN = re.compile(r"\{\{\s*colors\.([a-z_]+)\.(default|dark|light)\.(hex_stripped|hex|red|green|blue)\s*\}\}")


def render(template, colors, image=""):
    def sub(m):
        name, _variant, fmt = m.groups()
        val = colors.get(name)
        if val is None:
            return m.group(0)
        if fmt == "hex":
            return val
        if fmt == "hex_stripped":
            return val.lstrip("#")
        r, g, b = rgb(val)
        return str({"red": r, "green": g, "blue": b}[fmt])
    out = TOKEN.sub(sub, template)
    return out.replace("{{image}}", image)


def matugen_targets():
    """(input, output)-Paare aus ~/.config/matugen/config.toml lesen (ohne toml-Modul)."""
    cfg = os.path.join(MATUGEN_DIR, "config.toml")
    pairs = []
    try:
        text = open(cfg, encoding="utf-8").read()
    except OSError:
        return pairs
    for block in re.split(r"^\[templates\.", text, flags=re.M)[1:]:
        name = block.split("]", 1)[0]
        inp = re.search(r"input_path\s*=\s*'([^']+)'", block)
        out = re.search(r"output_path\s*=\s*'([^']+)'", block)
        if inp and out:
            pairs.append((name, os.path.expanduser(inp.group(1)), os.path.expanduser(out.group(1))))
    return pairs


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".glassy-tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


# ------------------------------------------------------------------ Hyprland + Kitty
def hypr_values(cfg, border):
    """glassy-generated.lua: Rahmenfarben + Schalter aus den Einstellungen."""
    g = deep_get(cfg, ["glassy"], {}) or {}
    a, b, c, inactive = border
    lua = (
        "-- claudes-glassy: automatisch erzeugt von glassy_theme.py - nicht von Hand aendern.\n"
        "-- Einstellungen: SUPER+I -> Glassy\n"
        "return {\n"
        f'    border_a = "rgba({a.lstrip("#")}ee)",\n'
        f'    border_b = "rgba({b.lstrip("#")}ee)",\n'
        f'    border_c = "rgba({c.lstrip("#")}ee)",\n'
        f'    border_inactive = "rgba({inactive.lstrip("#")}88)",\n'
        f"    border_anim = {'true' if g.get('borderAnimation', False) else 'false'},\n"
        f"    performance = {'true' if g.get('performanceMode', False) else 'false'},\n"
        "}\n"
    )
    write(HYPR_GEN, lua)


def read_generated_colors():
    try:
        with open(os.path.join(GEN_DIR, "colors.json"), encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def border_from_m3(c):
    return (c.get("primary", "#7aa2f7"), c.get("secondary", "#bb9af7"), c.get("tertiary", "#ff79c6"),
            c.get("surface_container_high", "#292e42"))


def kitty_theme(colors_m3, term, opacity):
    lines = [
        "# claudes-glassy: automatisch erzeugt von glassy_theme.py",
        f"background_opacity {opacity}",
        f"foreground {term['term7']}",
        f"background {term['term0']}",
        f"cursor {colors_m3['primary']}",
        f"cursor_text_color {term['term0']}",
        f"selection_foreground {colors_m3['on_secondary_container']}",
        f"selection_background {colors_m3['secondary_container']}",
        f"url_color {colors_m3['tertiary']}",
        f"active_tab_foreground {colors_m3['on_primary']}",
        f"active_tab_background {colors_m3['primary']}",
        f"inactive_tab_foreground {colors_m3['on_surface']}",
        f"inactive_tab_background {colors_m3['surface_container']}",
        f"tab_bar_background {colors_m3['surface_dim']}",
    ]
    lines += [f"color{i} {term[f'term{i}']}" for i in range(16)]
    write(KITTY_THEME, "\n".join(lines) + "\n")


def kitty_material(opacity):
    gen = os.path.join(GEN_DIR, "terminal", "kitty-theme.conf")
    write(KITTY_THEME, "# claudes-glassy: Material You (Farben vom Wallpaper)\n"
          f"include {gen}\nbackground_opacity {opacity}\n")


def reload_apps(reload_hypr=True):
    subprocess.run(["bash", "-c", "pkill -SIGUSR1 -x kitty"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if reload_hypr and os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        subprocess.run(["hyprctl", "reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def glass_levels(glass):
    """Shell-Transparenz aus dem Glas-Wert des Themes."""
    bg_t = max(0.18, min(0.66, 0.30 + (1.0 - glass) * 0.62))  # max 0.66: Blur braucht Deckkraft > 0.3 (ignore_alpha)
    content_t = max(0.40, min(0.85, 0.50 + (1.0 - glass) * 0.40))
    return round(bg_t, 3), round(content_t, 3)


# ------------------------------------------------------------------ Befehle
def apply(name, reload_hypr=True):
    if name not in ALL_NAMES:
        print(f"Unbekanntes Theme: {name}\nVerfuegbar: {', '.join(ALL_NAMES)}", file=sys.stderr)
        return 1
    cfg = load_config()
    previous = deep_get(cfg, ["glassy", "theme"], DEFAULT)
    deep_set(cfg, ["glassy", "theme"], name)
    deep_set(cfg, ["appearance", "transparency", "enable"], True)
    deep_set(cfg, ["appearance", "transparency", "automatic"], False)

    if name == MATERIAL:
        deep_set(cfg, ["appearance", "wallpaperTheming", "enableAppsAndShell"], True)
        deep_set(cfg, ["appearance", "wallpaperTheming", "enableTerminal"], True)
        bg_t, content_t = glass_levels(0.9)
        deep_set(cfg, ["appearance", "transparency", "backgroundTransparency"], bg_t)
        deep_set(cfg, ["appearance", "transparency", "contentTransparency"], content_t)
        save_config(cfg)
        switchwall = os.path.join(SCRIPT_DIR, "switchwall.sh")
        res = subprocess.run(["bash", switchwall, "--noswitch"], capture_output=True, text=True)
        scss = os.path.join(GEN_DIR, "material_colors.scss")
        try:
            ok = "$term0: #" in open(scss, encoding="utf-8").read()
        except OSError:
            ok = False
        if not ok:
            # Farb-Erzeugung (Python-venv) kaputt -> zurueck zum vorherigen Theme statt kaputter Farben
            fallback = previous if previous in THEMES else DEFAULT
            msg = ("Material You fehlgeschlagen: die Python-Umgebung fuer die Farb-Erzeugung fehlt oder ist kaputt "
                   f"({os.path.join(XDG_STATE, 'quickshell', '.venv')}). Reparieren: bash ~/.local/share/claudes-glassy/install.sh --install "
                   f"-> zurueck zu {LABELS[fallback]}")
            print(msg, file=sys.stderr)
            tail = (res.stderr or res.stdout or "").strip().splitlines()[-5:]
            if tail:
                print("  " + "\n  ".join(tail), file=sys.stderr)
            try:
                subprocess.run(["notify-send", "-a", "claudes-glassy", "Material You fehlgeschlagen", msg],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            except OSError:
                pass
            apply(fallback, reload_hypr)
            return 2
        c = read_generated_colors()
        hypr_values(cfg, border_from_m3(c))
        kitty_material(0.75)
        reload_apps(reload_hypr)
        print(f"Theme: {LABELS[name]}")
        return 0

    t = THEMES[name]
    colors = m3_from_palette(t)
    term = term_from_palette(t)

    # Statisches Theme: matugen soll beim Wallpaper-Wechsel NICHT drueberschreiben
    deep_set(cfg, ["appearance", "wallpaperTheming", "enableAppsAndShell"], False)
    bg_t, content_t = glass_levels(t["glass"])
    deep_set(cfg, ["appearance", "transparency", "backgroundTransparency"], bg_t)
    deep_set(cfg, ["appearance", "transparency", "contentTransparency"], content_t)
    save_config(cfg)

    wallpaper = deep_get(cfg, ["background", "wallpaperPath"], "") or ""
    for tname, inp, out in matugen_targets():
        if tname in ("kde_colors",):
            continue
        try:
            template = open(inp, encoding="utf-8").read()
        except OSError:
            continue
        write(out, render(template, colors, wallpaper))

    # Fuer applycolor.sh (Terminal-Farben in allen offenen Terminals)
    scss = ["$darkmode: True;", "$transparent: False;"]
    camel = lambda k: re.sub(r"_([a-z])", lambda m: m.group(1).upper(), k)
    scss += [f"${camel(k)}: {v};" for k, v in colors.items()]
    scss += [f"${k}: {v};" for k, v in term.items()]
    write(os.path.join(GEN_DIR, "material_colors.scss"), "\n".join(scss) + "\n")
    applycolor = os.path.join(SCRIPT_DIR, "applycolor.sh")
    if os.path.exists(applycolor):
        subprocess.Popen(["bash", applycolor], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"],
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    hypr_values(cfg, (colors["primary"], colors["secondary"], colors["tertiary"], colors["surface_container_high"]))
    kitty_theme(colors, term, t["term"])
    reload_apps(reload_hypr)
    print(f"Theme: {t['label']}")
    return 0


def sync(reload_hypr=True):
    cfg = load_config()
    name = current()
    if name == MATERIAL:
        border = border_from_m3(read_generated_colors())
    else:
        c = m3_from_palette(THEMES[name])
        border = (c["primary"], c["secondary"], c["tertiary"], c["surface_container_high"])
    hypr_values(cfg, border)
    if reload_hypr and os.environ.get("HYPRLAND_INSTANCE_SIGNATURE"):
        subprocess.run(["hyprctl", "reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return 0


def merge_defaults(path, force=False):
    try:
        with open(path, encoding="utf-8") as f:
            defaults = json.loads(f.read().replace("@HOME@", HOME))
    except (OSError, ValueError) as e:
        print(f"Standardwerte nicht lesbar: {e}", file=sys.stderr)
        return 1
    cfg = load_config()
    added = 0

    def walk(src, dst):
        nonlocal added
        for k, v in src.items():
            if isinstance(v, dict):
                if not isinstance(dst.get(k), dict):
                    dst[k] = {}
                walk(v, dst[k])
            elif force or k not in dst:
                if dst.get(k) != v:
                    added += 1
                dst[k] = v
    walk(defaults, cfg)
    save_config(cfg)
    print(f"{added} Standardwert(e) uebernommen")
    return 0


def main(argv):
    if not argv or argv[0] in ("-h", "--help", "help"):
        head = open(__file__, encoding="utf-8").read().split("# ====")[1]
        print("\n".join(l[2:] for l in head.splitlines()[1:]))
        return 0
    cmd, rest = argv[0], argv[1:]
    no_reload = "--no-reload" in rest
    rest = [a for a in rest if not a.startswith("--")]
    if cmd == "list":
        cur = current()
        for n in ALL_NAMES:
            mark = "*" if n == cur else " "
            desc = THEMES[n]["desc"] if n in THEMES else "Farben automatisch aus dem Wallpaper"
            print(f" {mark} {n:<11} {LABELS[n]:<34} {desc}")
        return 0
    if cmd == "current":
        print(current())
        return 0
    if cmd == "apply":
        return apply(rest[0] if rest else current(), reload_hypr=not no_reload)
    if cmd == "defaults":
        if not rest:
            print("Benutzung: glassy_theme.py defaults DATEI", file=sys.stderr)
            return 1
        return merge_defaults(os.path.expanduser(rest[0]), force="--force" in argv)
    if cmd == "sync":
        return sync(reload_hypr=not no_reload)
    print(f"Unbekannter Befehl: {cmd}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
