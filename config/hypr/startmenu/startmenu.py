#!/usr/bin/env python3
# ==================================================================
#  claudes-glassy  -  Startmenue v3 (Tokyo Night)
#  Aufbau nach Linux Mint (System-Knoepfe links, Kategorien, Apps) und
#  KDE Kickoff (Suche oben, Favoriten, Zuletzt, Orte unten).
#
#  Laeuft als Dienst (startet mit Hyprland), Super klappt auf/zu.
#  Debug:   python3 ~/.config/hypr/startmenu/startmenu.py --daemon --show
#  Log:     ~/.cache/claudes-glassy/startmenu.log
#
#  Einstellungen: Zahnrad oben rechts im Menue
#                 (gespeichert in ~/.config/hypr/startmenu/settings.json)
#  Favoriten:     Rechtsklick auf eine App, oder ~/.config/hypr/pinned-apps
#  Suche kann:    Apps finden, rechnen (z. B. 12*7+3), im Web suchen
# ==================================================================
import argparse
import ast
import json
import operator
import os
import subprocess
import sys
import time

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import Gdk, GdkPixbuf, Gio, GLib, Gtk, Pango  # noqa: E402

LS = None
try:
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk4LayerShell as LS  # noqa: E402
except (ValueError, ImportError):
    LS = None

HOME = os.path.expanduser("~")
HYPR = os.path.join(HOME, ".config", "hypr")
FAV_FILE = os.path.join(HYPR, "pinned-apps")
AVATAR = os.path.join(HYPR, "avatar.png")
SETTINGS_FILE = os.path.join(HYPR, "startmenu", "settings.json")
CACHE = os.path.join(HOME, ".cache", "claudes-glassy")
RECENT_FILE = os.path.join(CACHE, "recent.json")
SCRIPTS = os.path.join(HYPR, "scripts")
APP_ID = "glassy.startmenu"
FIFO = os.path.join(CACHE, "startmenu.fifo")

PANEL_W, PANEL_H = 500, 400
MARGIN_TOP, MARGIN_LEFT = 54, 14

DEFAULT_SETTINGS = {
    "show_avatar": False,       # Profilbild oben links
    "show_clock": True,         # Uhr + Datum oben rechts
    "show_recent": True,        # "Zuletzt verwendet" unter den Favoriten
    "show_desc": True,          # Beschreibung unter App-Namen
    "hover_categories": True,   # Kategorie wechselt beim Drueberfahren (wie Mint)
}

# Nerd-Font-Glyphen (JetBrainsMono Nerd Font)
G = {
    "fav": "", "all": "", "recent": "", "search": "",
    "Internet": "", "Multimedia": "", "Spiele": "",
    "Entwicklung": "", "Grafik": "", "Buero": "",
    "Bildung": "", "Wissenschaft": "", "System": "",
    "Einstellungen": "", "Zubehoer": "", "Sonstiges": "",
    "lock": "", "logout": "", "suspend": "", "reboot": "",
    "power": "", "files": "", "term": "", "settings": "",
    "home": "", "down": "", "docs": "", "pics": "",
    "music": "", "calc": "", "web": "", "gear": "",
    "sliders": "",
}

CAT_MAP = [
    ("Internet", ("Network", "WebBrowser", "Email", "Chat", "InstantMessaging")),
    ("Multimedia", ("AudioVideo", "Audio", "Video", "Music", "Player")),
    ("Spiele", ("Game",)),
    ("Grafik", ("Graphics",)),
    ("Buero", ("Office",)),
    ("Entwicklung", ("Development", "IDE")),
    ("Bildung", ("Education",)),
    ("Wissenschaft", ("Science",)),
    ("Zubehoer", ("Utility", "Accessories", "TextEditor")),
    ("Einstellungen", ("Settings", "DesktopSettings", "HardwareSettings")),
    ("System", ("System", "Monitor", "TerminalEmulator", "FileManager")),
]
CAT_LABEL = {"Buero": "Büro", "Zubehoer": "Zubehör"}
WEEKDAYS = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
MONTHS = ["Jan", "Feb", "Mär", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"]

CSS = r"""
/* ---------- Tokyo Night ---------- */
@define-color tn_bg        #1a1b26;
@define-color tn_bg_dark   #16161e;
@define-color tn_bg_hl     #292e42;
@define-color tn_fg        #c0caf5;
@define-color tn_fg_dark   #a9b1d6;
@define-color tn_comment   #565f89;
@define-color tn_blue      #7aa2f7;
@define-color tn_cyan      #7dcfff;
@define-color tn_purple    #bb9af7;
@define-color tn_green     #9ece6a;
@define-color tn_orange    #ff9e64;
@define-color tn_yellow    #e0af68;
@define-color tn_red       #f7768e;
@define-color tn_teal      #1abc9c;

window, window.background { background: transparent; }
* { font-family: "Inter", "JetBrainsMono Nerd Font", sans-serif; }

.panel {
    background-color: alpha(@tn_bg, 0.82);
    background-image: linear-gradient(90deg, alpha(@tn_purple, 0.0), alpha(@tn_blue, 0.85), alpha(@tn_cyan, 0.85), alpha(@tn_purple, 0.0));
    background-size: 100% 2px;
    background-repeat: no-repeat;
    background-position: top;
    border: 1px solid alpha(@tn_blue, 0.20);
    border-radius: 16px;
    box-shadow: 0 10px 28px alpha(black, 0.42);
    color: @tn_fg;
}

/* Kopf */
.header { padding: 10px 10px 6px 12px; }
.avatar { border-radius: 999px; border: 2px solid alpha(@tn_purple, 0.8); }
.clock  { font-size: 13px; font-weight: 800; color: @tn_fg; }
.date   { font-size: 9.5px; font-weight: 600; color: @tn_comment; }

entry.search {
    min-height: 30px;
    padding: 0 10px;
    border-radius: 10px;
    font-size: 12px;
    background-color: alpha(@tn_bg_dark, 0.85);
    border: 1px solid alpha(@tn_blue, 0.22);
    color: @tn_fg;
    caret-color: @tn_cyan;
    box-shadow: none;
    outline: none;
    transition: all 150ms ease;
}
entry.search:focus-within {
    border-color: alpha(@tn_cyan, 0.75);
    box-shadow: 0 0 0 3px alpha(@tn_cyan, 0.10);
}
entry.search image { color: @tn_blue; }

button.flat-icon {
    min-width: 28px; min-height: 28px; padding: 0;
    border-radius: 8px; border: none; box-shadow: none;
    background: transparent;
    color: @tn_comment;
    font-family: "JetBrainsMono Nerd Font"; font-size: 13px;
    transition: all 150ms ease;
}
button.flat-icon:hover { background-color: alpha(@tn_bg_hl, 0.9); color: @tn_cyan; }

/* Seitenleiste (Mint) */
.sidebar {
    padding: 5px 3px;
    margin: 0 0 0 8px;
    border-radius: 10px;
    background-color: alpha(@tn_bg_dark, 0.55);
}
.sidebtn {
    min-width: 26px; min-height: 26px; padding: 0;
    border-radius: 7px; border: none; box-shadow: none;
    background: transparent;
    color: @tn_fg_dark;
    font-family: "JetBrainsMono Nerd Font"; font-size: 12px;
    transition: all 150ms ease;
}
.sidebtn:hover          { background-color: alpha(@tn_bg_hl, 0.9); color: @tn_cyan; }
.sidebtn.lock:hover     { color: @tn_purple; }
.sidebtn.logout:hover   { color: @tn_yellow; }
.sidebtn.suspend:hover  { color: @tn_blue; }
.sidebtn.reboot:hover   { color: @tn_orange; }
.sidebtn.power:hover    { color: @tn_red; background-color: alpha(@tn_red, 0.14); }
.sidebtn.confirm        { color: @tn_bg; background-color: @tn_red; }
.sidebtn.confirm.reboot { background-color: @tn_orange; }
.sidebtn.confirm.logout { background-color: @tn_yellow; }

/* Kategorien */
.cats { background: transparent; margin: 0 2px 0 6px; }
.cats row {
    min-height: 24px; padding: 0 8px; margin: 1px 0;
    border-radius: 7px;
    color: @tn_fg_dark;
    background: transparent;
    transition: all 120ms ease;
}
.cats row:hover    { background-color: alpha(@tn_bg_hl, 0.65); color: @tn_fg; }
.cats row:selected {
    background-color: alpha(@tn_blue, 0.15);
    color: @tn_blue;
    box-shadow: inset 2px 0 0 @tn_blue;
}
.cats .catglyph { font-family: "JetBrainsMono Nerd Font"; min-width: 14px; font-size: 10px; }
.cats .catname  { font-size: 11.5px; font-weight: 600; }
.cats row.seprow, .cats row.seprow:hover { min-height: 0; padding: 0; margin: 3px 0; background: none; box-shadow: none; }
.sep { background-color: alpha(@tn_comment, 0.25); min-height: 1px; margin: 3px 8px; }

/* Inhalt */
.content { margin: 0 8px 0 2px; }
.section { font-size: 9px; font-weight: 800; color: @tn_comment; letter-spacing: 1px; margin: 2px 4px 4px 4px; }

.apps { background: transparent; }
.apps row {
    padding: 3px 6px; margin: 1px 0;
    border-radius: 7px;
    background: transparent;
    transition: all 120ms ease;
}
.apps row:hover, .apps row:selected { background-color: alpha(@tn_bg_hl, 0.85); }
.apps row:selected .appname { color: @tn_cyan; }
.appname { font-size: 11.5px; font-weight: 600; color: @tn_fg; }
.appdesc { font-size: 9.5px; color: @tn_comment; }
.apps row.special .appname { color: @tn_green; }
.apps row.special .rowglyph { color: @tn_green; font-family: "JetBrainsMono Nerd Font"; font-size: 13px; min-width: 20px; }
.apps row.web .appname, .apps row.web .rowglyph { color: @tn_blue; }

flowbox.favs { background: transparent; }
flowbox.favs flowboxchild {
    padding: 7px 2px 5px 2px; margin: 2px;
    border-radius: 9px;
    background-color: alpha(@tn_bg_hl, 0.28);
    border: 1px solid transparent;
    transition: all 140ms ease;
}
flowbox.favs flowboxchild:hover,
flowbox.favs flowboxchild:selected {
    background-color: alpha(@tn_bg_hl, 0.95);
    border-color: alpha(@tn_purple, 0.50);
    box-shadow: 0 0 12px alpha(@tn_purple, 0.18);
}
.favname { font-size: 9.5px; font-weight: 600; color: @tn_fg_dark; }

.empty { color: @tn_comment; font-size: 11px; margin: 30px; }

/* Fuss */
.footer { padding: 4px 10px 7px 10px; }
.place {
    min-width: 24px; min-height: 22px; padding: 0 5px;
    border-radius: 6px; border: none; box-shadow: none;
    background: transparent;
    color: @tn_teal;
    font-family: "JetBrainsMono Nerd Font"; font-size: 11px;
    transition: all 120ms ease;
}
.place:hover { background-color: alpha(@tn_bg_hl, 0.8); color: @tn_green; }
.hint { font-size: 9.5px; color: @tn_comment; }
.hint.warn { color: @tn_red; font-weight: 700; }

scrollbar { background: transparent; }
scrollbar slider { background-color: alpha(@tn_comment, 0.45); border-radius: 99px; min-width: 3px; }

popover.ctx > contents {
    background-color: @tn_bg_dark;
    border: 1px solid alpha(@tn_blue, 0.3);
    border-radius: 10px;
    padding: 4px;
}
popover.ctx button {
    background: transparent; border: none; box-shadow: none;
    color: @tn_fg; border-radius: 7px; padding: 5px 10px; font-size: 11.5px;
}
popover.ctx button:hover { background-color: @tn_bg_hl; color: @tn_cyan; }
popover.ctx .settitle { font-size: 10px; font-weight: 800; color: @tn_comment; letter-spacing: 1px; margin: 4px 6px 6px 6px; }
popover.ctx .setrow { padding: 3px 6px; }
popover.ctx .setrow label { font-size: 11.5px; color: @tn_fg; }
popover.ctx switch { min-height: 16px; min-width: 30px; background-color: @tn_bg_hl; border: none; }
popover.ctx switch:checked { background-color: @tn_blue; }
popover.ctx switch slider { min-width: 14px; min-height: 14px; background-color: @tn_fg; border: none; box-shadow: none; }
"""


# ------------------------------------------------------------------ Daten
def load_settings():
    s = dict(DEFAULT_SETTINGS)
    try:
        with open(SETTINGS_FILE, encoding="utf-8") as f:
            s.update({k: v for k, v in json.load(f).items() if k in DEFAULT_SETTINGS})
    except (FileNotFoundError, ValueError, AttributeError):
        pass
    return s


def save_settings(s):
    os.makedirs(os.path.dirname(SETTINGS_FILE), exist_ok=True)
    with open(SETTINGS_FILE, "w", encoding="utf-8") as f:
        json.dump(s, f, indent=2)


_OPS = {ast.Add: operator.add, ast.Sub: operator.sub, ast.Mult: operator.mul,
        ast.Div: operator.truediv, ast.Pow: operator.pow, ast.Mod: operator.mod,
        ast.FloorDiv: operator.floordiv, ast.USub: operator.neg, ast.UAdd: operator.pos}


def calc(expr):
    """Sicherer Taschenrechner fuer die Suche. Gibt Text oder None zurueck."""
    e = expr.replace(",", ".").replace("x", "*").replace("^", "**").replace(":", "/").strip()
    if not e or not any(ch.isdigit() for ch in e) or not any(op in e for op in "+-*/%"):
        return None
    if any(ch.isalpha() for ch in e):
        return None

    def ev(n):
        if isinstance(n, ast.Expression):
            return ev(n.body)
        if isinstance(n, ast.Constant) and isinstance(n.value, (int, float)):
            return n.value
        if isinstance(n, ast.BinOp) and type(n.op) in _OPS:
            a, b = ev(n.left), ev(n.right)
            if isinstance(n.op, ast.Pow) and abs(b) > 100:
                raise ValueError
            return _OPS[type(n.op)](a, b)
        if isinstance(n, ast.UnaryOp) and type(n.op) in _OPS:
            return _OPS[type(n.op)](ev(n.operand))
        raise ValueError
    try:
        v = ev(ast.parse(e, mode="eval"))
    except (ValueError, SyntaxError, ZeroDivisionError, OverflowError, TypeError):
        return None
    if isinstance(v, float):
        v = round(v, 10)
        if v == int(v) and abs(v) < 1e15:
            v = int(v)
    return str(v).replace(".", ",")


def clean_env():
    env = dict(os.environ)
    env.pop("LD_PRELOAD", None)
    return env


def run(cmd):
    subprocess.Popen(cmd, shell=True, start_new_session=True, env=clean_env(),
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def app_key(info):
    i = info.get_id() or ""
    return i[:-8] if i.endswith(".desktop") else i


def load_apps():
    apps, seen = [], set()
    for info in Gio.AppInfo.get_all():
        if not isinstance(info, Gio.DesktopAppInfo) or not info.should_show():
            continue
        key = app_key(info)
        if not key or key in seen:
            continue
        seen.add(key)
        cats = (info.get_categories() or "").split(";")
        cat = "Sonstiges"
        for label, keys in CAT_MAP:
            if any(c in keys for c in cats):
                cat = label
                break
        name = info.get_display_name() or info.get_name() or key
        desc = info.get_description() or info.get_generic_name() or ""
        kw = " ".join(info.get_keywords() or [])
        apps.append({
            "key": key, "info": info, "name": name, "desc": desc, "cat": cat,
            "icon": info.get_icon(),
            "blob": " ".join([name, desc, info.get_generic_name() or "", kw, key,
                              info.get_executable() or ""]).lower(),
        })
    apps.sort(key=lambda a: a["name"].lower())
    return apps


def read_favs():
    """Liste von Zeilen; jede Zeile = Alternativen (erste installierte gewinnt)."""
    lines = []
    try:
        with open(FAV_FILE, encoding="utf-8") as f:
            for raw in f:
                line = raw.split("#", 1)[0].strip().replace(" ", "")
                if line:
                    lines.append([x for x in line.split("|") if x])
    except FileNotFoundError:
        pass
    return lines


def write_fav_add(key):
    os.makedirs(os.path.dirname(FAV_FILE), exist_ok=True)
    with open(FAV_FILE, "a", encoding="utf-8") as f:
        f.write(key + "\n")


def write_fav_remove(key):
    try:
        with open(FAV_FILE, encoding="utf-8") as f:
            raw = f.readlines()
    except FileNotFoundError:
        return
    out = []
    for line in raw:
        body = line.split("#", 1)[0].strip().replace(" ", "")
        if body and key in body.split("|"):
            continue
        out.append(line)
    with open(FAV_FILE, "w", encoding="utf-8") as f:
        f.writelines(out)


def read_recent():
    try:
        with open(RECENT_FILE, encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, ValueError):
        return {}


def bump_recent(key):
    data = read_recent()
    cnt, _ = data.get(key, [0, 0])
    data[key] = [cnt + 1, time.time()]
    os.makedirs(CACHE, exist_ok=True)
    with open(RECENT_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f)


def xdg_dir(name, fallback):
    try:
        out = subprocess.run(["xdg-user-dir", name], capture_output=True, text=True, timeout=1)
        p = out.stdout.strip()
        if p and p != HOME:
            return p
    except (OSError, subprocess.SubprocessError):
        pass
    return os.path.join(HOME, fallback)


def greeting():
    h = time.localtime().tm_hour
    if h < 5:
        return "Gute Nacht"
    if h < 11:
        return "Guten Morgen"
    if h < 18:
        return "Hallo"
    return "Guten Abend"


def uptime_text():
    try:
        with open("/proc/uptime") as f:
            s = int(float(f.read().split()[0]))
    except OSError:
        return ""
    d, s = divmod(s, 86400)
    h, s = divmod(s, 3600)
    m = s // 60
    parts = []
    if d:
        parts.append(f"{d} T")
    if h:
        parts.append(f"{h} Std")
    parts.append(f"{m} Min")
    return "an seit " + " ".join(parts)


def glyph(text, extra=None):
    lbl = Gtk.Label(label=text)
    lbl.add_css_class("glyph")
    if extra:
        lbl.add_css_class(extra)
    return lbl



def clock_texts():
    t = time.localtime()
    return time.strftime("%H:%M", t), f"{WEEKDAYS[t.tm_wday]}, {t.tm_mday}. {MONTHS[t.tm_mon - 1]}"


def app_image(app, size):
    img = Gtk.Image.new_from_gicon(app["icon"]) if app["icon"] else Gtk.Image.new_from_icon_name("application-x-executable")
    img.set_pixel_size(size)
    return img


# ------------------------------------------------------------------ Hyprland-Ereignisse
class HyprEvents:
    """Liest Hyprlands Ereignis-Socket (.socket2.sock) und ruft cb(name, data) auf.
    Damit merken wir Klicks auf andere Monitore/Fenster, auch wenn wir die
    Tastatur exklusiv halten."""

    def __init__(self, cb):
        self.cb = cb
        self.conn = None
        GLib.idle_add(self._connect)

    def _path(self):
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        rt = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        if not sig:
            return None
        for p in (os.path.join(rt, "hypr", sig, ".socket2.sock"), os.path.join("/tmp", "hypr", sig, ".socket2.sock")):
            if os.path.exists(p):
                return p
        return None

    def _connect(self):
        path = self._path()
        if path is None:
            return False
        try:
            client = Gio.SocketClient.new()
            self.conn = client.connect(Gio.UnixSocketAddress.new(path), None)
        except GLib.Error as e:
            print("[hypr-events] verbinden:", e, file=sys.stderr, flush=True)
            GLib.timeout_add_seconds(5, self._connect)
            return False
        self.stream = Gio.DataInputStream.new(self.conn.get_input_stream())
        self._read()
        return False

    def _read(self):
        def done(s, res):
            try:
                line, _ = s.read_line_finish_utf8(res)
            except GLib.Error:
                line = None
            if line is None:
                GLib.timeout_add_seconds(2, self._connect)     # Hyprland neu geladen o. ae.
                return
            name, _, data = line.partition(">>")
            try:
                self.cb(name, data)
            except Exception as e:  # noqa: BLE001
                print("[hypr-events]", e, file=sys.stderr, flush=True)
            self._read()
        self.stream.read_line_async(GLib.PRIORITY_DEFAULT, None, done)


# ------------------------------------------------------------------ UI
class StartMenu(Gtk.ApplicationWindow):
    def __init__(self, app, monitor_name=None, screenshot=None, daemon=False):
        super().__init__(application=app, title="Startmenue")
        self.app = app
        self.daemon = daemon
        self.screenshot = screenshot
        self.settings = load_settings()
        self.apps = load_apps()
        self.by_key = {a["key"]: a for a in self.apps}
        self.apps_dirty = False
        self.confirm_pending = None
        self.layer = False
        self.opened_at = 0.0

        self.set_decorated(False)
        self.set_resizable(False)

        if LS is not None and LS.is_supported() and not screenshot:
            self.layer = True
            LS.init_for_window(self)
            LS.set_namespace(self, "glassy-startmenu")
            LS.set_layer(self, LS.Layer.OVERLAY)
            LS.set_keyboard_mode(self, LS.KeyboardMode.EXCLUSIVE)
            for edge in (LS.Edge.TOP, LS.Edge.BOTTOM, LS.Edge.LEFT, LS.Edge.RIGHT):
                LS.set_anchor(self, edge, True)
            LS.set_exclusive_zone(self, -1)
            mon = self._find_monitor(monitor_name)
            if mon is not None:
                LS.set_monitor(self, mon)
        else:
            self.set_default_size(PANEL_W, PANEL_H)
        print(f"[startmenu] layer-shell: {'an' if self.layer else 'AUS (normales Fenster)'}"
              f"  (typelib: {'ja' if LS is not None else 'nein'})", file=sys.stderr, flush=True)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(root)
        self.panel = self._build_panel()
        self.revealer = Gtk.Revealer()
        self.revealer.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        self.revealer.set_transition_duration(170)
        self.revealer.set_child(self.panel)
        if self.layer:
            self.revealer.set_halign(Gtk.Align.START)
            self.revealer.set_valign(Gtk.Align.START)
            self.revealer.set_margin_top(MARGIN_TOP)
            self.revealer.set_margin_start(MARGIN_LEFT)
            click = Gtk.GestureClick()
            click.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
            click.connect("pressed", self._on_root_click)
            self.add_controller(click)
        root.append(self.revealer)

        keys = Gtk.EventControllerKey()
        keys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        keys.connect("key-pressed", self._on_key)
        self.add_controller(keys)

        self.connect("notify::is-active", self._on_active_changed)
        # Klick auf anderen Monitor / anderes Fenster / Workspace-Wechsel -> zu
        if daemon:
            self.hypr = HyprEvents(self._on_hypr_event)
        self.appmon = Gio.AppInfoMonitor.get()
        self.appmon.connect("changed", lambda *_: setattr(self, "apps_dirty", True))

        self._apply_settings()
        self.reset_view()
        if screenshot:
            self.revealer.set_reveal_child(True)

    # ---------- Oeffnen / Schliessen ----------
    def _tick_clock(self):
        hm, d = clock_texts()
        self.clock_lbl.set_label(hm)
        self.date_lbl.set_label(d)
        return self.get_visible()

    def reset_view(self):
        self.confirm_pending = None
        for b in self.power_btns.values():
            b.remove_css_class("confirm")
        self._set_hint()
        self.search.set_text("")
        self._tick_clock()
        self.cat_list.select_row(self.cat_list.get_row_at_index(0))
        self._show_category("fav")
        GLib.idle_add(self.search.grab_focus)

    def open_on(self, monitor_name=None):
        if self.apps_dirty:
            self.apps = load_apps()
            self.by_key = {a["key"]: a for a in self.apps}
            self.apps_dirty = False
        if self.layer:
            mon = self._find_monitor(monitor_name)
            if mon is not None:
                LS.set_monitor(self, mon)
        self.reset_view()
        self.opened_at = time.monotonic()
        self.was_active = False
        self.revealer.set_reveal_child(False)
        self.present()
        GLib.idle_add(lambda: (self.revealer.set_reveal_child(True), False)[1])
        GLib.timeout_add_seconds(10, self._tick_clock)

    def toggle(self, monitor_name=None):
        if os.environ.get("GLASSY_DEBUG"):
            print(f"[startmenu] toggle: visible={self.get_visible()} reveal={self.revealer.get_reveal_child()}", file=sys.stderr, flush=True)
        if self.get_visible():
            self.close_menu()
        else:
            self.open_on(monitor_name)

    def close_menu(self):
        if self.screenshot:
            return
        if not self.daemon:
            self.app.quit()
            return
        if not self.get_visible():
            return
        self.revealer.set_reveal_child(False)
        GLib.timeout_add(180, lambda: (self.set_visible(False) if not self.revealer.get_reveal_child() else None, False)[1])

    # ---------- Aufbau ----------
    def _find_monitor(self, name):
        if not name:
            return None
        mons = Gdk.Display.get_default().get_monitors()
        for i in range(mons.get_n_items()):
            m = mons.get_item(i)
            if m.get_connector() == name:
                return m
        return None

    def _build_panel(self):
        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        panel.add_css_class("panel")
        panel.set_size_request(PANEL_W, PANEL_H)
        panel.set_overflow(Gtk.Overflow.HIDDEN)
        panel.append(self._build_header())
        body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        body.set_vexpand(True)
        body.append(self._build_sidebar())
        body.append(self._build_categories())
        body.append(self._build_content())
        panel.append(body)
        panel.append(self._build_footer())
        return panel

    def _build_header(self):
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        box.add_css_class("header")

        # Profilbild (per Einstellung ein-/ausblendbar, Standard: aus)
        self.avatar_box = Gtk.Box()
        self.avatar_box.add_css_class("avatar")
        self.avatar_box.set_overflow(Gtk.Overflow.HIDDEN)
        self.avatar_box.set_valign(Gtk.Align.CENTER)
        pic = None
        if os.path.exists(AVATAR):
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(AVATAR, 56, 56, False)
                pic = Gtk.Image.new_from_paintable(Gdk.Texture.new_for_pixbuf(pb))
            except GLib.Error:
                pic = None
        if pic is None:
            pic = Gtk.Image.new_from_icon_name("avatar-default")
        pic.set_pixel_size(26)
        pic.set_size_request(26, 26)
        self.avatar_box.set_size_request(26, 26)
        self.avatar_box.append(pic)
        box.append(self.avatar_box)

        self.search = Gtk.SearchEntry()
        self.search.add_css_class("search")
        self.search.set_placeholder_text("Apps, Rechnen, Web ...")
        self.search.set_hexpand(True)
        self.search.set_valign(Gtk.Align.CENTER)
        self.search.connect("search-changed", self._on_search)
        self.search.connect("activate", self._on_search_activate)
        box.append(self.search)

        self.clock_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.clock_box.set_valign(Gtk.Align.CENTER)
        self.clock_lbl = Gtk.Label(xalign=1)
        self.clock_lbl.add_css_class("clock")
        self.date_lbl = Gtk.Label(xalign=1)
        self.date_lbl.add_css_class("date")
        self.clock_box.append(self.clock_lbl)
        self.clock_box.append(self.date_lbl)
        box.append(self.clock_box)

        gear = Gtk.Button(label=G["sliders"])
        gear.add_css_class("flat-icon")
        gear.set_tooltip_text("Menue-Einstellungen")
        gear.set_focusable(False)
        gear.set_valign(Gtk.Align.CENTER)
        gear.connect("clicked", self._show_settings)
        box.append(gear)
        return box

    def _sidebtn(self, key, tip, cb, extra=None):
        b = Gtk.Button(label=G[key])
        b.add_css_class("sidebtn")
        if extra:
            b.add_css_class(extra)
        b.set_tooltip_text(tip)
        b.connect("clicked", cb)
        b.set_focusable(False)
        return b

    def _build_sidebar(self):
        bar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        bar.add_css_class("sidebar")
        bar.append(self._sidebtn("files", "Dateien", lambda *_: self._run("xdg-open " + GLib.shell_quote(HOME))))
        bar.append(self._sidebtn("term", "Terminal", lambda *_: self._run("kitty")))
        bar.append(self._sidebtn("settings", "Systemeinstellungen", lambda *_: self._run(os.path.join(SCRIPTS, "settings.sh"))))
        spacer = Gtk.Box()
        spacer.set_vexpand(True)
        bar.append(spacer)
        self.power_btns = {}
        for key, tip in (("lock", "Sperren"), ("logout", "Abmelden"), ("suspend", "Energiesparen"),
                         ("reboot", "Neustart"), ("power", "Herunterfahren")):
            btn = self._sidebtn(key, tip, self._on_power, key)
            btn._action = key
            self.power_btns[key] = btn
            bar.append(btn)
        return bar

    def _cat_row(self, key, label, glyph_key):
        row = Gtk.ListBoxRow()
        row._cat = key
        box = Gtk.Box(spacing=7)
        g = Gtk.Label(label=G.get(glyph_key, G["Sonstiges"]))
        g.add_css_class("catglyph")
        n = Gtk.Label(label=label, xalign=0)
        n.add_css_class("catname")
        box.append(g)
        box.append(n)
        row.set_child(box)
        hover = Gtk.EventControllerMotion()
        hover.connect("enter", lambda *_: self._hover_cat(row))
        row.add_controller(hover)
        return row

    def _build_categories(self):
        self.cat_list = Gtk.ListBox()
        self.cat_list.add_css_class("cats")
        self.cat_list.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.cat_list.append(self._cat_row("fav", "Favoriten", "fav"))
        self.cat_list.append(self._cat_row("all", "Alle Apps", "all"))
        self.cat_list.append(self._cat_row("recent", "Zuletzt", "recent"))
        sep = Gtk.ListBoxRow()
        sep.add_css_class("seprow")
        sep.set_selectable(False)
        sep.set_activatable(False)
        line = Gtk.Box()
        line.add_css_class("sep")
        sep.set_child(line)
        self.cat_list.append(sep)
        used = {a["cat"] for a in self.apps}
        for label, _ in CAT_MAP + [("Sonstiges", ())]:
            if label in used:
                self.cat_list.append(self._cat_row(label, CAT_LABEL.get(label, label), label))
        self.cat_list.connect("row-selected", self._on_cat_selected)
        sw = Gtk.ScrolledWindow()
        sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        sw.set_child(self.cat_list)
        sw.set_size_request(122, -1)
        return sw

    def _build_content(self):
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(110)
        self.stack.set_hexpand(True)
        self.stack.add_css_class("content")

        fav_page = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        t1 = Gtk.Label(label="FAVORITEN", xalign=0)
        t1.add_css_class("section")
        fav_page.append(t1)
        self.favbox = Gtk.FlowBox()
        self.favbox.add_css_class("favs")
        self.favbox.set_max_children_per_line(4)
        self.favbox.set_min_children_per_line(4)
        self.favbox.set_homogeneous(True)
        self.favbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.favbox.set_activate_on_single_click(True)
        self.favbox.connect("child-activated", lambda fb, ch: self._launch(ch._app))
        fav_page.append(self.favbox)
        self.recent_title = Gtk.Label(label="ZULETZT VERWENDET", xalign=0)
        self.recent_title.add_css_class("section")
        self.recent_title.set_margin_top(6)
        fav_page.append(self.recent_title)
        self.recent_list = self._new_app_list()
        fav_page.append(self.recent_list)
        fsw = Gtk.ScrolledWindow()
        fsw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        fsw.set_child(fav_page)
        self.stack.add_named(fsw, "fav")

        lpage = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.list_title = Gtk.Label(label="", xalign=0)
        self.list_title.add_css_class("section")
        lpage.append(self.list_title)
        self.app_list = self._new_app_list()
        lsw = Gtk.ScrolledWindow()
        lsw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        lsw.set_vexpand(True)
        lsw.set_child(self.app_list)
        self.list_scroll = lsw
        lpage.append(lsw)
        self.empty = Gtk.Label(label="Nichts gefunden")
        self.empty.add_css_class("empty")
        self.empty.set_visible(False)
        lpage.append(self.empty)
        self.stack.add_named(lpage, "list")
        return self.stack

    def _new_app_list(self):
        lb = Gtk.ListBox()
        lb.add_css_class("apps")
        lb.set_selection_mode(Gtk.SelectionMode.SINGLE)
        lb.set_activate_on_single_click(True)
        lb.connect("row-activated", lambda l, r: self._activate_row(r))
        return lb

    def _build_footer(self):
        box = Gtk.Box(spacing=2)
        box.add_css_class("footer")
        for key, name, xdg, fb in (("home", "Persönlicher Ordner", None, ""),
                                   ("down", "Downloads", "DOWNLOAD", "Downloads"),
                                   ("docs", "Dokumente", "DOCUMENTS", "Documents"),
                                   ("pics", "Bilder", "PICTURES", "Pictures"),
                                   ("music", "Musik", "MUSIC", "Music")):
            path = HOME if xdg is None else xdg_dir(xdg, fb)
            b = Gtk.Button(label=G[key])
            b.add_css_class("place")
            b.set_focusable(False)
            b.set_tooltip_text(f"{name}  -  {path}")
            b.connect("clicked", lambda _b, p=path: self._run("xdg-open " + GLib.shell_quote(p)))
            box.append(b)
        sp = Gtk.Box()
        sp.set_hexpand(True)
        box.append(sp)
        self.hint = Gtk.Label()
        self.hint.add_css_class("hint")
        box.append(self.hint)
        return box

    # ---------- Einstellungen ----------
    def _apply_settings(self):
        s = self.settings
        self.avatar_box.set_visible(bool(s["show_avatar"]))
        self.clock_box.set_visible(bool(s["show_clock"]))
        self.recent_title.set_visible(bool(s["show_recent"]))
        self.recent_list.set_visible(bool(s["show_recent"]))

    def _show_settings(self, btn):
        pop = Gtk.Popover()
        pop.add_css_class("ctx")
        pop.set_has_arrow(False)
        pop.set_position(Gtk.PositionType.BOTTOM)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        title = Gtk.Label(label="MENÜ-EINSTELLUNGEN", xalign=0)
        title.add_css_class("settitle")
        box.append(title)
        for key, label in (("show_avatar", "Profilbild anzeigen"),
                           ("show_clock", "Uhr anzeigen"),
                           ("show_recent", "Zuletzt verwendet"),
                           ("show_desc", "Beschreibungen"),
                           ("hover_categories", "Kategorie beim Drüberfahren")):
            row = Gtk.Box(spacing=14)
            row.add_css_class("setrow")
            lbl = Gtk.Label(label=label, xalign=0)
            lbl.set_hexpand(True)
            sw = Gtk.Switch()
            sw.set_active(bool(self.settings[key]))
            sw.set_valign(Gtk.Align.CENTER)
            sw.connect("notify::active", self._on_setting, key)
            row.append(lbl)
            row.append(sw)
            box.append(row)
        pop.set_child(box)
        pop.set_parent(btn)
        pop.connect("closed", lambda p: GLib.idle_add(p.unparent))
        pop.popup()

    def _on_setting(self, sw, _pspec, key):
        self.settings[key] = sw.get_active()
        save_settings(self.settings)
        self._apply_settings()
        if key == "show_desc":
            row = self.cat_list.get_selected_row()
            if self.search.get_text():
                self._on_search(self.search)
            else:
                self._show_category(row._cat if row is not None and hasattr(row, "_cat") else "fav")

    # ---------- Zeilen / Kacheln ----------
    def _app_row(self, app):
        row = Gtk.ListBoxRow()
        row._app = app
        box = Gtk.Box(spacing=8)
        box.append(app_image(app, 20))
        tb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        tb.set_valign(Gtk.Align.CENTER)
        n = Gtk.Label(label=app["name"], xalign=0)
        n.add_css_class("appname")
        n.set_ellipsize(Pango.EllipsizeMode.END)
        tb.append(n)
        if app["desc"] and self.settings["show_desc"]:
            d = Gtk.Label(label=app["desc"], xalign=0)
            d.add_css_class("appdesc")
            d.set_ellipsize(Pango.EllipsizeMode.END)
            d.set_max_width_chars(30)
            tb.append(d)
        box.append(tb)
        row.set_child(box)
        self._attach_context(row, app)
        return row

    def _special_row(self, glyph_key, title, sub, action, extra):
        row = Gtk.ListBoxRow()
        row._action = action
        row.add_css_class("special")
        if extra:
            row.add_css_class(extra)
        box = Gtk.Box(spacing=8)
        g = Gtk.Label(label=G[glyph_key])
        g.add_css_class("rowglyph")
        box.append(g)
        tb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        n = Gtk.Label(label=title, xalign=0)
        n.add_css_class("appname")
        n.set_ellipsize(Pango.EllipsizeMode.END)
        tb.append(n)
        d = Gtk.Label(label=sub, xalign=0)
        d.add_css_class("appdesc")
        tb.append(d)
        box.append(tb)
        row.set_child(box)
        return row

    def _fav_tile(self, app):
        ch = Gtk.FlowBoxChild()
        ch._app = app
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        box.append(app_image(app, 26))
        n = Gtk.Label(label=app["name"])
        n.add_css_class("favname")
        n.set_ellipsize(Pango.EllipsizeMode.END)
        n.set_max_width_chars(9)
        box.append(n)
        ch.set_child(box)
        ch.set_tooltip_text(app["desc"] or app["name"])
        self._attach_context(ch, app)
        return ch

    def _attach_context(self, widget, app):
        click = Gtk.GestureClick(button=3)
        click.connect("pressed", lambda g, n, x, y: self._show_context(widget, app, x, y))
        widget.add_controller(click)

    def _show_context(self, widget, app, x, y):
        pop = Gtk.Popover()
        pop.add_css_class("ctx")
        pop.set_has_arrow(False)
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        is_fav = app["key"] in self._fav_keys()

        def btn(label, cb):
            b = Gtk.Button(label=label)
            b.connect("clicked", lambda *_: (pop.popdown(), cb()))
            box.append(b)

        btn("Starten", lambda: self._launch(app))
        if is_fav:
            btn("Aus Favoriten entfernen", lambda: (write_fav_remove(app["key"]), self._refresh_favs()))
        else:
            btn("Zu Favoriten hinzufügen", lambda: (write_fav_add(app["key"]), self._refresh_favs()))
        pop.set_child(box)
        pop.set_parent(widget)
        rect = Gdk.Rectangle()
        rect.x, rect.y, rect.width, rect.height = int(x), int(y), 1, 1
        pop.set_pointing_to(rect)
        pop.connect("closed", lambda p: GLib.idle_add(p.unparent))
        pop.popup()

    # ---------- Inhalt ----------
    def _fav_keys(self):
        keys = []
        for alts in read_favs():
            for k in alts:
                if k in self.by_key:
                    keys.append(k)
                    break
        return keys

    def _refresh_favs(self):
        while (c := self.favbox.get_first_child()) is not None:
            self.favbox.remove(c)
        for k in self._fav_keys():
            self.favbox.append(self._fav_tile(self.by_key[k]))
        self._fill_list(self.recent_list, self._recent_apps(3))

    def _recent_apps(self, n):
        data = read_recent()
        keys = sorted((k for k in data if k in self.by_key), key=lambda k: data[k][1], reverse=True)
        return [self.by_key[k] for k in keys[:n]]

    def _fill_list(self, lb, apps, specials=()):
        while (c := lb.get_first_child()) is not None:
            lb.remove(c)
        for sp in specials:
            lb.append(sp)
        for a in apps:
            lb.append(self._app_row(a))

    def _show_category(self, key):
        if key == "fav":
            self._refresh_favs()
            self.stack.set_visible_child_name("fav")
            return
        if key == "all":
            apps, title = self.apps, "ALLE APPS"
        elif key == "recent":
            apps, title = self._recent_apps(40), "ZULETZT VERWENDET"
        else:
            apps = [a for a in self.apps if a["cat"] == key]
            title = CAT_LABEL.get(key, key).upper()
        self.list_title.set_label(f"{title}   ·   {len(apps)}")
        self._fill_list(self.app_list, apps)
        self.empty.set_visible(not apps)
        self.list_scroll.set_visible(bool(apps))
        self.stack.set_visible_child_name("list")

    def _set_hint(self, text=None, warn=False):
        self.hint.set_label(text or "Rechtsklick: Favorit")
        (self.hint.add_css_class if warn else self.hint.remove_css_class)("warn")

    # ---------- Ereignisse ----------
    def _hover_cat(self, row):
        if not self.settings["hover_categories"] or self.search.get_text():
            return
        if self.cat_list.get_selected_row() is not row:
            self.cat_list.select_row(row)

    def _on_cat_selected(self, lb, row):
        if row is None or not hasattr(row, "_cat") or self.search.get_text():
            return
        self._show_category(row._cat)

    def _on_search(self, entry):
        raw = entry.get_text().strip()
        q = raw.lower()
        if not q:
            row = self.cat_list.get_selected_row()
            self._show_category(row._cat if row is not None and hasattr(row, "_cat") else "fav")
            return
        scored = []
        for a in self.apps:
            n = a["name"].lower()
            if n.startswith(q):
                s = 0
            elif any(w.startswith(q) for w in n.split()):
                s = 1
            elif q in n:
                s = 2
            elif q in a["blob"]:
                s = 3
            else:
                continue
            scored.append((s, n, a))
        scored.sort(key=lambda t: (t[0], t[1]))
        res = [t[2] for t in scored]

        specials = []
        result = calc(raw)
        if result is not None:
            specials.append(self._special_row("calc", f"= {result}", "Enter kopiert das Ergebnis",
                                              ("copy", result), None))
        web = self._special_row("web", f"Im Web suchen: {raw}", "DuckDuckGo im Browser",
                                ("web", raw), "web")
        self.list_title.set_label(f"SUCHE   ·   {len(res)}")
        self._fill_list(self.app_list, res, specials)
        self.app_list.append(web)
        self.empty.set_visible(False)
        self.list_scroll.set_visible(True)
        self.stack.set_visible_child_name("list")
        first = self.app_list.get_row_at_index(0)
        if first is not None:
            self.app_list.select_row(first)

    def _activate_row(self, row):
        if hasattr(row, "_app"):
            self._launch(row._app)
            return
        kind, val = getattr(row, "_action", (None, None))
        if kind == "copy":
            Gdk.Display.get_default().get_clipboard().set(val)
            self._set_hint(f"Kopiert: {val}")
            GLib.timeout_add(700, lambda: (self.close_menu(), False)[1])
        elif kind == "web":
            self._run("xdg-open " + GLib.shell_quote("https://duckduckgo.com/?q=" + GLib.uri_escape_string(val, None, False)))

    def _on_search_activate(self, entry):
        if self.stack.get_visible_child_name() == "list":
            row = self.app_list.get_selected_row() or self.app_list.get_row_at_index(0)
            if row is not None:
                self._activate_row(row)
        else:
            ch = self.favbox.get_child_at_index(0)
            if ch is not None:
                self._launch(ch._app)

    def _on_key(self, ctrl, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            if self.search.get_text():
                self.search.set_text("")
            else:
                self.close_menu()
            return True
        focus = self.get_focus()
        in_search = focus is not None and (focus is self.search or focus.is_ancestor(self.search))
        if keyval == Gdk.KEY_Down and in_search:
            if self.stack.get_visible_child_name() == "list":
                row = self.app_list.get_selected_row() or self.app_list.get_row_at_index(0)
                if row is not None:
                    self.app_list.select_row(row)
                    row.grab_focus()
                    return True
            else:
                ch = self.favbox.get_child_at_index(0)
                if ch is not None:
                    ch.grab_focus()
                    return True
            return False
        if not in_search:
            uni = Gdk.keyval_to_unicode(keyval)
            if uni and chr(uni).isprintable() and not (state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK)):
                self.search.grab_focus()
                self.search.set_text(self.search.get_text() + chr(uni))
                self.search.set_position(-1)
                return True
        return False

    def _on_root_click(self, gesture, n, x, y):
        ok, b = self.panel.compute_bounds(self)
        if not ok:
            return
        if not (b.get_x() <= x <= b.get_x() + b.get_width() and b.get_y() <= y <= b.get_y() + b.get_height()):
            self.close_menu()

    def _on_active_changed(self, *_):
        if self.screenshot or not self.get_visible():
            return
        if self.is_active():
            self.was_active = True      # erst schliessen, wenn es wirklich Fokus hatte
            return
        if not getattr(self, "was_active", False):
            return
        if time.monotonic() - self.opened_at < 0.3:
            return
        if not self.is_active():
            GLib.timeout_add(120, lambda: (self.close_menu() if self.get_visible() and not self.is_active() else None, False)[1])

    def _on_hypr_event(self, name, data):
        if not self.get_visible() or time.monotonic() - self.opened_at < 0.35:
            return
        if name in ("focusedmon", "focusedmonv2", "activewindow", "activewindowv2", "workspace", "workspacev2", "openwindow", "fullscreen", "activespecial"):
            self.close_menu()

    def _on_power(self, btn):
        action = btn._action
        if action == "lock":
            self._run("pidof hyprlock || hyprlock")
            return
        if action == "suspend":
            self._run("systemctl suspend")
            return
        if self.confirm_pending == action:
            cmds = {
                "logout": "command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'",
                "reboot": "systemctl reboot",
                "power": "systemctl poweroff",
            }
            self._run(cmds[action])
            return
        for b in self.power_btns.values():
            b.remove_css_class("confirm")
        self.confirm_pending = action
        btn.add_css_class("confirm")
        names = {"logout": "Abmelden", "reboot": "Neustart", "power": "Herunterfahren"}
        self._set_hint(f"Nochmal klicken: {names[action]}", warn=True)

        def reset():
            if self.confirm_pending == action:
                self.confirm_pending = None
                btn.remove_css_class("confirm")
                self._set_hint()
            return False
        GLib.timeout_add(3500, reset)

    # ---------- Aktionen ----------
    def _launch(self, app):
        try:
            ctx = self.get_display().get_app_launch_context()
            ctx.unsetenv("LD_PRELOAD")
            app["info"].launch([], ctx)
        except GLib.Error:
            run("gtk-launch " + GLib.shell_quote(app["key"]))
        bump_recent(app["key"])
        self.close_menu()

    def _run(self, cmd):
        run(cmd)
        self.close_menu()


class App(Gtk.Application):
    def __init__(self, args):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.DEFAULT_FLAGS)
        self.args = args
        self.win = None

    def do_startup(self):
        Gtk.Application.do_startup(self)
        prov = Gtk.CssProvider()
        if hasattr(prov, "load_from_string"):
            prov.load_from_string(CSS)
        else:
            prov.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION + 1)
        settings = Gtk.Settings.get_default()
        if settings is not None:
            settings.set_property("gtk-application-prefer-dark-theme", True)

    def do_activate(self):
        if self.win is not None:
            self.win.toggle(self.args.monitor)
            return
        self.win = StartMenu(self, self.args.monitor, self.args.screenshot, daemon=self.args.daemon)
        if self.args.daemon:
            self.hold()
            self._listen_fifo()
            if self.args.show:
                self.win.open_on(self.args.monitor)
            return
        self.win.present()
        if self.args.screenshot:
            if self.args.query:
                GLib.timeout_add(300, lambda: (self.win.search.set_text(self.args.query), False)[1])
            GLib.timeout_add(1200, self._snap)

    def _listen_fifo(self):
        """Befehle von startmenu.sh: 'toggle [MONITOR]', 'show [MONITOR]', 'hide', 'quit'."""
        os.makedirs(CACHE, exist_ok=True)
        try:
            if os.path.exists(FIFO) and not stat_is_fifo(FIFO):
                os.remove(FIFO)
            if not os.path.exists(FIFO):
                os.mkfifo(FIFO, 0o600)
        except OSError as e:
            print("FIFO-Fehler:", e, file=sys.stderr)
            return
        self.fifo_fd = os.open(FIFO, os.O_RDWR | os.O_NONBLOCK)
        self.fifo_buf = b""
        GLib.unix_fd_add_full(GLib.PRIORITY_DEFAULT, self.fifo_fd, GLib.IOCondition.IN, self._on_fifo)

    def _on_fifo(self, fd, cond):
        try:
            self.fifo_buf += os.read(fd, 4096)
        except BlockingIOError:
            return True
        while b"\n" in self.fifo_buf:
            line, self.fifo_buf = self.fifo_buf.split(b"\n", 1)
            parts = line.decode(errors="ignore").split()
            if not parts:
                continue
            cmd, mon = parts[0], (parts[1] if len(parts) > 1 else None)
            if cmd == "toggle":
                self.win.toggle(mon)
            elif cmd == "show":
                self.win.open_on(mon)
            elif cmd == "hide":
                self.win.close_menu()
            elif cmd == "quit":
                self.quit()
        return True

    def _snap(self):
        w = self.win.panel
        paintable = Gtk.WidgetPaintable.new(w)
        snap = Gtk.Snapshot()
        width, height = w.get_width(), w.get_height()
        paintable.snapshot(snap, width, height)
        tex = self.win.get_renderer().render_texture(snap.to_node(), None)
        tex.save_to_png(self.args.screenshot)
        print("screenshot", self.args.screenshot, width, height)
        self.quit()
        return False


def stat_is_fifo(path):
    import stat
    try:
        return stat.S_ISFIFO(os.stat(path).st_mode)
    except OSError:
        return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--monitor", default=None, help="Monitor-Name (z. B. DP-3)")
    p.add_argument("--daemon", action="store_true", help="im Hintergrund laufen, per FIFO auf-/zuklappen")
    p.add_argument("--show", action="store_true", help="mit --daemon: direkt anzeigen")
    p.add_argument("--screenshot", default=None, help=argparse.SUPPRESS)
    p.add_argument("--query", default=None, help=argparse.SUPPRESS)
    args = p.parse_args()
    os.environ.pop("LD_PRELOAD", None)
    app = App(args)
    return app.run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
