#!/usr/bin/env python3
# ==================================================================
#  claudes-glassy  -  Einstellungen (Tokyo Night)              SUPER+I
#  Alle Optionen an einem Ort. Aenderungen gelten sofort.
#
#  Speichert:  ~/.config/hypr/glassy-settings.json      (alles, was hier steht)
#  Erzeugt:    ~/.config/hypr/glassy-settings.lua       (Hyprland: Aussehen, Eingabe, Apps)
#              ~/.config/waybar/config.jsonc            (Bar)
#              ~/.config/hypr/hypridle.conf             (Sperren & Energie)
#              ~/.config/hypr/hyprlock.conf             (Sperrbildschirm)
#              ~/.config/hypr/startmenu/settings.json   (Startmenue)
#              ~/.config/hypr/island/settings.json      (Dynamic Island)
#
#  Ohne Fenster neu anwenden (z. B. nach einem Update):
#     python3 ~/.config/hypr/settings/glassy_settings.py --apply
# ==================================================================
import argparse
import copy
import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
HYPR = os.path.join(HOME, ".config", "hypr")
STORE = os.path.join(HYPR, "glassy-settings.json")
LUA_OUT = os.path.join(HYPR, "glassy-settings.lua")
WAYBAR_OUT = os.path.join(HOME, ".config", "waybar", "config.jsonc")
IDLE_OUT = os.path.join(HYPR, "hypridle.conf")
LOCK_OUT = os.path.join(HYPR, "hyprlock.conf")
STARTMENU_JSON = os.path.join(HYPR, "startmenu", "settings.json")
ISLAND_JSON = os.path.join(HYPR, "island", "settings.json")
REPO = os.path.join(HOME, ".local", "share", "claudes-glassy")
SCRIPTS = os.path.join(HYPR, "scripts")

DEFAULTS = {
    # Aussehen (Hyprland)
    "gaps_in": 6, "gaps_out": 14, "border_size": 2, "rounding": 16,
    "blur": True, "blur_passes": 3, "blur_size": 8,
    "inactive_opacity": 0.94, "dim_inactive": True,
    "animations": True, "border_anim": True, "shadow": True,
    # Eingabe
    "kb_layout": "de", "sensitivity": 0.0, "accel_flat": True, "natural_scroll": False,
    "follow_mouse": True, "numlock": True,
    # Apps
    "terminal": "kitty", "fileManager": "dolphin", "browser": "firefox",
    # Startmenue
    "sm_show_avatar": False, "sm_show_clock": True, "sm_show_recent": True,
    "sm_show_desc": True, "sm_hover_categories": False,
    # Dynamic Island
    "island_enabled": True, "island_all_monitors": True, "island_auto_expand": False,
    "island_show_volume": True, "island_clock_seconds": False,
    # Bar
    "bar_all_monitors": True, "bar_show_search": True, "bar_show_window": True,
    "bar_show_stats": True, "bar_show_tray": True, "bar_main_monitor": "DP-3",
    # Sperren & Energie
    "lock_minutes": 10, "screen_off_minutes": 12, "suspend_minutes": 0,
    # Sperrbildschirm
    "lock_accent": "blue", "lock_clock_size": "large", "lock_clock_font": "thin",
    "lock_show_date": True, "lock_show_greeting": True, "lock_show_music": True,
    "lock_show_info": True, "lock_show_icon": True, "lock_dim": 0.45, "lock_blur": 3,
    "lock_input_fade": True, "lock_other_monitors": True,
}

ACCENTS = {   # (Hauptfarbe, Verlauf-Partner) - Tokyo Night
    "blue": ("7aa2f7", "7dcfff"), "purple": ("bb9af7", "7aa2f7"), "cyan": ("7dcfff", "2ac3de"),
    "pink": ("ff79c6", "bb9af7"), "green": ("9ece6a", "73daca"), "orange": ("ff9e64", "e0af68"),
}
CLOCK_SIZES = {"small": 84, "medium": 104, "large": 124, "huge": 156}
CLOCK_FONTS = {"thin": "Inter Light", "regular": "Inter Medium", "bold": "Inter ExtraBold",
               "mono": "JetBrainsMono Nerd Font"}


# ------------------------------------------------------------------ Speichern / Laden
def load():
    s = copy.deepcopy(DEFAULTS)
    have_store = False
    try:
        with open(STORE, encoding="utf-8") as f:
            s.update({k: v for k, v in json.load(f).items() if k in DEFAULTS})
        have_store = True
    except (FileNotFoundError, ValueError):
        pass
    # Im Startmenue selbst (Regler-Symbol) geaendert? Dann diese Werte nehmen.
    try:
        newer = (not have_store) or os.path.getmtime(STARTMENU_JSON) > os.path.getmtime(STORE)
        if newer:
            with open(STARTMENU_JSON, encoding="utf-8") as f:
                old = json.load(f)
            for k in ("show_avatar", "show_clock", "show_recent", "show_desc", "hover_categories"):
                if k in old:
                    s["sm_" + k] = bool(old[k])
    except (OSError, ValueError):
        pass
    return s


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def sh(cmd):
    env = dict(os.environ)
    env.pop("LD_PRELOAD", None)
    subprocess.Popen(cmd, shell=True, start_new_session=True, env=env,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def lua_str(v):
    return '"' + str(v).replace("\\", "\\\\").replace('"', '\\"') + '"'


# ------------------------------------------------------------------ Erzeugen
def gen_lua(s):
    b = lambda v: "true" if v else "false"  # noqa: E731
    return f"""-- Automatisch erzeugt von den claudes-glassy Einstellungen (SUPER+I).
-- Nicht von Hand bearbeiten - Aenderungen hier werden ueberschrieben.
return {{
    apps = {{
        terminal    = {lua_str(s["terminal"])},
        fileManager = {lua_str(s["fileManager"])},
        browser     = {lua_str(s["browser"])},
    }},
    border_anim = {b(s["border_anim"])},
    config = {{
        general = {{
            gaps_in = {int(s["gaps_in"])},
            gaps_out = {int(s["gaps_out"])},
            border_size = {int(s["border_size"])},
        }},
        decoration = {{
            rounding = {int(s["rounding"])},
            inactive_opacity = {float(s["inactive_opacity"]):.2f},
            dim_inactive = {b(s["dim_inactive"])},
            shadow = {{ enabled = {b(s["shadow"])} }},
            blur = {{
                enabled = {b(s["blur"])},
                passes = {int(s["blur_passes"])},
                size = {int(s["blur_size"])},
            }},
        }},
        animations = {{ enabled = {b(s["animations"])} }},
        input = {{
            kb_layout = {lua_str(s["kb_layout"])},
            sensitivity = {float(s["sensitivity"]):.2f},
            accel_profile = {lua_str("flat" if s["accel_flat"] else "adaptive")},
            follow_mouse = {1 if s["follow_mouse"] else 0},
            numlock_by_default = {b(s["numlock"])},
            natural_scroll = {b(s["natural_scroll"])},
        }},
    }},
}}
"""


def strip_jsonc(text):
    out, i, n, in_str = [], 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            if c == '"':
                in_str = False
            i += 1
            continue
        if c == '"':
            in_str = True
            out.append(c)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            j = text.find("*/", i + 2)
            i = n if j < 0 else j + 2
            continue
        else:
            out.append(c)
        i += 1
    return "".join(out)


def gen_waybar(s):
    template = os.path.join(REPO, "config", "waybar", "config.jsonc")
    src = template if os.path.exists(template) else WAYBAR_OUT
    try:
        with open(src, encoding="utf-8") as f:
            cfg = json.loads(strip_jsonc(f.read()))
    except (OSError, ValueError) as e:
        print("Waybar-Vorlage nicht lesbar:", e, file=sys.stderr)
        return None
    if s["bar_all_monitors"]:
        cfg.pop("output", None)
    else:
        cfg["output"] = [s["bar_main_monitor"]]
    left = [m for m in cfg.get("modules-left", [])]
    if not s["bar_show_search"]:
        left = [m for m in left if m != "custom/search"]
    if not s["bar_show_window"]:
        left = [m for m in left if m != "hyprland/window"]
    cfg["modules-left"] = left
    right = [m for m in cfg.get("modules-right", [])]
    if not s["bar_show_stats"]:
        right = [m for m in right if m not in ("cpu", "memory")]
    if not s["bar_show_tray"]:
        right = [m for m in right if m != "tray"]
    cfg["modules-right"] = right
    # Island aus -> Uhr wieder in die Mitte der Leiste
    cfg["modules-center"] = [] if s["island_enabled"] else ["clock"]
    head = ("// Automatisch erzeugt von den claudes-glassy Einstellungen (SUPER+I).\n"
            "// Vorlage: ~/.local/share/claudes-glassy/config/waybar/config.jsonc\n")
    return head + json.dumps(cfg, indent=4, ensure_ascii=False) + "\n"


def gen_idle(s):
    lock = int(s["lock_minutes"])
    off = int(s["screen_off_minutes"])
    susp = int(s["suspend_minutes"])
    parts = ["""# Automatisch erzeugt von den claudes-glassy Einstellungen (SUPER+I).
general {
    lock_cmd = pidof hyprlock || hyprlock
    before_sleep_cmd = loginctl lock-session
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
    ignore_dbus_inhibit = false
}
"""]
    if lock > 0:
        parts.append(f"""
listener {{
    timeout = {lock * 60}
    on-timeout = loginctl lock-session
}}
""")
    if off > 0:
        parts.append(f"""
listener {{
    timeout = {off * 60}
    on-timeout = hyprctl dispatch 'hl.dsp.dpms({{ action = "disable" }})'
    on-resume = hyprctl dispatch 'hl.dsp.dpms({{ action = "enable" }})'
}}
""")
    if susp > 0:
        parts.append(f"""
listener {{
    timeout = {susp * 60}
    on-timeout = systemctl suspend
}}
""")
    return "".join(parts)


def gen_lock(s):
    a1, a2 = ACCENTS.get(s["lock_accent"], ACCENTS["blue"])
    size = CLOCK_SIZES.get(s["lock_clock_size"], 124)
    font = CLOCK_FONTS.get(s["lock_clock_font"], "Inter Light")
    script = "~/.config/hypr/scripts/lockinfo.sh"
    mon = s.get("bar_main_monitor", "DP-3")
    k = size / 124.0                       # Abstaende mit der Uhrgroesse skalieren
    y_time = 222
    y_date = int(y_time + 80 * k + 40)
    y_icon = y_date + 55
    y_greet = int(y_time - 80 * k - 40)
    out = [f"""# Automatisch erzeugt von den claudes-glassy Einstellungen (SUPER+I -> Sperrbildschirm).
# hyprlock nutzt hyprlang-Syntax. Doku: https://wiki.hypr.land/Hypr-Ecosystem/hyprlock/

general {{
    hide_cursor = true
    ignore_empty_input = true
    grace = 2
    fail_timeout = 1200
}}

animations {{
    enabled = true
    bezier = smooth, 0.25, 1, 0.5, 1
    animation = fadeIn, 1, 6, smooth
    animation = fadeOut, 1, 5, smooth
    animation = inputFieldDots, 1, 2, smooth
}}

background {{
    monitor =
    path = ~/.cache/claudes-glassy/wallpaper
    color = rgb(1a1b26)
    blur_passes = {int(s["lock_blur"])}
    blur_size = 9
    noise = 0.012
    contrast = 0.92
    brightness = {float(s["lock_dim"]):.2f}
    vibrancy = 0.22
    vibrancy_darkness = 0.15
}}
"""]
    if s["lock_show_icon"]:
        out.append(f"""
label {{
    monitor = {mon}
    text = <span foreground="##{a1}">&##xf023;</span>
    font_size = 16
    font_family = JetBrainsMono Nerd Font
    position = 0, {y_icon}
    halign = center
    valign = center
}}
""")
    if s["lock_show_date"]:
        out.append(f"""
label {{
    monitor = {mon}
    text = cmd[update:60000] {script} date
    color = rgba(a9b1d6cc)
    font_size = 19
    font_family = Inter Medium
    position = 0, {y_date}
    halign = center
    valign = center
}}
""")
    out.append(f"""
label {{
    monitor = {mon}
    text = cmd[update:1000] date +"%H:%M"
    color = rgba(c0caf5ff)
    font_size = {size}
    font_family = {font}
    position = 0, {y_time}
    halign = center
    valign = center
    shadow_passes = 3
    shadow_size = 10
    shadow_color = rgba(0,0,0,0.45)
}}
""")
    if s["lock_show_greeting"]:
        out.append(f"""
label {{
    monitor = {mon}
    text = cmd[update:60000] {script} greet
    color = rgba(565f89ff)
    font_size = 15
    font_family = Inter Medium
    position = 0, {y_greet}
    halign = center
    valign = center
}}
""")
    if s["lock_show_music"]:
        out.append(f"""
image {{
    monitor = {mon}
    path = ~/.config/hypr/lock/empty.png
    reload_time = 2
    reload_cmd = {script} cover
    size = 88
    rounding = 18
    border_size = 0
    position = 0, -10
    halign = center
    valign = center
}}

label {{
    monitor = {mon}
    text = cmd[update:2000] {script} title
    color = rgba(c0caf5ff)
    font_size = 15
    font_family = Inter Bold
    position = 0, -86
    halign = center
    valign = center
}}

label {{
    monitor = {mon}
    text = cmd[update:2000] {script} artist
    color = rgba(a9b1d6cc)
    font_size = 12
    font_family = Inter Medium
    position = 0, -110
    halign = center
    valign = center
}}
""")
    out.append(f"""
input-field {{
    monitor = {mon}
    size = 290, 46
    outline_thickness = 2
    dots_size = 0.22
    dots_spacing = 0.45
    dots_center = true
    dots_rounding = -1
    outer_color = rgba({a2}aa) rgba({a1}aa) 45deg
    inner_color = rgba(16161ecc)
    font_color = rgba(c0caf5ff)
    font_family = Inter Medium
    check_color = rgba({a1}ee) rgba({a2}ee) 45deg
    fail_color = rgba(f7768eee) rgba(ff9e64ee) 45deg
    capslock_color = rgba(e0af68ee)
    placeholder_text = <span foreground="##565f89">Passwort</span>
    fail_text = <span foreground="##f7768e">Falsch  ($ATTEMPTS)</span>
    fade_on_empty = {"true" if s["lock_input_fade"] else "false"}
    fade_timeout = 4000
    rounding = -1
    position = 0, 120
    halign = center
    valign = bottom
}}
""")
    if s["lock_show_info"]:
        out.append(f"""
label {{
    monitor = {mon}
    text = <span foreground="##{a1}">&##xf11c;</span>   $LAYOUT
    color = rgba(565f89ff)
    font_size = 11
    font_family = JetBrainsMono Nerd Font
    position = 36, 28
    halign = left
    valign = bottom
}}

label {{
    monitor = {mon}
    text = cmd[update:60000] {script} uptime
    color = rgba(565f89ff)
    font_size = 11
    font_family = Inter Medium
    position = -36, 28
    halign = right
    valign = bottom
}}
""")
    if s["lock_other_monitors"]:
        for m in monitor_names():
            if m == mon:
                continue
            out.append(f"""
label {{
    monitor = {m}
    text = cmd[update:1000] date +"%H:%M"
    color = rgba(c0caf5dd)
    font_size = 84
    font_family = {font}
    position = 0, 20
    halign = center
    valign = center
}}
""")
    return "".join(out)


def apply_all(s, what=None, quiet=False):
    """Schreibt die Dateien und laedt die betroffenen Teile neu.
    what = None -> alles, sonst Menge aus {'hypr','bar','idle','startmenu','island'}"""
    what = what or {"hypr", "bar", "idle", "startmenu", "island", "lock"}
    with open(STORE + ".tmp", "w", encoding="utf-8") as f:
        json.dump(s, f, indent=2, ensure_ascii=False)
    os.replace(STORE + ".tmp", STORE)

    if "hypr" in what:
        write(LUA_OUT, gen_lua(s))
        if not quiet:
            sh("hyprctl reload")
    if "bar" in what:
        txt = gen_waybar(s)
        if txt:
            write(WAYBAR_OUT, txt)
            if not quiet:
                sh("pkill -x waybar; sleep 0.3; setsid -f waybar")
    if "idle" in what:
        write(IDLE_OUT, gen_idle(s))
        if not quiet:
            sh("pkill -x hypridle; sleep 0.2; setsid -f hypridle")
    if "lock" in what:
        write(LOCK_OUT, gen_lock(s))
    if "startmenu" in what:
        write(STARTMENU_JSON, json.dumps({
            "show_avatar": s["sm_show_avatar"], "show_clock": s["sm_show_clock"],
            "show_recent": s["sm_show_recent"], "show_desc": s["sm_show_desc"],
            "hover_categories": s["sm_hover_categories"]}, indent=2))
        if not quiet:
            sh("pkill -f 'startmenu.py --daemon'")      # naechstes Super startet mit neuen Werten
    if "island" in what:
        write(ISLAND_JSON, json.dumps({
            "enabled": s["island_enabled"], "all_monitors": s["island_all_monitors"],
            "auto_expand": s["island_auto_expand"], "show_volume": s["island_show_volume"],
            "clock_seconds": s["island_clock_seconds"], "main_monitor": s["bar_main_monitor"]}, indent=2))
        if not quiet:
            if s["island_enabled"]:
                sh(os.path.join(SCRIPTS, "island.sh") + " restart")
            else:
                sh("pkill -f island/island.py")


# ------------------------------------------------------------------ GUI
def run_gui():
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Gdk", "4.0")
    from gi.repository import Gdk, Gio, GLib, Gtk

    CSS = r"""
@define-color tn_bg      #1a1b26;
@define-color tn_bg_dark #16161e;
@define-color tn_hl      #292e42;
@define-color tn_fg      #c0caf5;
@define-color tn_fg_dark #a9b1d6;
@define-color tn_comment #565f89;
@define-color tn_blue    #7aa2f7;
@define-color tn_cyan    #7dcfff;
@define-color tn_purple  #bb9af7;
@define-color tn_green   #9ece6a;
@define-color tn_red     #f7768e;

window.glassy, window.glassy.background { background-color: alpha(@tn_bg, 0.93); color: @tn_fg; }
window.glassy * { font-family: "Inter", "JetBrainsMono Nerd Font", sans-serif; }
.side { background-color: alpha(@tn_bg_dark, 0.85); padding: 14px 8px; }
.apptitle { font-size: 15px; font-weight: 800; color: @tn_fg; margin: 4px 10px 14px 10px; }
.side list { background: transparent; }
.side row { min-height: 34px; padding: 0 10px; margin: 1px 0; border-radius: 9px; color: @tn_fg_dark; }
.side row:hover { background-color: alpha(@tn_hl, 0.7); color: @tn_fg; }
.side row:selected { background-color: alpha(@tn_blue, 0.16); color: @tn_blue; box-shadow: inset 2px 0 0 @tn_blue; }
.sglyph { font-family: "JetBrainsMono Nerd Font"; min-width: 18px; font-size: 12px; }
.sname  { font-size: 12.5px; font-weight: 600; }

.page { padding: 20px 26px; }
.ptitle { font-size: 20px; font-weight: 800; color: @tn_fg; }
.psub   { font-size: 11.5px; color: @tn_comment; margin-bottom: 10px; }
.group  { font-size: 10px; font-weight: 800; color: @tn_comment; letter-spacing: 1px; margin: 14px 4px 6px 4px; }
.card   { background-color: alpha(@tn_hl, 0.35); border-radius: 12px; border: 1px solid alpha(@tn_blue, 0.10); }
.opt    { padding: 10px 14px; }
.opt + .opt { border-top: 1px solid alpha(@tn_comment, 0.18); }
.olabel { font-size: 12.5px; font-weight: 600; color: @tn_fg; }
.odesc  { font-size: 10.5px; color: @tn_comment; }

switch { background-color: @tn_hl; border: none; }
switch:checked { background-color: @tn_blue; }
switch slider { background-color: @tn_fg; background-image: none; border: none; box-shadow: none; min-width: 18px; min-height: 18px; }
spinbutton, dropdown > button, entry.text {
    background-color: alpha(@tn_bg_dark, 0.85); color: @tn_fg;
    border: 1px solid alpha(@tn_blue, 0.20); border-radius: 8px; box-shadow: none;
}
scale trough { background-color: @tn_hl; border-radius: 99px; min-height: 4px; }
scale highlight { background-image: linear-gradient(90deg, @tn_purple, @tn_blue); border-radius: 99px; }
scale slider { background-color: @tn_fg; border: none; min-width: 14px; min-height: 14px; border-radius: 99px; }
button.act {
    background-color: alpha(@tn_blue, 0.14); color: @tn_blue;
    border: 1px solid alpha(@tn_blue, 0.30); border-radius: 9px; padding: 6px 14px; box-shadow: none;
}
button.act:hover { background-color: alpha(@tn_blue, 0.28); }
button.act.danger { background-color: alpha(@tn_red, 0.10); color: @tn_red; border-color: alpha(@tn_red, 0.30); }
.toast { background-color: alpha(@tn_green, 0.15); color: @tn_green; border-radius: 99px; padding: 4px 12px;
         font-size: 11px; font-weight: 700; }
.ver { font-size: 10.5px; color: @tn_comment; }
"""

    s = load()
    pending = {"what": set(), "id": 0}

    class Win(Gtk.ApplicationWindow):
        def __init__(self, app):
            super().__init__(application=app, title="Einstellungen")
            self.add_css_class("glassy")
            self.set_default_size(880, 620)

            root = Gtk.Box()
            self.set_child(root)

            side = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            side.add_css_class("side")
            side.set_size_request(210, -1)
            t = Gtk.Label(label="   Einstellungen", xalign=0)
            t.add_css_class("apptitle")
            side.append(t)
            self.nav = Gtk.ListBox()
            self.nav.set_selection_mode(Gtk.SelectionMode.SINGLE)
            side.append(self.nav)
            sp = Gtk.Box()
            sp.set_vexpand(True)
            side.append(sp)
            self.toast = Gtk.Label(label="")
            self.toast.add_css_class("toast")
            self.toast.set_visible(False)
            self.toast.set_margin_start(6)
            self.toast.set_margin_end(6)
            side.append(self.toast)
            root.append(side)

            self.stack = Gtk.Stack()
            self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
            self.stack.set_transition_duration(120)
            self.stack.set_hexpand(True)
            root.append(self.stack)

            pages = [
                ("look", "", "Aussehen", self.page_look),
                ("start", "", "Startmenü", self.page_start),
                ("island", "", "Dynamic Island", self.page_island),
                ("bar", "", "Leiste", self.page_bar),
                ("input", "", "Eingabe", self.page_input),
                ("lock", "\uf023", "Sperrbildschirm", self.page_lock),
                ("power", "", "Sperren & Energie", self.page_power),
                ("apps", "", "Standard-Apps", self.page_apps),
                ("wall", "", "Hintergrund", self.page_wall),
                ("system", "", "System", self.page_system),
            ]
            for key, gl, name, builder in pages:
                row = Gtk.ListBoxRow()
                row._key = key
                b = Gtk.Box(spacing=10)
                g = Gtk.Label(label=gl)
                g.add_css_class("sglyph")
                n = Gtk.Label(label=name, xalign=0)
                n.add_css_class("sname")
                b.append(g)
                b.append(n)
                row.set_child(b)
                self.nav.append(row)
                sw = Gtk.ScrolledWindow()
                sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
                sw.set_child(builder())
                self.stack.add_named(sw, key)
            self.nav.connect("row-selected", lambda lb, r: r and self.stack.set_visible_child_name(r._key))
            self.nav.select_row(self.nav.get_row_at_index(0))

            keys = Gtk.EventControllerKey()
            keys.connect("key-pressed", lambda c, kv, kc, st: (self.close(), True)[1] if kv == Gdk.KEY_Escape else False)
            self.add_controller(keys)

        # ---------- Bausteine ----------
        def page(self, title, sub):
            box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            box.add_css_class("page")
            t = Gtk.Label(label=title, xalign=0)
            t.add_css_class("ptitle")
            st = Gtk.Label(label=sub, xalign=0)
            st.add_css_class("psub")
            st.set_wrap(True)
            box.append(t)
            box.append(st)
            return box

        def group(self, page, title):
            g = Gtk.Label(label=title.upper(), xalign=0)
            g.add_css_class("group")
            page.append(g)
            card = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            card.add_css_class("card")
            page.append(card)
            return card

        def row(self, card, label, desc, widget):
            r = Gtk.Box(spacing=14)
            r.add_css_class("opt")
            tb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
            tb.set_hexpand(True)
            tb.set_valign(Gtk.Align.CENTER)
            l = Gtk.Label(label=label, xalign=0)
            l.add_css_class("olabel")
            tb.append(l)
            if desc:
                d = Gtk.Label(label=desc, xalign=0)
                d.add_css_class("odesc")
                d.set_wrap(True)
                tb.append(d)
            r.append(tb)
            widget.set_valign(Gtk.Align.CENTER)
            r.append(widget)
            card.append(r)

        def changed(self, key, value, what):
            s[key] = value
            pending["what"] |= set(what)
            if pending["id"]:
                GLib.source_remove(pending["id"])
            pending["id"] = GLib.timeout_add(450, self.flush)

        def flush(self):
            pending["id"] = 0
            w, pending["what"] = pending["what"], set()
            apply_all(s, w)
            self.toast.set_label("  Gespeichert")
            self.toast.set_visible(True)
            GLib.timeout_add(1600, lambda: (self.toast.set_visible(False), False)[1])
            return False

        def sw(self, card, key, label, desc, what):
            w = Gtk.Switch()
            w.set_active(bool(s[key]))
            w.connect("notify::active", lambda x, _p: self.changed(key, x.get_active(), what))
            self.row(card, label, desc, w)

        def spin(self, card, key, label, desc, lo, hi, step, what, digits=0):
            w = Gtk.SpinButton.new_with_range(lo, hi, step)
            w.set_digits(digits)
            w.set_value(float(s[key]))
            w.connect("value-changed", lambda x: self.changed(key, round(x.get_value(), digits) if digits else int(x.get_value()), what))
            self.row(card, label, desc, w)

        def slider(self, card, key, label, desc, lo, hi, step, what):
            w = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, lo, hi, step)
            w.set_size_request(200, -1)
            w.set_value(float(s[key]))
            w.set_draw_value(True)
            w.set_digits(2)
            w.connect("value-changed", lambda x: self.changed(key, round(x.get_value(), 2), what))
            self.row(card, label, desc, w)

        def choice(self, card, key, label, desc, options, what):
            # options: [(wert, anzeige)]
            names = [o[1] for o in options]
            w = Gtk.DropDown.new_from_strings(names)
            vals = [o[0] for o in options]
            if s[key] in vals:
                w.set_selected(vals.index(s[key]))
            w.connect("notify::selected", lambda x, _p: self.changed(key, vals[x.get_selected()], what))
            self.row(card, label, desc, w)

        def text(self, card, key, label, desc, what):
            w = Gtk.Entry()
            w.add_css_class("text")
            w.set_text(str(s[key]))
            w.set_width_chars(16)
            w.connect("changed", lambda x: self.changed(key, x.get_text().strip() or DEFAULTS[key], what))
            self.row(card, label, desc, w)

        def button(self, card, label, desc, btn_label, cmd, danger=False):
            b = Gtk.Button(label=btn_label)
            b.add_css_class("act")
            if danger:
                b.add_css_class("danger")
            b.connect("clicked", lambda *_: sh(cmd))
            self.row(card, label, desc, b)

        # ---------- Seiten ----------
        def page_look(self):
            p = self.page("Aussehen", "Fenster, Abstände, Glas-Effekt und Animationen.")
            c = self.group(p, "Fenster")
            self.spin(c, "gaps_in", "Abstand zwischen Fenstern", "Pixel", 0, 40, 1, {"hypr"})
            self.spin(c, "gaps_out", "Abstand zum Bildschirmrand", "Pixel", 0, 60, 1, {"hypr"})
            self.spin(c, "rounding", "Runde Ecken", "Radius in Pixel", 0, 32, 1, {"hypr"})
            self.spin(c, "border_size", "Rahmendicke", "Pixel (0 = kein Rahmen)", 0, 8, 1, {"hypr"})
            self.slider(c, "inactive_opacity", "Deckkraft inaktiver Fenster", "1.00 = gar nicht durchsichtig", 0.5, 1.0, 0.01, {"hypr"})
            self.sw(c, "dim_inactive", "Inaktive Fenster abdunkeln", None, {"hypr"})
            self.sw(c, "shadow", "Schatten", None, {"hypr"})
            c = self.group(p, "Glas")
            self.sw(c, "blur", "Blur (Glas-Effekt)", "Kostet etwas GPU", {"hypr"})
            self.spin(c, "blur_passes", "Blur-Durchgänge", "Mehr = weicher, aber teurer", 1, 6, 1, {"hypr"})
            self.spin(c, "blur_size", "Blur-Stärke", None, 1, 20, 1, {"hypr"})
            c = self.group(p, "Animationen")
            self.sw(c, "animations", "Animationen", "Fenster, Workspaces, Menüs", {"hypr"})
            self.sw(c, "border_anim", "Drehender Rahmen-Verlauf", "Aus = weniger GPU-Last", {"hypr"})
            return p

        def page_start(self):
            p = self.page("Startmenü", "Super antippen oder auf den Start-Knopf klicken.")
            c = self.group(p, "Verhalten")
            self.sw(c, "sm_hover_categories", "Kategorie beim Drüberfahren wechseln",
                    "Aus = Kategorie wechselt erst beim Klicken", {"startmenu"})
            c = self.group(p, "Anzeige")
            self.sw(c, "sm_show_avatar", "Profilbild anzeigen", "Bild: ~/.face", {"startmenu"})
            self.sw(c, "sm_show_clock", "Uhr und Datum", None, {"startmenu"})
            self.sw(c, "sm_show_recent", "Zuletzt verwendet", "Unter den Favoriten", {"startmenu"})
            self.sw(c, "sm_show_desc", "Beschreibungen unter App-Namen", None, {"startmenu"})
            c = self.group(p, "Favoriten")
            self.button(c, "Angeheftete Apps bearbeiten", "Oder im Startmenü: Rechtsklick auf eine App",
                        "Öffnen", "xdg-open " + os.path.join(HYPR, "pinned-apps"))
            return p

        def page_island(self):
            p = self.page("Dynamic Island", "Die schwarze Pille oben in der Mitte: Uhr, Musik, Lautstärke, Aufnahme.")
            c = self.group(p, "Allgemein")
            self.sw(c, "island_enabled", "Dynamic Island anzeigen", "Aus = Uhr wieder in der Leiste", {"island", "bar"})
            self.sw(c, "island_all_monitors", "Auf allen Monitoren", "Aus = nur Hauptmonitor (siehe Leiste)", {"island"})
            c = self.group(p, "Verhalten")
            self.sw(c, "island_auto_expand", "Bei neuem Song kurz aufklappen", "Aus = nur beim Drüberfahren", {"island"})
            self.sw(c, "island_show_volume", "Lautstärke-Änderung anzeigen", None, {"island"})
            self.sw(c, "island_clock_seconds", "Uhr mit Sekunden", None, {"island"})
            return p

        def page_bar(self):
            p = self.page("Leiste", "Die Waybar oben.")
            c = self.group(p, "Monitore")
            self.sw(c, "bar_all_monitors", "Leiste auf allen Monitoren", None, {"bar"})
            mons = monitor_names() or [s["bar_main_monitor"]]
            if s["bar_main_monitor"] not in mons:
                mons.append(s["bar_main_monitor"])
            self.choice(c, "bar_main_monitor", "Hauptmonitor", "Für „nur Hauptmonitor“ (Leiste und Island)",
                        [(m, m) for m in mons], {"bar", "island"})
            c = self.group(p, "Elemente")
            self.sw(c, "bar_show_search", "Suchleiste neben dem Start-Knopf", None, {"bar"})
            self.sw(c, "bar_show_window", "Name des aktiven Fensters", None, {"bar"})
            self.sw(c, "bar_show_stats", "CPU und Arbeitsspeicher", None, {"bar"})
            self.sw(c, "bar_show_tray", "Symbole im Infobereich (Tray)", None, {"bar"})
            return p

        def page_input(self):
            p = self.page("Eingabe", "Tastatur und Maus.")
            c = self.group(p, "Tastatur")
            self.choice(c, "kb_layout", "Tastaturlayout", None,
                        [("de", "Deutsch"), ("at", "Österreich"), ("ch", "Schweiz"), ("us", "Englisch (US)"),
                         ("gb", "Englisch (UK)")], {"hypr"})
            self.sw(c, "numlock", "Num-Lock beim Start an", None, {"hypr"})
            c = self.group(p, "Maus")
            self.slider(c, "sensitivity", "Empfindlichkeit", "0 = unverändert", -1.0, 1.0, 0.05, {"hypr"})
            self.sw(c, "accel_flat", "Ohne Mausbeschleunigung", "Empfohlen für Spiele", {"hypr"})
            self.sw(c, "natural_scroll", "Natürliches Scrollen", "Wie am Handy", {"hypr"})
            self.sw(c, "follow_mouse", "Fokus folgt der Maus", "Aus = erst Klick fokussiert", {"hypr"})
            return p

        def page_lock(self):
            p = self.page("Sperrbildschirm", "Wie der Sperrbildschirm (SUPER+L) aussieht. Kein Name, kein Profilbild.")
            c = self.group(p, "Farbe & Uhr")
            self.choice(c, "lock_accent", "Akzentfarbe", "Schloss, Passwort-Rahmen, Tastatur-Symbol",
                        [("blue", "Blau"), ("purple", "Lila"), ("cyan", "Cyan"), ("pink", "Pink"),
                         ("green", "Gr\u00fcn"), ("orange", "Orange")], {"lock"})
            self.choice(c, "lock_clock_size", "Uhrgr\u00f6\u00dfe", None,
                        [("small", "Klein"), ("medium", "Mittel"), ("large", "Gro\u00df"), ("huge", "Riesig")], {"lock"})
            self.choice(c, "lock_clock_font", "Uhr-Schrift", None,
                        [("thin", "D\u00fcnn"), ("regular", "Normal"), ("bold", "Fett"), ("mono", "Monospace")], {"lock"})
            c = self.group(p, "Hintergrund")
            self.slider(c, "lock_dim", "Helligkeit", "Niedriger = dunkler", 0.15, 1.0, 0.05, {"lock"})
            self.spin(c, "lock_blur", "Unsch\u00e4rfe", "0 = scharfes Wallpaper", 0, 5, 1, {"lock"})
            c = self.group(p, "Elemente")
            self.sw(c, "lock_show_icon", "Schloss-Symbol", None, {"lock"})
            self.sw(c, "lock_show_date", "Datum", None, {"lock"})
            self.sw(c, "lock_show_greeting", "Begr\u00fc\u00dfung", "\u201eGuten Abend\u201c, ohne Namen", {"lock"})
            self.sw(c, "lock_show_music", "Laufende Musik", "Cover, Titel, K\u00fcnstler", {"lock"})
            self.sw(c, "lock_show_info", "Tastaturlayout und Laufzeit", "Unten links und rechts", {"lock"})
            self.sw(c, "lock_input_fade", "Passwortfeld ausblenden, wenn leer", None, {"lock"})
            self.sw(c, "lock_other_monitors", "Uhr auf den anderen Monitoren", None, {"lock"})
            c = self.group(p, "Test")
            self.button(c, "Jetzt sperren", "Zum Ansehen (SUPER+L)", "Sperren", "pidof hyprlock || hyprlock")
            return p

        def page_power(self):
            p = self.page("Sperren & Energie", "0 = nie.")
            c = self.group(p, "Automatisch")
            self.spin(c, "lock_minutes", "Sperren nach", "Minuten ohne Eingabe", 0, 240, 1, {"idle"})
            self.spin(c, "screen_off_minutes", "Bildschirm aus nach", "Minuten", 0, 240, 1, {"idle"})
            self.spin(c, "suspend_minutes", "Energiesparen nach", "Minuten", 0, 480, 5, {"idle"})
            c = self.group(p, "Jetzt")
            self.button(c, "Sperrbildschirm testen", "SUPER+L", "Sperren", "pidof hyprlock || hyprlock")
            return p

        def page_apps(self):
            p = self.page("Standard-Apps", "Werden von den Tastenkürzeln und dem Startmenü benutzt.")
            c = self.group(p, "Programme")
            self.text(c, "terminal", "Terminal", "SUPER+Return", {"hypr"})
            self.text(c, "fileManager", "Dateimanager", "SUPER+E", {"hypr"})
            self.text(c, "browser", "Browser", "SUPER+B", {"hypr"})
            return p

        def page_wall(self):
            p = self.page("Hintergrund", "Bilder liegen in ~/Pictures/Wallpapers.")
            c = self.group(p, "Wallpaper")
            self.button(c, "Wallpaper auswählen", "Mit Vorschau (SUPER+W)", "Auswählen", os.path.join(SCRIPTS, "wallpaper.sh") + " pick")
            self.button(c, "Zufälliges Wallpaper", "SUPER+SHIFT+W", "Wechseln", os.path.join(SCRIPTS, "wallpaper.sh") + " next")
            self.button(c, "Wallpaper-Ordner öffnen", None, "Öffnen", "xdg-open " + os.path.join(HOME, "Pictures", "Wallpapers"))
            return p

        def page_system(self):
            p = self.page("System", "Update, Reparatur und Backups.")
            ver = Gtk.Label(label="Version: " + repo_version(), xalign=0)
            ver.add_css_class("ver")
            p.append(ver)
            term = s.get("terminal") or "kitty"
            c = self.group(p, "Wartung")
            self.button(c, "Nach Updates suchen", "Holt den neuesten Stand von GitHub und installiert ihn",
                        "Aktualisieren", f"{term} -e bash -c 'bash -c \"$(curl -fsSL https://raw.githubusercontent.com/femboyss/claudes-glassy/main/get.sh)\"; read -p \"Enter zum Schließen\"'")
            self.button(c, "Doktor", "Prüft Configs, Dienste und Pakete", "Prüfen",
                        f"{term} -e bash -c 'bash {REPO}/doctor.sh; read -p \"Enter zum Schließen\"'")
            self.button(c, "Doktor: reparieren", "Holt kaputte Dateien aus dem Repo zurück", "Reparieren",
                        f"{term} -e bash -c 'bash {REPO}/doctor.sh --repair; read -p \"Enter zum Schließen\"'")
            self.button(c, "Backup wiederherstellen", "Zurück zum Setup vor der Installation", "Wiederherstellen",
                        f"{term} -e bash -c 'bash {REPO}/install.sh --restore; read -p \"Enter zum Schließen\"'", danger=True)
            c = self.group(p, "Sonstiges")
            self.button(c, "Einstellungen zurücksetzen", "Alle Werte auf Standard", "Zurücksetzen",
                        f"rm -f {STORE} && python3 {os.path.abspath(__file__)} --apply && pkill -f glassy_settings.py", danger=True)
            self.button(c, "Hyprland-Config-Ordner", None, "Öffnen", "xdg-open " + HYPR)
            self.button(c, "GitHub-Seite", None, "Öffnen", "xdg-open https://github.com/femboyss/claudes-glassy")
            return p

    class App(Gtk.Application):
        def __init__(self):
            super().__init__(application_id="glassy.settings", flags=Gio.ApplicationFlags.DEFAULT_FLAGS)
            self.win = None

        def do_startup(self):
            Gtk.Application.do_startup(self)
            prov = Gtk.CssProvider()
            if hasattr(prov, "load_from_string"):
                prov.load_from_string(CSS)
            else:
                prov.load_from_data(CSS.encode())
            Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov,
                                                      Gtk.STYLE_PROVIDER_PRIORITY_USER + 10)
            st = Gtk.Settings.get_default()
            if st is not None:
                st.set_property("gtk-application-prefer-dark-theme", True)

        def do_activate(self):
            if self.win is None:
                self.win = Win(self)
            self.win.present()

    return App().run([sys.argv[0]])


def monitor_names():
    try:
        out = subprocess.run(["hyprctl", "-j", "monitors"], capture_output=True, text=True, timeout=2).stdout
        return [m["name"] for m in json.loads(out)]
    except (OSError, ValueError, subprocess.SubprocessError, KeyError, TypeError):
        return []


def repo_version():
    try:
        out = subprocess.run(["git", "-C", REPO, "log", "-1", "--format=%h  %cd", "--date=format:%d.%m.%Y %H:%M"],
                             capture_output=True, text=True, timeout=2).stdout.strip()
        return out or "unbekannt"
    except (OSError, subprocess.SubprocessError):
        return "unbekannt"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apply", action="store_true", help="gespeicherte Einstellungen ohne Fenster anwenden")
    ap.add_argument("--quiet", action="store_true", help="mit --apply: nichts neu starten")
    a = ap.parse_args()
    if a.apply:
        apply_all(load(), quiet=a.quiet)
        print("Einstellungen angewendet:", STORE)
        return 0
    return run_gui()


if __name__ == "__main__":
    sys.exit(main())
