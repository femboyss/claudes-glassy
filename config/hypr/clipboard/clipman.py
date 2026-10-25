#!/usr/bin/env python3
# ==================================================================
#  claudes-glassy  -  Zwischenablage (Tokyo Night)           SUPER+V
#  Verlauf aus cliphist mit Suche, Bild-Vorschau, Loeschen-Knopf pro
#  Eintrag und "Alles loeschen".
#    Klick / Enter      -> zurueck in die Zwischenablage
#    Muelleimer / Entf  -> Eintrag loeschen
#    Alles loeschen     -> zweimal klicken (Sicherheit)
#    Esc / daneben      -> schliessen
#  Laeuft als Dienst (startet mit Hyprland). Log: ~/.cache/claudes-glassy/clipboard.log
# ==================================================================
import argparse
import hashlib
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


def _theme_css():
    """Farben des aktiven Themes (erzeugt von theme/theme.py) - kommen NACH den
    Standardfarben, ueberschreiben sie also."""
    try:
        with open(os.path.expanduser("~/.config/hypr/theme/colors.css"), encoding="utf-8") as f:
            return "\n" + f.read()
    except OSError:
        return ""


def _themed(css):
    """Theme-Farben einsetzen: GTK nimmt bei doppeltem @define-color nicht zuverlaessig
    den letzten Wert -> eigene Standardwerte fuer diese Namen entfernen, Theme davor."""
    import re
    t = _theme_css()
    if not t:
        return css
    names = set(re.findall(r"@define-color\s+(\w+)", t))
    css = re.sub(r"^[ \t]*@define-color\s+(\w+)[^\n]*\n",
                 lambda m: "" if m.group(1) in names else m.group(0), css, flags=re.M)
    return t + "\n" + css

HOME = os.path.expanduser("~")
CACHE = os.path.join(HOME, ".cache", "claudes-glassy")
THUMBS = os.path.join(CACHE, "clip-thumbs")
FIFO = os.path.join(CACHE, "clipboard.fifo")
PANEL_W, PANEL_H = 440, 500
MAX_ITEMS = 300
MAX_THUMBS = 40

G = {"search": "", "trash": "", "img": "", "text": "", "link": "",
     "clip": "", "check": ""}

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
@define-color tn_on_accent #16161e;
@define-color tn_island_bg rgba(6, 6, 10, 0.92);

window, window.background, window.background:backdrop, window > *, .frame {
    background: none; background-color: transparent; background-image: none;
    box-shadow: none; border: none; }
* { font-family: "Inter", "JetBrainsMono Nerd Font", sans-serif; }

.panel {
    background-color: alpha(@tn_bg, 0.84);
    background-image: linear-gradient(90deg, alpha(@tn_purple, 0.0), alpha(@tn_blue, 0.85), alpha(@tn_cyan, 0.85), alpha(@tn_purple, 0.0));
    background-size: 100% 2px;
    background-repeat: no-repeat;
    background-position: top;
    border: 1px solid alpha(@tn_blue, 0.20);
    border-radius: 16px;
    box-shadow: 0 10px 28px alpha(black, 0.42);
    color: @tn_fg;
}
.head { padding: 12px 12px 6px 14px; }
.title { font-size: 13px; font-weight: 800; color: @tn_fg; }
.count { font-size: 10px; font-weight: 700; color: @tn_comment; }
.glyph { font-family: "JetBrainsMono Nerd Font"; }
.titleglyph { color: @tn_blue; font-size: 13px; }

button.wipe {
    min-height: 26px; padding: 0 10px;
    border-radius: 8px; border: 1px solid alpha(@tn_red, 0.35); box-shadow: none;
    background: alpha(@tn_red, 0.08);
    color: @tn_red; font-size: 11px; font-weight: 700;
    transition: all 140ms ease;
}
button.wipe:hover   { background: alpha(@tn_red, 0.20); }
button.wipe.confirm { background: @tn_red; color: @tn_on_accent; border-color: @tn_red; }

entry.search {
    min-height: 30px; margin: 0 12px 8px 12px; padding: 0 10px;
    border-radius: 10px; font-size: 12px;
    background-color: alpha(@tn_bg_dark, 0.85);
    border: 1px solid alpha(@tn_blue, 0.22);
    color: @tn_fg; caret-color: @tn_cyan; box-shadow: none; outline: none;
}
entry.search:focus-within { border-color: alpha(@tn_cyan, 0.75); }
entry.search image { color: @tn_blue; }

.items { background: transparent; margin: 0 8px; }
.items row {
    padding: 6px 6px 6px 8px; margin: 2px 0;
    border-radius: 10px;
    background-color: alpha(@tn_hl, 0.28);
    border: 1px solid transparent;
    transition: all 120ms ease;
}
.items row:hover, .items row:selected {
    background-color: alpha(@tn_hl, 0.95);
    border-color: alpha(@tn_purple, 0.40);
}
.kind { font-family: "JetBrainsMono Nerd Font"; font-size: 12px; color: @tn_comment; min-width: 18px; }
.items row:selected .kind { color: @tn_cyan; }
.preview { font-size: 11.5px; color: @tn_fg; }
.meta    { font-size: 9.5px; color: @tn_comment; }
.thumb   { border-radius: 7px; }

button.del {
    min-width: 28px; min-height: 28px; padding: 0;
    border-radius: 8px; border: none; box-shadow: none;
    background: transparent;
    color: @tn_comment;
    font-family: "JetBrainsMono Nerd Font"; font-size: 12px;
    transition: all 120ms ease;
}
button.del:hover { background: alpha(@tn_red, 0.18); color: @tn_red; }

.empty { color: @tn_comment; font-size: 12px; margin: 60px 20px; }
.foot  { padding: 6px 14px 9px 14px; }
.hint  { font-size: 9.5px; color: @tn_comment; }
.hint.ok { color: @tn_green; font-weight: 700; }
scrollbar { background: transparent; }
scrollbar slider { background-color: alpha(@tn_comment, 0.45); border-radius: 99px; min-width: 3px; }
"""


def run_cmd(argv, data=None, timeout=3):
    env = dict(os.environ)
    env.pop("LD_PRELOAD", None)
    try:
        r = subprocess.run(argv, input=data, capture_output=True, timeout=timeout, env=env)
        return r.stdout
    except (OSError, subprocess.SubprocessError):
        return b""


def human(n):
    for unit in ("B", "KiB", "MiB"):
        if n < 1024:
            return f"{n:.0f} {unit}"
        n /= 1024
    return f"{n:.1f} GiB"


def load_items():
    """cliphist list -> [{line, id, text, is_img}] (neueste zuerst)."""
    out = run_cmd(["cliphist", "list"]).decode("utf-8", "replace")
    items = []
    for line in out.splitlines()[:MAX_ITEMS]:
        if "\t" not in line:
            continue
        cid, text = line.split("\t", 1)
        is_img = text.startswith("[[ binary data") and any(t in text for t in ("png", "jpeg", "jpg", "webp", "gif", "bmp"))
        items.append({"line": line, "id": cid, "text": text, "is_img": is_img})
    return items


def thumb_for(item):
    os.makedirs(THUMBS, exist_ok=True)
    path = os.path.join(THUMBS, hashlib.sha1(item["line"].encode()).hexdigest()[:16] + ".img")
    if not os.path.exists(path):
        data = run_cmd(["cliphist", "decode"], data=item["line"].encode())
        if not data:
            return None
        with open(path, "wb") as f:
            f.write(data)
    try:
        return GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 96, 64, True)
    except GLib.Error:
        return None




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
class ClipWindow(Gtk.ApplicationWindow):
    def __init__(self, app, daemon=False, screenshot=False):
        super().__init__(application=app, title="Zwischenablage")
        self.app = app
        self.daemon = daemon
        self.screenshot = screenshot
        self.items = []
        self.opened_at = 0.0
        self.was_active = False
        self.wipe_armed = False
        self.layer = False
        self.set_decorated(False)
        self.set_resizable(False)

        if LS is not None and LS.is_supported() and not screenshot:
            self.layer = True
            LS.init_for_window(self)
            LS.set_namespace(self, "glassy-clipboard")
            LS.set_layer(self, LS.Layer.OVERLAY)
            LS.set_keyboard_mode(self, LS.KeyboardMode.EXCLUSIVE)
            for e in (LS.Edge.TOP, LS.Edge.BOTTOM, LS.Edge.LEFT, LS.Edge.RIGHT):
                LS.set_anchor(self, e, True)
            LS.set_exclusive_zone(self, -1)
            # Wichtig: sonst ist die Ebene nur so gross wie der Inhalt und klebt links oben
            self.set_resizable(True)
        else:
            self.set_default_size(PANEL_W, PANEL_H)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(root)
        self.panel = self._build()
        self.rev = Gtk.Revealer()
        self.rev.set_transition_type(Gtk.RevealerTransitionType.CROSSFADE)
        self.rev.set_transition_duration(140)
        self.rev.set_child(self.panel)
        if self.layer:
            self.rev.set_halign(Gtk.Align.CENTER)
            self.rev.set_valign(Gtk.Align.CENTER)
            click = Gtk.GestureClick()
            click.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
            click.connect("pressed", self._on_outside_click)
            self.add_controller(click)
        root.append(self.rev)

        keys = Gtk.EventControllerKey()
        keys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
        keys.connect("key-pressed", self._on_key)
        self.add_controller(keys)
        self.connect("notify::is-active", self._on_active)
        if daemon:
            self.hypr = HyprEvents(self._on_hypr_event)
        if screenshot:
            self.rev.set_reveal_child(True)

    # ---------- Aufbau ----------
    def _build(self):
        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        panel.add_css_class("panel")
        panel.set_size_request(PANEL_W, PANEL_H)
        panel.set_overflow(Gtk.Overflow.HIDDEN)

        head = Gtk.Box(spacing=8)
        head.add_css_class("head")
        g = Gtk.Label(label=G["clip"])
        g.add_css_class("glyph")
        g.add_css_class("titleglyph")
        head.append(g)
        t = Gtk.Label(label="Zwischenablage", xalign=0)
        t.add_css_class("title")
        head.append(t)
        self.count = Gtk.Label(xalign=0)
        self.count.add_css_class("count")
        self.count.set_hexpand(True)
        head.append(self.count)
        self.wipe = Gtk.Button(label=G["trash"] + "  Alles löschen")
        self.wipe.add_css_class("wipe")
        self.wipe.set_focusable(False)
        self.wipe.connect("clicked", self._on_wipe)
        head.append(self.wipe)
        panel.append(head)

        self.search = Gtk.SearchEntry()
        self.search.add_css_class("search")
        self.search.set_placeholder_text("Verlauf durchsuchen ...")
        self.search.connect("search-changed", lambda *_: self._fill())
        self.search.connect("activate", lambda *_: self._activate_selected())
        panel.append(self.search)

        self.listbox = Gtk.ListBox()
        self.listbox.add_css_class("items")
        self.listbox.set_selection_mode(Gtk.SelectionMode.SINGLE)
        self.listbox.set_activate_on_single_click(True)
        self.listbox.connect("row-activated", lambda lb, row: self._paste(row._item))
        self.scroll = Gtk.ScrolledWindow()
        self.scroll.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
        self.scroll.set_vexpand(True)
        self.scroll.set_child(self.listbox)
        panel.append(self.scroll)

        self.empty = Gtk.Label(label="Zwischenablage ist leer")
        self.empty.add_css_class("empty")
        self.empty.set_vexpand(True)
        self.empty.set_visible(False)
        panel.append(self.empty)

        foot = Gtk.Box()
        foot.add_css_class("foot")
        self.hint = Gtk.Label(xalign=0)
        self.hint.add_css_class("hint")
        foot.append(self.hint)
        panel.append(foot)
        self._set_hint()
        return panel

    def _set_hint(self, text=None, ok=False):
        self.hint.set_label(text or "Enter: einfügen   ·   Entf: löschen   ·   Esc: schließen")
        (self.hint.add_css_class if ok else self.hint.remove_css_class)("ok")

    def _row(self, item, with_thumb):
        row = Gtk.ListBoxRow()
        row._item = item
        box = Gtk.Box(spacing=9)
        text = item["text"]
        pic = thumb_for(item) if (item["is_img"] and with_thumb) else None
        if pic is not None:
            img = Gtk.Image.new_from_paintable(Gdk.Texture.new_for_pixbuf(pic))
            img.set_pixel_size(52)
            img.add_css_class("thumb")
            box.append(img)
        else:
            kind = G["img"] if item["is_img"] else (G["link"] if text.startswith(("http://", "https://")) else G["text"])
            k = Gtk.Label(label=kind)
            k.add_css_class("kind")
            k.set_valign(Gtk.Align.START)
            k.set_margin_top(2)
            box.append(k)

        tb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        tb.set_hexpand(True)
        tb.set_valign(Gtk.Align.CENTER)
        if item["is_img"]:
            p = Gtk.Label(label="Bild", xalign=0)
            p.add_css_class("preview")
            m = Gtk.Label(label=text.strip("[] ").replace("binary data ", ""), xalign=0)
            m.add_css_class("meta")
            tb.append(p)
            tb.append(m)
        else:
            flat = " ".join(text.split())
            p = Gtk.Label(label=flat or "(leer)", xalign=0)
            p.add_css_class("preview")
            p.set_ellipsize(Pango.EllipsizeMode.END)
            p.set_lines(2)
            p.set_wrap(True)
            p.set_wrap_mode(Pango.WrapMode.WORD_CHAR)
            p.set_max_width_chars(44)
            tb.append(p)
            m = Gtk.Label(label=f"{len(text)} Zeichen" + ("  ·  Link" if text.startswith(("http://", "https://")) else ""), xalign=0)
            m.add_css_class("meta")
            tb.append(m)
        box.append(tb)

        d = Gtk.Button(label=G["trash"])
        d.add_css_class("del")
        d.set_tooltip_text("Diesen Eintrag löschen")
        d.set_valign(Gtk.Align.CENTER)
        d.set_focusable(False)
        d.connect("clicked", lambda *_: self._delete(row))
        box.append(d)
        row.set_child(box)
        return row

    # ---------- Daten ----------
    def reload(self):
        self.items = load_items()
        self._fill()

    def _fill(self):
        while (c := self.listbox.get_first_child()) is not None:
            self.listbox.remove(c)
        q = self.search.get_text().strip().lower()
        shown = [it for it in self.items if not q or q in it["text"].lower()]
        thumbs = 0
        for it in shown:
            with_thumb = it["is_img"] and thumbs < MAX_THUMBS
            thumbs += 1 if it["is_img"] else 0
            self.listbox.append(self._row(it, with_thumb))
        n = len(self.items)
        self.count.set_label(f"{n} Einträge" if n != 1 else "1 Eintrag")
        self.wipe.set_sensitive(n > 0)
        self.empty.set_label("Nichts gefunden" if (q and self.items) else "Zwischenablage ist leer")
        self.empty.set_visible(not shown)
        self.scroll.set_visible(bool(shown))
        first = self.listbox.get_row_at_index(0)
        if first is not None:
            self.listbox.select_row(first)

    # ---------- Aktionen ----------
    def _paste(self, item):
        data = run_cmd(["cliphist", "decode"], data=item["line"].encode())
        if data:
            mime = []
            if item["is_img"]:
                for t in ("png", "jpeg", "webp", "gif", "bmp"):
                    if t in item["text"]:
                        mime = ["--type", "image/" + t]
                        break
            env = dict(os.environ)
            env.pop("LD_PRELOAD", None)
            subprocess.Popen(["wl-copy"] + mime, stdin=subprocess.PIPE, env=env,
                             start_new_session=True).communicate(data, timeout=3)
        self.close_menu()

    def _delete(self, row):
        item = row._item
        run_cmd(["cliphist", "delete"], data=item["line"].encode())
        idx = row.get_index()
        self.items = [it for it in self.items if it["line"] != item["line"]]
        self.listbox.remove(row)
        n = len(self.items)
        self.count.set_label(f"{n} Einträge" if n != 1 else "1 Eintrag")
        nxt = self.listbox.get_row_at_index(min(idx, max(0, n - 1)))
        if nxt is not None:
            self.listbox.select_row(nxt)
        else:
            self._fill()
        self._set_hint("Gelöscht", ok=True)
        GLib.timeout_add(1200, lambda: (self._set_hint(), False)[1])

    def _on_wipe(self, *_):
        if not self.wipe_armed:
            self.wipe_armed = True
            self.wipe.add_css_class("confirm")
            self.wipe.set_label(G["trash"] + "  Wirklich alles?")

            def disarm():
                if self.wipe_armed:
                    self.wipe_armed = False
                    self.wipe.remove_css_class("confirm")
                    self.wipe.set_label(G["trash"] + "  Alles löschen")
                return False
            GLib.timeout_add(3000, disarm)
            return
        self.wipe_armed = False
        self.wipe.remove_css_class("confirm")
        self.wipe.set_label(G["trash"] + "  Alles löschen")
        run_cmd(["cliphist", "wipe"])
        run_cmd(["wl-copy", "--clear"])
        self.items = []
        self._fill()
        self._set_hint("Verlauf gelöscht", ok=True)

    def _activate_selected(self):
        row = self.listbox.get_selected_row() or self.listbox.get_row_at_index(0)
        if row is not None:
            self._paste(row._item)

    # ---------- Oeffnen / Schliessen ----------
    def _find_monitor(self, name):
        if not name:
            return None
        mons = Gdk.Display.get_default().get_monitors()
        for i in range(mons.get_n_items()):
            m = mons.get_item(i)
            if m.get_connector() == name:
                return m
        return None

    def open_on(self, monitor_name=None, x=None, y=None):
        if self.layer:
            mon = self._find_monitor(monitor_name)
            if mon is not None:
                LS.set_monitor(self, mon)
            self._place(mon, x, y)
        self.search.set_text("")
        self.reload()
        self._set_hint()
        self.opened_at = time.monotonic()
        self.was_active = False
        self.rev.set_reveal_child(False)
        self.present()
        GLib.idle_add(lambda: (self.rev.set_reveal_child(True), self.search.grab_focus(), False)[2])

    def toggle(self, monitor_name=None, x=None, y=None):
        if self.get_visible():
            self.close_menu()
        else:
            self.open_on(monitor_name, x, y)

    def _place(self, mon, x, y):
        """Panel an die Maus setzen (wie Windows Win+V), am Bildschirmrand begrenzt.
        Ohne Mausposition: Mitte des Monitors."""
        if x is None or y is None or mon is None:
            self.rev.set_halign(Gtk.Align.CENTER)
            self.rev.set_valign(Gtk.Align.CENTER)
            self.rev.set_margin_start(0)
            self.rev.set_margin_top(0)
            return
        geo = mon.get_geometry()
        pad = 12
        left = int(min(max(pad, x - PANEL_W // 2), geo.width - PANEL_W - pad))
        top = int(min(max(pad + 46, y - 20), geo.height - PANEL_H - pad))   # nicht ueber die Bar
        self.rev.set_halign(Gtk.Align.START)
        self.rev.set_valign(Gtk.Align.START)
        self.rev.set_margin_start(max(0, left))
        self.rev.set_margin_top(max(0, top))

    def close_menu(self):
        if self.screenshot:
            return
        if not self.daemon:
            self.app.quit()
            return
        if not self.get_visible():
            return
        self.rev.set_reveal_child(False)
        GLib.timeout_add(150, lambda: (self.set_visible(False) if not self.rev.get_reveal_child() else None, False)[1])

    # ---------- Ereignisse ----------
    def _on_key(self, ctrl, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            if self.search.get_text():
                self.search.set_text("")
            else:
                self.close_menu()
            return True
        if keyval == Gdk.KEY_Delete:
            if state & Gdk.ModifierType.SHIFT_MASK:
                self._on_wipe()
                return True
            row = self.listbox.get_selected_row()
            if row is not None:
                self._delete(row)
                return True
        if keyval in (Gdk.KEY_Down, Gdk.KEY_Up):
            row = self.listbox.get_selected_row()
            idx = (row.get_index() if row is not None else -1) + (1 if keyval == Gdk.KEY_Down else -1)
            nxt = self.listbox.get_row_at_index(max(0, idx))
            if nxt is not None:
                self.listbox.select_row(nxt)
                nxt.grab_focus()
                GLib.idle_add(self.search.grab_focus)   # weiter tippen koennen
            return True
        return False

    def _on_outside_click(self, gesture, n, x, y):
        ok, b = self.panel.compute_bounds(self)
        if ok and not (b.get_x() <= x <= b.get_x() + b.get_width() and b.get_y() <= y <= b.get_y() + b.get_height()):
            self.close_menu()

    def _on_active(self, *_):
        if self.screenshot or not self.get_visible():
            return
        if self.is_active():
            self.was_active = True
            return
        if self.was_active and time.monotonic() - self.opened_at > 0.3:
            GLib.timeout_add(120, lambda: (self.close_menu() if self.get_visible() and not self.is_active() else None, False)[1])

    def _on_hypr_event(self, name, data):
        if not self.get_visible() or time.monotonic() - self.opened_at < 0.35:
            return
        if name in ("focusedmon", "focusedmonv2", "activewindow", "activewindowv2", "workspace", "workspacev2", "openwindow", "fullscreen", "activespecial"):
            self.close_menu()


class App(Gtk.Application):
    def __init__(self, args):
        super().__init__(application_id="glassy.clipboard", flags=Gio.ApplicationFlags.DEFAULT_FLAGS)
        self.args = args
        self.win = None

    def do_startup(self):
        Gtk.Application.do_startup(self)
        prov = Gtk.CssProvider()
        if hasattr(prov, "load_from_string"):
            prov.load_from_string(_themed(CSS))
        else:
            prov.load_from_data((_themed(CSS)).encode())
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_USER + 10)   # ueber ~/.config/gtk-4.0/gtk.css

    def do_activate(self):
        if self.win is not None:
            self.win.toggle(self.args.monitor)
            return
        self.win = ClipWindow(self, daemon=self.args.daemon, screenshot=bool(self.args.screenshot))
        print(f"[clipboard] layer-shell: {'an' if self.win.layer else 'AUS'}", file=sys.stderr, flush=True)
        if self.args.daemon:
            self.hold()
            self._listen_fifo()
            if self.args.show:
                at = (self.args.at or "").split()
                if len(at) >= 3:
                    try:
                        self.win.open_on(at[0], int(at[1]), int(at[2]))
                    except ValueError:
                        self.win.open_on(at[0])
                else:
                    self.win.open_on(self.args.monitor)
            return
        self.win.reload()
        self.win.present()
        if self.args.screenshot:
            GLib.timeout_add(1200, self._snap)

    def _listen_fifo(self):
        os.makedirs(CACHE, exist_ok=True)
        try:
            import stat
            if os.path.exists(FIFO) and not stat.S_ISFIFO(os.stat(FIFO).st_mode):
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
            x = y = None
            if len(parts) >= 4:
                try:
                    x, y = int(parts[2]), int(parts[3])
                except ValueError:
                    x = y = None
            if cmd == "toggle":
                self.win.toggle(mon, x, y)
            elif cmd == "show":
                self.win.open_on(mon, x, y)
            elif cmd == "hide":
                self.win.close_menu()
            elif cmd == "quit":
                self.quit()
        return True

    def _snap(self):
        w = self.win.panel
        p = Gtk.WidgetPaintable.new(w)
        sn = Gtk.Snapshot()
        p.snapshot(sn, w.get_width(), w.get_height())
        node = sn.to_node()
        if node is not None:
            self.win.get_renderer().render_texture(node, None).save_to_png(self.args.screenshot)
            print("screenshot", self.args.screenshot, flush=True)
        self.quit()
        return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--daemon", action="store_true")
    p.add_argument("--show", action="store_true")
    p.add_argument("--monitor", default=None)
    p.add_argument("--at", default=None, help='"MONITOR X Y" - an dieser Mausposition oeffnen')
    p.add_argument("--screenshot", default=None, help=argparse.SUPPRESS)
    args = p.parse_args()
    os.environ.pop("LD_PRELOAD", None)
    return App(args).run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
