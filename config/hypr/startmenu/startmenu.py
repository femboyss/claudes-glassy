#!/usr/bin/env python3
# ==================================================================
#  claudes-glassy  -  Startmenue (Tokyo Night)
#  Aufbau inspiriert von Linux Mint (Seitenleiste mit System-Knoepfen,
#  Kategorien links, Apps rechts) und KDE Kickoff (Suche oben,
#  Favoriten, Zuletzt verwendet, Orte unten).
#
#  Start:   ~/.config/hypr/scripts/startmenu.sh   (Super antippen)
#  Debug:   python3 ~/.config/hypr/startmenu/startmenu.py
#
#  Favoriten:  ~/.config/hypr/pinned-apps  (Rechtsklick auf eine App
#              -> "Zu Favoriten" / "Aus Favoriten" geht auch)
# ==================================================================
import argparse
import json
import os
import socket
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
CACHE = os.path.join(HOME, ".cache", "claudes-glassy")
RECENT_FILE = os.path.join(CACHE, "recent.json")
SCRIPTS = os.path.join(HYPR, "scripts")
APP_ID = "glassy.startmenu"
FIFO = os.path.join(CACHE, "startmenu.fifo")

PANEL_W, PANEL_H = 580, 460
MARGIN_TOP, MARGIN_LEFT = 54, 14

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
    "music": "", "video": "",
}

# Freedesktop-Hauptkategorien -> Anzeige (Reihenfolge = Liste links)
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
@define-color tn_magenta   #ff007c;
@define-color tn_green     #9ece6a;
@define-color tn_orange    #ff9e64;
@define-color tn_yellow    #e0af68;
@define-color tn_red       #f7768e;
@define-color tn_teal      #1abc9c;

window, window.background { background: transparent; }

* { font-family: "Inter", "JetBrainsMono Nerd Font", sans-serif; }

.panel {
    background-color: alpha(@tn_bg, 0.80);
    border: 1px solid alpha(@tn_blue, 0.22);
    border-radius: 18px;
    box-shadow: 0 10px 30px alpha(black, 0.40);
    color: @tn_fg;
}

/* Header */
.header { padding: 12px 14px 8px 14px; }
.avatar { border-radius: 999px; border: 2px solid alpha(@tn_purple, 0.8); }
.hello  { font-size: 13px; font-weight: 800; color: @tn_fg; }
.sub    { font-size: 10px; color: @tn_comment; }
.glyph  { font-family: "JetBrainsMono Nerd Font"; }

entry.search {
    min-height: 32px;
    min-width: 210px;
    padding: 0 10px;
    border-radius: 10px;
    font-size: 12px;
    background-color: alpha(@tn_bg_dark, 0.85);
    border: 1px solid alpha(@tn_blue, 0.28);
    color: @tn_fg;
    caret-color: @tn_cyan;
    box-shadow: none;
    outline: none;
}
entry.search:focus-within {
    border-color: alpha(@tn_cyan, 0.75);
    box-shadow: 0 0 0 3px alpha(@tn_cyan, 0.12);
}
entry.search image { color: @tn_blue; }

/* Seitenleiste (Mint) */
.sidebar {
    padding: 6px 4px;
    margin: 0 0 0 10px;
    border-radius: 12px;
    background-color: alpha(@tn_bg_dark, 0.55);
}
.sidebtn {
    min-width: 30px; min-height: 30px;
    padding: 0;
    border-radius: 8px;
    background: transparent;
    border: none;
    box-shadow: none;
    color: @tn_fg_dark;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 13px;
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
.cats { background: transparent; margin: 0 4px 0 8px; }
.cats row {
    min-height: 26px;
    padding: 0 9px;
    margin: 1px 0;
    border-radius: 8px;
    color: @tn_fg_dark;
    background: transparent;
}
.cats row:hover    { background-color: alpha(@tn_bg_hl, 0.65); color: @tn_fg; }
.cats row:selected {
    background-color: alpha(@tn_blue, 0.16);
    color: @tn_blue;
    box-shadow: inset 3px 0 0 @tn_blue;
}
.cats .catglyph { font-family: "JetBrainsMono Nerd Font"; min-width: 16px; font-size: 11px; }
.cats .catname  { font-size: 12px; font-weight: 600; }
.cats row.seprow, .cats row.seprow:hover { min-height: 0; padding: 0; margin: 4px 0; background: none; box-shadow: none; }
.sep { background-color: alpha(@tn_comment, 0.25); min-height: 1px; margin: 4px 10px; }

/* Inhalt */
.content { margin: 0 10px 0 2px; }
.section { font-size: 9.5px; font-weight: 800; color: @tn_comment; letter-spacing: 1px; margin: 2px 6px 4px 6px; }

.apps { background: transparent; }
.apps row {
    padding: 4px 8px;
    margin: 1px 0;
    border-radius: 8px;
    background: transparent;
}
.apps row:hover, .apps row:selected { background-color: alpha(@tn_bg_hl, 0.85); }
.apps row:selected .appname { color: @tn_cyan; }
.appname { font-size: 12px; font-weight: 600; color: @tn_fg; }
.appdesc { font-size: 10px; color: @tn_comment; }

flowbox.favs { background: transparent; }
flowbox.favs flowboxchild {
    padding: 8px 2px 6px 2px;
    margin: 2px;
    border-radius: 10px;
    background-color: alpha(@tn_bg_hl, 0.30);
    border: 1px solid transparent;
}
flowbox.favs flowboxchild:hover,
flowbox.favs flowboxchild:selected {
    background-color: alpha(@tn_bg_hl, 0.9);
    border-color: alpha(@tn_purple, 0.45);
}
.favname { font-size: 10px; font-weight: 600; color: @tn_fg_dark; }

.empty { color: @tn_comment; font-size: 13px; margin: 40px; }

/* Fusszeile (Kickoff-Orte) */
.footer { padding: 6px 12px 8px 12px; }
.place {
    padding: 2px 8px;
    min-height: 24px;
    border-radius: 7px;
    font-family: "JetBrainsMono Nerd Font";
    font-size: 12px;
    background: transparent;
    border: none;
    box-shadow: none;
    color: @tn_fg_dark;
}
.place:hover { background-color: alpha(@tn_bg_hl, 0.8); color: @tn_green; }
.place { color: @tn_teal; }
.hint { font-size: 10px; color: @tn_comment; }
.hint.warn { color: @tn_red; font-weight: 700; }

scrollbar { background: transparent; }
scrollbar slider { background-color: alpha(@tn_comment, 0.5); border-radius: 99px; min-width: 4px; }

popover.ctx > contents {
    background-color: @tn_bg_dark;
    border: 1px solid alpha(@tn_blue, 0.3);
    border-radius: 12px;
    padding: 4px;
}
popover.ctx button {
    background: transparent; border: none; box-shadow: none;
    color: @tn_fg; border-radius: 8px; padding: 6px 12px;
}
popover.ctx button:hover { background-color: @tn_bg_hl; color: @tn_cyan; }
"""


# ------------------------------------------------------------------ Daten
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


# ------------------------------------------------------------------ UI
class StartMenu(Gtk.ApplicationWindow):
    def __init__(self, app, monitor_name=None, screenshot=None, daemon=False):
        super().__init__(application=app, title="Startmenue")
        self.app = app
        self.daemon = daemon
        self.screenshot = screenshot
        self.apps_dirty = False
        self.apps = load_apps()
        self.by_key = {a["key"]: a for a in self.apps}
        self.confirm_pending = None
        self.layer = False

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
        if self.layer:
            self.panel.set_halign(Gtk.Align.START)
            self.panel.set_valign(Gtk.Align.START)
            self.panel.set_margin_top(MARGIN_TOP)
            self.panel.set_margin_start(MARGIN_LEFT)
            click = Gtk.GestureClick()
            click.connect("pressed", self._on_root_click)
            root.add_controller(click)
        root.append(self.panel)

        keys = Gtk.EventControllerKey()
        keys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        keys.connect("key-pressed", self._on_key)
        self.add_controller(keys)

        # Fokus weg (anderes Fenster / anderer Monitor angeklickt) -> schliessen
        self.connect("notify::is-active", self._on_active_changed)

        # neue/entfernte Apps merken, beim naechsten Oeffnen neu laden
        self.appmon = Gio.AppInfoMonitor.get()
        self.appmon.connect("changed", lambda *_: setattr(self, "apps_dirty", True))

        self.reset_view()

    # ---------- Oeffnen / Schliessen ----------
    def _update_header(self):
        user = os.environ.get("USER") or os.path.basename(HOME)
        self.hello_lbl.set_label(f"{greeting()}, {user[:1].upper() + user[1:]}")
        self.sub_lbl.set_label(f"{user}@{socket.gethostname()}   \u00b7   {uptime_text()}")

    def reset_view(self):
        self.confirm_pending = None
        for b in getattr(self, "power_btns", {}).values():
            b.remove_css_class("confirm")
        self.hint.set_label("Rechtsklick: Favorit")
        self.hint.remove_css_class("warn")
        self.search.set_text("")
        self._update_header()
        self.cat_list.select_row(self.cat_list.get_row_at_index(0))
        self._show_category("fav")
        GLib.idle_add(self.search.grab_focus)

    def _reload_apps(self):
        self.apps = load_apps()
        self.by_key = {a["key"]: a for a in self.apps}
        self.apps_dirty = False

    def open_on(self, monitor_name=None):
        if self.apps_dirty:
            self._reload_apps()
        if self.layer:
            mon = self._find_monitor(monitor_name)
            if mon is not None:
                LS.set_monitor(self, mon)
        self.reset_view()
        self.opened_at = time.monotonic()
        self.present()

    def toggle(self, monitor_name=None):
        if self.get_visible():
            self.close_menu()
        else:
            self.open_on(monitor_name)

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
        box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        box.add_css_class("header")

        av = Gtk.Box()
        av.add_css_class("avatar")
        av.set_overflow(Gtk.Overflow.HIDDEN)
        av.set_valign(Gtk.Align.CENTER)
        pic = None
        if os.path.exists(AVATAR):
            try:
                pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(AVATAR, 64, 64, False)
                pic = Gtk.Image.new_from_paintable(Gdk.Texture.new_for_pixbuf(pb))
            except GLib.Error:
                pic = None
        if pic is None:
            pic = Gtk.Image.new_from_icon_name("avatar-default")
        pic.set_pixel_size(32)
        pic.set_size_request(32, 32)
        pic.set_halign(Gtk.Align.CENTER)
        pic.set_valign(Gtk.Align.CENTER)
        av.set_size_request(32, 32)
        av.set_hexpand(False)
        av.set_vexpand(False)
        av.append(pic)
        box.append(av)

        user = os.environ.get("USER") or os.path.basename(HOME)
        texts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        texts.set_valign(Gtk.Align.CENTER)
        hello = Gtk.Label(label="", xalign=0)
        self.hello_lbl = hello
        hello.add_css_class("hello")
        sub = Gtk.Label(label="", xalign=0)
        self.sub_lbl = sub
        sub.add_css_class("sub")
        texts.append(hello)
        texts.append(sub)
        self._update_header()
        texts.set_hexpand(True)
        box.append(texts)

        self.search = Gtk.SearchEntry()
        self.search.add_css_class("search")
        self.search.set_placeholder_text("Suchen ...")
        self.search.set_valign(Gtk.Align.CENTER)
        self.search.connect("search-changed", self._on_search)
        self.search.connect("activate", self._on_search_activate)
        box.append(self.search)
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
        bar.append(self._sidebtn("settings", "Einstellungen", lambda *_: self._run(os.path.join(SCRIPTS, "settings.sh"))))
        spacer = Gtk.Box()
        spacer.set_vexpand(True)
        bar.append(spacer)
        self.power_btns = {}
        for key, tip, extra in (("lock", "Sperren", "lock"), ("logout", "Abmelden", "logout"),
                                ("suspend", "Energiesparen", "suspend"), ("reboot", "Neustart", "reboot"),
                                ("power", "Herunterfahren", "power")):
            btn = self._sidebtn(key, tip, self._on_power, extra)
            btn._action = key
            self.power_btns[key] = btn
            bar.append(btn)
        return bar

    def _cat_row(self, key, label, glyph_key):
        row = Gtk.ListBoxRow()
        row._cat = key
        box = Gtk.Box(spacing=8)
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
        self.cat_list.set_size_request(140, -1)
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
        sw.set_size_request(150, -1)
        return sw

    def _build_content(self):
        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.stack.set_transition_duration(120)
        self.stack.set_hexpand(True)
        self.stack.add_css_class("content")

        # Favoriten-Seite (Raster + Zuletzt)
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
        t2 = Gtk.Label(label="ZULETZT VERWENDET", xalign=0)
        t2.add_css_class("section")
        t2.set_margin_top(6)
        fav_page.append(t2)
        self.recent_list = self._new_app_list()
        fav_page.append(self.recent_list)
        fsw = Gtk.ScrolledWindow()
        fsw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        fsw.set_child(fav_page)
        self.stack.add_named(fsw, "fav")

        # Listen-Seite
        lpage = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.list_title = Gtk.Label(label="", xalign=0)
        self.list_title.add_css_class("section")
        lpage.append(self.list_title)
        self.app_list = self._new_app_list()
        self.app_list.set_vexpand(True)
        lsw = Gtk.ScrolledWindow()
        lsw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        lsw.set_vexpand(True)
        lsw.set_child(self.app_list)
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
        lb.connect("row-activated", lambda l, r: self._launch(r._app))
        return lb

    def _build_footer(self):
        box = Gtk.Box(spacing=4)
        box.add_css_class("footer")
        for key, name, xdg, fb in (("home", "Persoenlich", None, ""),
                                   ("down", "Downloads", "DOWNLOAD", "Downloads"),
                                   ("docs", "Dokumente", "DOCUMENTS", "Documents"),
                                   ("pics", "Bilder", "PICTURES", "Pictures"),
                                   ("music", "Musik", "MUSIC", "Music")):
            path = HOME if xdg is None else xdg_dir(xdg, fb)
            b = Gtk.Button()
            b.add_css_class("place")
            b.set_focusable(False)
            inner = Gtk.Box()
            inner.append(glyph(G[key]))
            b.set_child(inner)
            b.set_tooltip_text(name.replace("oe", "ö") + "  -  " + path)
            b.connect("clicked", lambda _b, p=path: self._run("xdg-open " + GLib.shell_quote(p)))
            box.append(b)
        sp = Gtk.Box()
        sp.set_hexpand(True)
        box.append(sp)
        self.hint = Gtk.Label(label="Rechtsklick: Favorit")
        self.hint.add_css_class("hint")
        box.append(self.hint)
        return box

    # ---------- App-Zeilen / Kacheln ----------
    def _app_row(self, app):
        row = Gtk.ListBoxRow()
        row._app = app
        box = Gtk.Box(spacing=9)
        img = Gtk.Image.new_from_gicon(app["icon"]) if app["icon"] else Gtk.Image.new_from_icon_name("application-x-executable")
        img.set_pixel_size(22)
        box.append(img)
        tb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        tb.set_valign(Gtk.Align.CENTER)
        n = Gtk.Label(label=app["name"], xalign=0)
        n.add_css_class("appname")
        n.set_ellipsize(Pango.EllipsizeMode.END)
        tb.append(n)
        if app["desc"]:
            d = Gtk.Label(label=app["desc"], xalign=0)
            d.add_css_class("appdesc")
            d.set_ellipsize(Pango.EllipsizeMode.END)
            d.set_max_width_chars(34)
            tb.append(d)
        box.append(tb)
        row.set_child(box)
        self._attach_context(row, app)
        return row

    def _fav_tile(self, app):
        ch = Gtk.FlowBoxChild()
        ch._app = app
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        img = Gtk.Image.new_from_gicon(app["icon"]) if app["icon"] else Gtk.Image.new_from_icon_name("application-x-executable")
        img.set_pixel_size(30)
        box.append(img)
        n = Gtk.Label(label=app["name"])
        n.add_css_class("favname")
        n.set_ellipsize(Pango.EllipsizeMode.END)
        n.set_max_width_chars(10)
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

    # ---------- Inhalt fuellen ----------
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

    def _fill_list(self, lb, apps):
        while (c := lb.get_first_child()) is not None:
            lb.remove(c)
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
        self.stack.set_visible_child_name("list")

    # ---------- Ereignisse ----------
    def _hover_cat(self, row):
        if self.search.get_text():
            return
        if self.cat_list.get_selected_row() is not row:
            self.cat_list.select_row(row)

    def _on_cat_selected(self, lb, row):
        if row is None or not hasattr(row, "_cat"):
            return
        if self.search.get_text():
            return
        self._show_category(row._cat)

    def _on_search(self, entry):
        q = entry.get_text().strip().lower()
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
        self.list_title.set_label(f"SUCHE   ·   {len(res)}")
        self._fill_list(self.app_list, res)
        self.empty.set_visible(not res)
        self.stack.set_visible_child_name("list")
        first = self.app_list.get_row_at_index(0)
        if first is not None:
            self.app_list.select_row(first)

    def _on_search_activate(self, entry):
        if self.stack.get_visible_child_name() == "list":
            row = self.app_list.get_selected_row() or self.app_list.get_row_at_index(0)
            if row is not None:
                self._launch(row._app)
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
        # Tippen irgendwo -> ab ins Suchfeld (wie Kickoff)
        if not in_search:
            uni = Gdk.keyval_to_unicode(keyval)
            if uni and chr(uni).isprintable() and not (state & (Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.ALT_MASK)):
                self.search.grab_focus()
                self.search.set_text(self.search.get_text() + chr(uni))
                self.search.set_position(-1)
                return True
        return False

    def _on_root_click(self, gesture, n, x, y):
        ok, rect = self.panel.compute_bounds(self.get_child())
        if not ok:
            return
        b = rect
        if not (b.get_x() <= x <= b.get_x() + b.get_width() and b.get_y() <= y <= b.get_y() + b.get_height()):
            self.close_menu()

    def _on_active_changed(self, *_):
        if self.screenshot or not self.get_visible():
            return
        if time.monotonic() - getattr(self, "opened_at", 0) < 0.4:
            return
        if not self.is_active():
            GLib.timeout_add(120, lambda: (self.close_menu() if self.get_visible() and not self.is_active() else None, False)[1])

    def _on_power(self, btn):
        action = btn._action
        if action == "lock":
            self._run("pidof hyprlock || hyprlock")
            return
        if action == "suspend":
            self._run("systemctl suspend")
            return
        # Abmelden / Neustart / Aus: zweiter Klick bestaetigt (wie Mint)
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
        names = {"logout": "abmelden", "reboot": "neu starten", "power": "herunterfahren"}
        self.hint.set_label(f"Nochmal klicken zum {names[action].capitalize()}")
        self.hint.add_css_class("warn")

        def reset():
            if self.confirm_pending == action:
                self.confirm_pending = None
                btn.remove_css_class("confirm")
                self.hint.set_label("Rechtsklick: Favorit")
                self.hint.remove_css_class("warn")
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

    def close_menu(self):
        if self.screenshot:
            return
        if self.daemon:
            self.set_visible(False)
        else:
            self.app.quit()


class App(Gtk.Application):
    def __init__(self, args):
        super().__init__(application_id=APP_ID, flags=Gio.ApplicationFlags.DEFAULT_FLAGS)
        self.args = args
        self.win = None

    def do_startup(self):
        Gtk.Application.do_startup(self)
        prov = Gtk.CssProvider()
        prov.load_from_string(CSS) if hasattr(prov, "load_from_string") else prov.load_from_data(CSS.encode())
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
            self.hold()                      # weiterlaufen, auch wenn versteckt
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
        # O_RDWR: kein EOF, wenn der Schreiber wieder zumacht
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
        node = snap.to_node()
        tex = self.win.get_renderer().render_texture(node, None)
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
    # LD_PRELOAD wird nur fuer uns selbst gebraucht, nicht fuer gestartete Apps
    os.environ.pop("LD_PRELOAD", None)
    app = App(args)
    return app.run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
