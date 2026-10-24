#!/usr/bin/env python3
# ==================================================================
#  claudes-glassy  -  Dynamic Island (Tokyo Night)
#  Schwarze Pille oben in der Mitte, wie beim iPhone:
#    - ruhig:        Uhrzeit
#    - Musik laeuft: Cover + Titel + tanzende Balken
#    - Songwechsel / Maus drueber / Klick: klappt auf mit Cover,
#      Titel, Kuenstler, Fortschritt und Steuerung
#    - Lautstaerke aendern: zeigt kurz einen Balken
#  Laeuft auf allen Monitoren. Start: ~/.config/hypr/scripts/island.sh
#  Log: ~/.cache/claudes-glassy/island.log
# ==================================================================
import hashlib
import os
import sys
import threading
import time
import urllib.request

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
CACHE = os.path.join(HOME, ".cache", "claudes-glassy")
ART_CACHE = os.path.join(CACHE, "covers")
SEP = "␟"   # Trennzeichen fuer playerctl-Ausgabe

MARGIN_TOP = 8           # gleiche Hoehe wie die Waybar-Inseln
SHADOW_PAD = 28          # unsichtbarer Rand ums Fenster, damit der Schatten nicht eckig abgeschnitten wird
COMPACT_H = 38
AUTO_EXPAND_SECS = 4     # bei Songwechsel so lange aufgeklappt

G = {"prev": "", "play": "", "pause": "", "next": "",
     "vol": "", "mute": "", "music": ""}

CSS = r"""
@define-color tn_fg      #c0caf5;
@define-color tn_fg_dark #a9b1d6;
@define-color tn_comment #565f89;
@define-color tn_blue    #7aa2f7;
@define-color tn_cyan    #7dcfff;
@define-color tn_purple  #bb9af7;
@define-color tn_green   #9ece6a;
@define-color tn_red     #f7768e;
@define-color tn_hl      #292e42;

window, window.background, window.background:backdrop, window > *, .frame {
    background: none; background-color: transparent; background-image: none;
    box-shadow: none; border: none; }
* { font-family: "Inter", "JetBrainsMono Nerd Font", sans-serif; }

.island {
    background-color: alpha(#06060a, 0.92);
    border: 1px solid alpha(@tn_blue, 0.16);
    border-radius: 19px;
    box-shadow: 0 4px 14px alpha(black, 0.40);
    color: @tn_fg;
    padding: 0 14px;
    min-height: 36px;
    transition: all 260ms cubic-bezier(.2, .9, .3, 1.15);
}
.island.expanded {
    border-radius: 26px;
    padding: 0 16px;
    border-color: alpha(@tn_purple, 0.30);
    box-shadow: 0 6px 18px alpha(black, 0.50), 0 0 14px alpha(@tn_purple, 0.10);
}

.clock    { font-size: 13px; font-weight: 800; color: @tn_fg; }
.ctitle   { font-size: 11.5px; font-weight: 700; color: @tn_fg; }
.cover    { border-radius: 7px; }
.bigcover { border-radius: 14px; }

/* tanzende Balken */
.bar      { background-color: @tn_green; border-radius: 99px; min-width: 3px; min-height: 4px; }
.bars.paused .bar { background-color: @tn_comment; animation: none; min-height: 4px; }
@keyframes b1 { 0% { min-height: 4px; } 50% { min-height: 14px; } 100% { min-height: 4px; } }
@keyframes b2 { 0% { min-height: 12px; } 50% { min-height: 5px; } 100% { min-height: 12px; } }
@keyframes b3 { 0% { min-height: 7px; } 50% { min-height: 16px; } 100% { min-height: 7px; } }
.bars .b1 { animation: b1 0.9s ease-in-out infinite; }
.bars .b2 { animation: b2 0.7s ease-in-out infinite; }
.bars .b3 { animation: b3 1.1s ease-in-out infinite; }
.bars .b4 { animation: b1 0.8s ease-in-out infinite; }

/* aufgeklappt */
.etitle  { font-size: 14px; font-weight: 800; color: @tn_fg; }
.eartist { font-size: 11.5px; font-weight: 600; color: @tn_fg_dark; }
.eplayer { font-size: 9.5px; font-weight: 800; color: @tn_comment; letter-spacing: 1px; }
.etime   { font-size: 9.5px; color: @tn_comment; font-feature-settings: "tnum"; }

/* Song-Schieberegler (klicken/ziehen = spulen) */
scale.seek { padding: 6px 0; margin: 0; }
scale.seek trough    { min-height: 4px; border-radius: 99px; background-color: alpha(@tn_hl, 0.9); transition: min-height 120ms ease; }
scale.seek highlight { min-height: 4px; border-radius: 99px;
                       background-image: linear-gradient(90deg, @tn_purple, @tn_blue, @tn_cyan); }
scale.seek slider    { min-width: 0; min-height: 0; margin: -6px; padding: 0;
                       background-color: @tn_fg; border: none; box-shadow: none; border-radius: 99px;
                       transition: all 120ms ease; }
scale.seek:hover trough, scale.seek:hover highlight { min-height: 6px; }
scale.seek:hover slider { min-width: 12px; min-height: 12px; margin: -4px; box-shadow: 0 0 8px alpha(@tn_cyan, 0.6); }
progressbar trough   { min-height: 4px; border-radius: 99px; background-color: alpha(@tn_hl, 0.9); }
progressbar progress { min-height: 4px; border-radius: 99px;
                       background-image: linear-gradient(90deg, @tn_purple, @tn_blue, @tn_cyan); }

button.ctl {
    min-width: 30px; min-height: 30px; padding: 0;
    border-radius: 99px; border: none; box-shadow: none;
    background: transparent;
    color: @tn_fg;
    font-family: "JetBrainsMono Nerd Font"; font-size: 13px;
    transition: all 140ms ease;
}
button.ctl:hover { background-color: alpha(@tn_hl, 0.95); color: @tn_cyan; }
button.ctl.main  { min-width: 36px; min-height: 36px; font-size: 15px;
                   background-color: alpha(@tn_fg, 0.92); color: #06060a; }
button.ctl.main:hover { background-color: @tn_cyan; color: #06060a; }

/* Aufnahme */
.recdot  { background-color: #f7768e; border-radius: 99px; min-width: 9px; min-height: 9px;
           animation: recpulse 1.2s ease-in-out infinite; }
@keyframes recpulse { 0% { opacity: 1; } 50% { opacity: 0.25; } 100% { opacity: 1; } }
.rectext { font-size: 11.5px; font-weight: 800; color: #f7768e; letter-spacing: 1px; }
.rectime { font-size: 12px; font-weight: 700; color: @tn_fg; font-feature-settings: "tnum"; }
.rechint { font-size: 9.5px; color: @tn_comment; }

/* Lautstaerke */
.volglyph { font-family: "JetBrainsMono Nerd Font"; font-size: 13px; color: @tn_blue; }
.volpct   { font-size: 11.5px; font-weight: 800; color: @tn_fg; min-width: 34px; }
"""


def fmt_time(us):
    if not us or us < 0:
        return "0:00"
    s = int(us // 1_000_000)
    return f"{s // 60}:{s % 60:02d}"


def run_async(argv, cb=None):
    """Kommando ohne Blockieren ausfuehren; cb(stdout_text) bei Erfolg."""
    try:
        p = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE)
    except GLib.Error:
        return
    if cb is None:
        return

    def done(proc, res):
        try:
            ok, out, _ = proc.communicate_utf8_finish(res)
        except GLib.Error:
            return
        cb(out or "")
    p.communicate_utf8_async(None, None, done)


def have(cmd):
    return GLib.find_program_in_path(cmd) is not None


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


# ------------------------------------------------------------------ Zustand
class State:
    def __init__(self):
        self.status = "Stopped"
        self.player = ""
        self.title = ""
        self.artist = ""
        self.art_url = ""
        self.length = 0
        self.position = 0
        self.art_pixbuf = None
        self.volume = None
        self.muted = False
        self.rec_start = 0

    @property
    def has_media(self):
        return self.status in ("Playing", "Paused") and bool(self.title)


# ------------------------------------------------------------------ Fenster
class IslandWindow(Gtk.ApplicationWindow):
    def __init__(self, app, monitor):
        super().__init__(application=app, title="Island")
        self.app = app
        self.st = app.state
        self.set_decorated(False)
        self.set_resizable(False)
        if LS is not None and LS.is_supported():
            LS.init_for_window(self)
            LS.set_namespace(self, "glassy-island")
            LS.set_layer(self, LS.Layer.TOP)
            LS.set_anchor(self, LS.Edge.TOP, True)
            LS.set_margin(self, LS.Edge.TOP, 0)
            LS.set_exclusive_zone(self, -1)
            LS.set_keyboard_mode(self, LS.KeyboardMode.NONE)
            if monitor is not None:
                LS.set_monitor(self, monitor)

        self.pill = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.pill.add_css_class("island")
        self.pill.set_halign(Gtk.Align.CENTER)
        self.pill.set_valign(Gtk.Align.START)
        # Pille mit Abstand in einen durchsichtigen Rahmen setzen: Platz fuer Schatten + runde Ecken
        self.pill.set_margin_top(MARGIN_TOP)
        self.pill.set_margin_start(SHADOW_PAD)
        self.pill.set_margin_end(SHADOW_PAD)
        self.pill.set_margin_bottom(SHADOW_PAD)
        frame = Gtk.Box()
        frame.add_css_class("frame")
        frame.append(self.pill)
        self.set_child(frame)

        # ---- kompakte Zeile ----
        self.compact = Gtk.Stack()
        self.compact.set_transition_type(Gtk.StackTransitionType.CROSSFADE)
        self.compact.set_transition_duration(180)
        self.compact.set_size_request(-1, 36)
        self.compact.set_vhomogeneous(False)
        self.compact.set_hhomogeneous(False)
        self.compact.set_interpolate_size(True)

        self.clock = Gtk.Label()
        self.clock.add_css_class("clock")
        self.clock.set_size_request(70, -1)
        self.compact.add_named(self.clock, "clock")

        mrow = Gtk.Box(spacing=10)
        mrow.set_valign(Gtk.Align.CENTER)
        self.ccover = Gtk.Image()
        self.ccover.add_css_class("cover")
        self.ccover.set_pixel_size(22)
        mrow.append(self.ccover)
        self.ctitle = Gtk.Label(xalign=0)
        self.ctitle.add_css_class("ctitle")
        self.ctitle.set_ellipsize(Pango.EllipsizeMode.END)
        self.ctitle.set_max_width_chars(22)
        mrow.append(self.ctitle)
        self.bars = self._make_bars()
        mrow.append(self.bars)
        self.compact.add_named(mrow, "media")

        vrow = Gtk.Box(spacing=10)
        vrow.set_valign(Gtk.Align.CENTER)
        self.vglyph = Gtk.Label(label=G["vol"])
        self.vglyph.add_css_class("volglyph")
        vrow.append(self.vglyph)
        self.vbar = Gtk.ProgressBar()
        self.vbar.set_size_request(150, -1)
        self.vbar.set_valign(Gtk.Align.CENTER)
        vrow.append(self.vbar)
        self.vpct = Gtk.Label(xalign=1)
        self.vpct.add_css_class("volpct")
        vrow.append(self.vpct)
        self.compact.add_named(vrow, "volume")

        rrow = Gtk.Box(spacing=8)
        rrow.set_valign(Gtk.Align.CENTER)
        dot = Gtk.Box()
        dot.add_css_class("recdot")
        dot.set_valign(Gtk.Align.CENTER)
        rrow.append(dot)
        rt = Gtk.Label(label="REC")
        rt.add_css_class("rectext")
        rrow.append(rt)
        self.rectime = Gtk.Label(label="0:00")
        self.rectime.add_css_class("rectime")
        rrow.append(self.rectime)
        rh = Gtk.Label(label="Klick = Stopp")
        rh.add_css_class("rechint")
        rrow.append(rh)
        self.compact.add_named(rrow, "rec")

        self.pill.append(self.compact)

        # ---- aufgeklappter Teil ----
        self.rev = Gtk.Revealer()
        self.rev.set_transition_type(Gtk.RevealerTransitionType.SLIDE_DOWN)
        self.rev.set_transition_duration(240)
        self.rev.set_child(self._build_expanded())
        self.rev.set_visible(False)
        # nach dem Zuklappen ganz ausblenden, sonst bleibt die Pille breit
        self.rev.connect("notify::child-revealed",
                         lambda r, _p: r.set_visible(False) if not r.get_reveal_child() else None)
        self.pill.append(self.rev)

        # Maus: drueber = aufklappen, weg = zuklappen, Klick = anpinnen
        motion = Gtk.EventControllerMotion()
        motion.connect("enter", lambda *_: app.hover(True))
        motion.connect("leave", lambda *_: app.hover(False))
        self.pill.add_controller(motion)
        click = Gtk.GestureClick()
        click.connect("released", lambda *_: app.click())
        self.compact.add_controller(click)

    def _make_bars(self):
        box = Gtk.Box(spacing=2)
        box.add_css_class("bars")
        box.set_valign(Gtk.Align.CENTER)
        box.set_size_request(-1, 16)
        for i in range(1, 5):
            b = Gtk.Box()
            b.add_css_class("bar")
            b.add_css_class(f"b{i}")
            b.set_valign(Gtk.Align.CENTER)
            box.append(b)
        return box

    def _build_expanded(self):
        outer = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        outer.set_margin_bottom(14)
        outer.set_margin_top(4)
        outer.set_size_request(360, -1)

        top = Gtk.Box(spacing=12)
        self.bcover = Gtk.Image()
        self.bcover.add_css_class("bigcover")
        self.bcover.set_pixel_size(58)
        top.append(self.bcover)
        txt = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        txt.set_valign(Gtk.Align.CENTER)
        txt.set_hexpand(True)
        self.eplayer = Gtk.Label(xalign=0)
        self.eplayer.add_css_class("eplayer")
        self.etitle = Gtk.Label(xalign=0)
        self.etitle.add_css_class("etitle")
        self.etitle.set_ellipsize(Pango.EllipsizeMode.END)
        self.etitle.set_max_width_chars(28)
        self.eartist = Gtk.Label(xalign=0)
        self.eartist.add_css_class("eartist")
        self.eartist.set_ellipsize(Pango.EllipsizeMode.END)
        self.eartist.set_max_width_chars(32)
        txt.append(self.eplayer)
        txt.append(self.etitle)
        txt.append(self.eartist)
        top.append(txt)
        self.ebars = self._make_bars()
        self.ebars.set_valign(Gtk.Align.START)
        self.ebars.set_margin_top(6)
        top.append(self.ebars)
        outer.append(top)

        prog = Gtk.Box(spacing=8)
        self.tpos = Gtk.Label(label="0:00")
        self.tpos.add_css_class("etime")
        self.pbar = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 1, 1)
        self.pbar.add_css_class("seek")
        self.pbar.set_draw_value(False)
        self.pbar.set_hexpand(True)
        self.pbar.set_valign(Gtk.Align.CENTER)
        self.pbar.set_focusable(False)
        self.pbar.set_tooltip_text("Klicken oder ziehen zum Spulen")
        self.updating = False
        self.pbar.connect("change-value", self._on_seek)
        self.tlen = Gtk.Label(label="0:00")
        self.tlen.add_css_class("etime")
        prog.append(self.tpos)
        prog.append(self.pbar)
        prog.append(self.tlen)
        outer.append(prog)

        ctl = Gtk.Box(spacing=14)
        ctl.set_halign(Gtk.Align.CENTER)
        for key, cmd, main in (("prev", "previous", False), ("play", "play-pause", True), ("next", "next", False)):
            b = Gtk.Button(label=G[key])
            b.add_css_class("ctl")
            if main:
                b.add_css_class("main")
                self.playbtn = b
            b.set_focusable(False)
            b.connect("clicked", lambda _b, c=cmd: self.app.player_cmd(c))
            ctl.append(b)
        outer.append(ctl)
        return outer

    def _on_seek(self, scale, scroll, value):
        if self.updating:
            return False
        self.app.seek_to(value)
        return False

    # ---- Darstellung ----
    def render(self, mode, expanded):
        st = self.st
        self.clock.set_label(time.strftime("%H:%M"))
        playing = st.status == "Playing"
        for bx in (self.bars, self.ebars):
            (bx.remove_css_class if playing else bx.add_css_class)("paused")
        if st.has_media:
            self.ctitle.set_label(st.title)
            self.etitle.set_label(st.title)
            self.eartist.set_label(st.artist or "")
            self.eplayer.set_label((st.player or "").upper())
            self.playbtn.set_label(G["pause"] if playing else G["play"])
            if st.art_pixbuf is not None:
                small = st.art_pixbuf.scale_simple(44, 44, GdkPixbuf.InterpType.BILINEAR)
                big = st.art_pixbuf.scale_simple(116, 116, GdkPixbuf.InterpType.BILINEAR)
                self.ccover.set_from_paintable(Gdk.Texture.new_for_pixbuf(small))
                self.bcover.set_from_paintable(Gdk.Texture.new_for_pixbuf(big))
            else:
                self.ccover.set_from_icon_name("audio-x-generic")
                self.bcover.set_from_icon_name("audio-x-generic")
            self.ccover.set_pixel_size(22)
            self.bcover.set_pixel_size(58)
            if time.monotonic() > self.app.seek_hold_until:   # nicht reinfunken, waehrend gezogen wird
                self.updating = True
                self.pbar.set_range(0, max(1.0, st.length / 1_000_000))
                self.pbar.set_value(max(0.0, st.position / 1_000_000))
                self.updating = False
            self.tpos.set_label(fmt_time(st.position))
            self.tlen.set_label(fmt_time(st.length))
        if st.rec_start:
            secs = max(0, int(time.time() - st.rec_start))
            self.rectime.set_label(f"{secs // 60}:{secs % 60:02d}" if secs < 3600 else f"{secs // 3600}:{secs % 3600 // 60:02d}:{secs % 60:02d}")
        if st.volume is not None:
            self.vbar.set_fraction(min(1.0, st.volume))
            self.vpct.set_label("aus" if st.muted else f"{int(round(st.volume * 100))}%")
            self.vglyph.set_label(G["mute"] if st.muted else G["vol"])
        want = expanded and st.has_media and mode not in ("volume", "rec")
        top = "clock" if want else mode          # aufgeklappt: oben nur die Uhr
        if self.compact.get_visible_child_name() != top:
            self.compact.set_visible_child_name(top)
        if self.rev.get_reveal_child() != want:
            if want:
                self.rev.set_visible(True)
            self.rev.set_reveal_child(want)
        (self.pill.add_css_class if want else self.pill.remove_css_class)("expanded")


# ------------------------------------------------------------------ App
class IslandApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="glassy.island", flags=Gio.ApplicationFlags.DEFAULT_FLAGS)
        self.state = State()
        self.windows = {}
        self.hovering = False
        self.pinned = False
        self.auto_until = 0.0
        self.volume_until = 0.0
        self.collapse_id = 0
        self.seek_hold_until = 0.0
        self.seek_id = 0

    def do_startup(self):
        Gtk.Application.do_startup(self)
        prov = Gtk.CssProvider()
        if hasattr(prov, "load_from_string"):
            prov.load_from_string(CSS)
        else:
            prov.load_from_data(CSS.encode())
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov,
                                                  Gtk.STYLE_PROVIDER_PRIORITY_USER + 10)   # ueber ~/.config/gtk-4.0/gtk.css
        os.makedirs(ART_CACHE, exist_ok=True)

    def do_activate(self):
        if self.windows:
            return
        self.hold()
        print(f"[island] layer-shell: {'an' if (LS is not None and LS.is_supported()) else 'AUS'}",
              file=sys.stderr, flush=True)
        mons = Gdk.Display.get_default().get_monitors()
        mons.connect("items-changed", lambda *_: GLib.idle_add(self._sync_monitors))
        self._sync_monitors()
        self._follow_player()
        self._follow_volume()
        self.hypr = HyprEvents(self._on_hypr_event)
        GLib.timeout_add(1000, self._tick)
        self.refresh()
        snap = os.environ.get("GLASSY_ISLAND_SNAP")     # nur fuer Tests: Bild der Pille speichern
        if snap:
            self.pinned = os.environ.get("GLASSY_ISLAND_PIN") == "1"
            GLib.timeout_add(2500, self._snap, snap)

    def _snap(self, path):
        self.refresh()
        w = next(iter(self.windows.values()))
        pill = w.pill
        p = Gtk.WidgetPaintable.new(w)
        sn = Gtk.Snapshot()
        p.snapshot(sn, w.get_width(), w.get_height())
        node = sn.to_node()
        if node is None:
            print("snap: leer", flush=True)
            self.quit()
            return False
        w.get_renderer().render_texture(node, None).save_to_png(path)
        print("snap", path, pill.get_width(), pill.get_height(), flush=True)
        self.quit()
        return False

    # ---- Monitore ----
    def _sync_monitors(self):
        mons = Gdk.Display.get_default().get_monitors()
        current = [mons.get_item(i) for i in range(mons.get_n_items())]
        for m in list(self.windows):
            if m not in current:
                self.windows.pop(m).destroy()
        for m in current:
            if m not in self.windows:
                w = IslandWindow(self, m)
                self.windows[m] = w
                w.present()
        self.refresh()
        return False

    # ---- Anzeige ----
    def mode(self):
        now = time.monotonic()
        if self.state.rec_start:
            return "rec"
        if now < self.volume_until and self.state.volume is not None:
            return "volume"
        if self.state.has_media:
            return "media"
        return "clock"

    def expanded(self):
        return self.pinned or self.hovering or time.monotonic() < self.auto_until

    def refresh(self):
        m, e = self.mode(), self.expanded()
        for w in self.windows.values():
            w.render(m, e)

    def hover(self, inside):
        self.hovering = inside
        if self.collapse_id:
            GLib.source_remove(self.collapse_id)
            self.collapse_id = 0
        if inside:
            self.collapse_id = GLib.timeout_add(220, self._apply_hover)
        else:
            self.collapse_id = GLib.timeout_add(500, self._apply_hover)

    def _apply_hover(self):
        self.collapse_id = 0
        if self.hovering and self.state.has_media:
            self._poll_position()
        self.refresh()
        return False

    def _on_hypr_event(self, name, data):
        # woanders hingeklickt / Fenster oder Workspace gewechselt -> aufgeklappte Island zu
        if name in ("focusedmon", "focusedmonv2", "activewindow", "activewindowv2", "workspace", "workspacev2", "openwindow", "fullscreen", "activespecial") and (self.pinned or self.auto_until > time.monotonic()):
            self.pinned = False
            self.auto_until = 0.0
            self.refresh()

    def click(self):
        if self.state.rec_start:            # Aufnahme laeuft -> Klick stoppt sie
            run_async([os.path.join(HOME, ".config", "hypr", "scripts", "record.sh"), "stop"])
            self.state.rec_start = 0
            self.refresh()
            return
        # sonst nichts: aufgeklappt wird nur, solange die Maus drueber ist

    def _check_recording(self):
        st = self.state
        try:
            with open(os.path.join(CACHE, "recording.pid")) as f:
                pid = int(f.read().strip())
            os.kill(pid, 0)
            with open(os.path.join(CACHE, "recording.start")) as f:
                st.rec_start = int(f.read().strip())
        except (OSError, ValueError):
            st.rec_start = 0

    def _tick(self):
        st = self.state
        self._check_recording()
        if st.status == "Playing" and st.length:
            st.position = min(st.length, st.position + 1_000_000)
            if int(time.time()) % 5 == 0:
                self._poll_position()
        self.refresh()
        return True

    # ---- Medien (playerctl) ----
    def player_cmd(self, cmd):
        run_async(["playerctl", cmd])
        GLib.timeout_add(350, lambda: (self._poll_position(), False)[1])

    def seek_to(self, seconds):
        """Schieberegler bewegt -> nach kurzer Pause (Ziehen fertig) spulen."""
        st = self.state
        seconds = max(0.0, min(seconds, st.length / 1_000_000 if st.length else seconds))
        st.position = int(seconds * 1_000_000)
        self.seek_hold_until = time.monotonic() + 0.8
        for w in self.windows.values():
            w.tpos.set_label(fmt_time(st.position))
        if self.seek_id:
            GLib.source_remove(self.seek_id)

        def go():
            self.seek_id = 0
            run_async(["playerctl", "position", f"{seconds:.2f}"])
            GLib.timeout_add(400, lambda: (self._poll_position(), False)[1])
            return False
        self.seek_id = GLib.timeout_add(120, go)

    def _poll_position(self):
        if not have("playerctl"):
            return

        def got(out):
            if time.monotonic() < self.seek_hold_until:
                return
            try:
                self.state.position = int(float(out.strip()) * 1_000_000)
            except ValueError:
                return
            self.refresh()
        run_async(["playerctl", "position"], got)

    def _follow_player(self):
        if not have("playerctl"):
            print("[island] playerctl fehlt - Musik-Anzeige aus", file=sys.stderr, flush=True)
            return
        fmt = SEP.join(["{{status}}", "{{playerName}}", "{{title}}", "{{artist}}", "{{mpris:artUrl}}", "{{mpris:length}}"])
        try:
            proc = Gio.Subprocess.new(["playerctl", "--follow", "metadata", "--format", fmt],
                                      Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE)
        except GLib.Error as e:
            print("[island] playerctl:", e, file=sys.stderr)
            return
        self.player_proc = proc
        stream = Gio.DataInputStream.new(proc.get_stdout_pipe())
        self._read_player_line(stream)
        proc.wait_async(None, lambda *_: GLib.timeout_add_seconds(3, lambda: (self._follow_player(), False)[1]))

    def _read_player_line(self, stream):
        def done(s, res):
            try:
                line, _ = s.read_line_finish_utf8(res)
            except GLib.Error:
                return
            if line is None:
                return
            self._on_player_line(line)
            self._read_player_line(s)
        stream.read_line_async(GLib.PRIORITY_DEFAULT, None, done)

    def _on_player_line(self, line):
        parts = line.split(SEP)
        st = self.state
        if len(parts) < 6 or not parts[0]:
            st.status, st.title = "Stopped", ""
            self.pinned = False
            self.refresh()
            return
        status, player, title, artist, art, length = parts[:6]
        changed = title != st.title or artist != st.artist
        st.status, st.player, st.title, st.artist = status, player, title, artist
        try:
            st.length = int(length) if length else 0
        except ValueError:
            st.length = 0
        if changed:
            st.position = 0
            self._poll_position()
            if status == "Playing" and title:
                pass   # kein Auto-Aufklappen mehr - nur bei Hover
                GLib.timeout_add((AUTO_EXPAND_SECS * 1000) + 50, lambda: (self.refresh(), False)[1])
        if art != st.art_url:
            st.art_url = art
            st.art_pixbuf = None
            if art:
                self._load_art(art)
        self.refresh()

    def _load_art(self, url):
        def work():
            path = None
            try:
                if url.startswith("file://"):
                    path = GLib.filename_from_uri(url)[0]
                elif url.startswith(("http://", "https://")):
                    path = os.path.join(ART_CACHE, hashlib.sha1(url.encode()).hexdigest() + ".img")
                    if not os.path.exists(path):
                        req = urllib.request.Request(url, headers={"User-Agent": "claudes-glassy-island"})
                        with urllib.request.urlopen(req, timeout=6) as r, open(path + ".part", "wb") as f:
                            f.write(r.read())
                        os.replace(path + ".part", path)
                if path and os.path.exists(path):
                    pb = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, 160, 160, True)
                    GLib.idle_add(self._set_art, url, pb)
            except Exception as e:  # noqa: BLE001 - Cover ist optional
                print("[island] Cover:", e, file=sys.stderr, flush=True)
        threading.Thread(target=work, daemon=True).start()

    def _set_art(self, url, pb):
        if url == self.state.art_url:
            # quadratisch zuschneiden
            w, h = pb.get_width(), pb.get_height()
            s = min(w, h)
            self.state.art_pixbuf = pb.new_subpixbuf((w - s) // 2, (h - s) // 2, s, s)
            self.refresh()
        return False

    # ---- Lautstaerke (pactl subscribe + wpctl) ----
    def _follow_volume(self):
        if not (have("pactl") and have("wpctl")):
            print("[island] pactl/wpctl fehlt - Lautstaerke-Anzeige aus", file=sys.stderr, flush=True)
            return
        self._read_volume(show=False)
        try:
            proc = Gio.Subprocess.new(["pactl", "subscribe"],
                                      Gio.SubprocessFlags.STDOUT_PIPE | Gio.SubprocessFlags.STDERR_SILENCE)
        except GLib.Error:
            return
        self.vol_proc = proc
        stream = Gio.DataInputStream.new(proc.get_stdout_pipe())
        self.vol_pending = False

        def read(s):
            def done(src, res):
                try:
                    line, _ = src.read_line_finish_utf8(res)
                except GLib.Error:
                    return
                if line is None:
                    return
                if "'change' on sink" in line and not self.vol_pending:
                    self.vol_pending = True
                    GLib.timeout_add(60, self._vol_debounced)
                read(src)
            s.read_line_async(GLib.PRIORITY_DEFAULT, None, done)
        read(stream)
        proc.wait_async(None, lambda *_: GLib.timeout_add_seconds(3, lambda: (self._follow_volume(), False)[1]))

    def _vol_debounced(self):
        self.vol_pending = False
        self._read_volume(show=True)
        return False

    def _read_volume(self, show):
        def got(out):
            # "Volume: 0.45" oder "Volume: 0.45 [MUTED]"
            try:
                parts = out.split()
                vol = float(parts[1])
            except (IndexError, ValueError):
                return
            muted = "MUTED" in out
            st = self.state
            changed = st.volume is None or abs(vol - st.volume) > 0.001 or muted != st.muted
            st.volume, st.muted = vol, muted
            if show and changed:
                self.volume_until = time.monotonic() + 1.6
                GLib.timeout_add(1650, lambda: (self.refresh(), False)[1])
            self.refresh()
        run_async(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], got)


def main():
    os.environ.pop("LD_PRELOAD", None)
    return IslandApp().run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
