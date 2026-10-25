#!/usr/bin/env python3
# ==================================================================
#  claudes-glassy  -  Panel / Flyouts (Tokyo Night)
#  Eigene Pop-outs der Leiste wie bei Windows 11 - ohne externe Apps:
#    quick      Schnelleinstellungen (WLAN, Bluetooth, Nicht stoeren, Nachtlicht,
#               Flugmodus, Energie, Lautstaerke, Mikrofon, Helligkeit, Musik)
#    sound      Ausgabe/Eingabe + Lautstaerke pro App
#    network    WLAN-Liste, verbinden, trennen, vergessen
#    bluetooth  Geraete suchen, koppeln, verbinden, entfernen
#    calendar   Kalender (Klick auf die Dynamic Island)
#  Laeuft als Dienst; ~/.config/hypr/scripts/panel.sh <seite> klappt auf/zu.
#  Log: ~/.cache/claudes-glassy/panel.log
# ==================================================================
import argparse
import os
import stat
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gdk, Gio, GLib, Gtk  # noqa: E402

LS = None
try:
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk4LayerShell as LS  # noqa: E402
except (ValueError, ImportError):
    LS = None

import views as V  # noqa: E402

HOME = os.path.expanduser("~")
CACHE = os.path.join(HOME, ".cache", "claudes-glassy")
FIFO = os.path.join(CACHE, "panel.fifo")
SCRIPTS = os.path.join(HOME, ".config", "hypr", "scripts")
WIDTH = 380
MARGIN_TOP, MARGIN_SIDE = 54, 14

PANEL_CSS = r"""
window, window.background, window.background:backdrop, window > * {
    background: none; background-color: transparent; background-image: none; box-shadow: none; border: none; }
.gl-panel {
    background-color: alpha(#1a1b26, 0.86);
    background-image: linear-gradient(90deg, alpha(#bb9af7, 0.0), alpha(#7aa2f7, 0.85), alpha(#7dcfff, 0.85), alpha(#bb9af7, 0.0));
    background-size: 100% 2px; background-repeat: no-repeat; background-position: top;
    border: 1px solid alpha(#7aa2f7, 0.20); border-radius: 16px;
    box-shadow: 0 10px 28px alpha(black, 0.42);
    padding: 14px;
}
.gl-top { margin-bottom: 6px; }
.gl-title { font-size: 14px; font-weight: 800; color: #c0caf5; }
.gl-foot { margin-top: 10px; padding-top: 8px; border-top: 1px solid alpha(#565f89, 0.25); }
"""

TITLES = {"quick": "", "sound": "Sound", "network": "", "bluetooth": "", "calendar": ""}


class HyprEvents:
    """Klick auf anderen Monitor / anderes Fenster -> Panel zu."""
    def __init__(self, cb):
        self.cb = cb
        GLib.idle_add(self._connect)

    def _connect(self):
        sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        rt = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
        path = os.path.join(rt, "hypr", sig or "", ".socket2.sock")
        if not sig or not os.path.exists(path):
            return False
        try:
            conn = Gio.SocketClient.new().connect(Gio.UnixSocketAddress.new(path), None)
        except GLib.Error:
            GLib.timeout_add_seconds(5, self._connect)
            return False
        self.conn = conn
        self.stream = Gio.DataInputStream.new(conn.get_input_stream())
        self._read()
        return False

    def _read(self):
        def done(s, res):
            try:
                line, _ = s.read_line_finish_utf8(res)
            except GLib.Error:
                line = None
            if line is None:
                GLib.timeout_add_seconds(2, self._connect)
                return
            self.cb(line.partition(">>")[0])
            self._read()
        self.stream.read_line_async(GLib.PRIORITY_DEFAULT, None, done)


class Panel(Gtk.ApplicationWindow):
    def __init__(self, app, daemon, screenshot=None):
        super().__init__(application=app, title="Panel")
        self.app, self.daemon, self.screenshot = app, daemon, screenshot
        self.page = None
        self.home = "quick"
        self.opened_at = 0.0
        self.was_active = False
        self.layer = False
        self.set_decorated(False)
        self.set_resizable(False)
        if LS is not None and LS.is_supported() and not screenshot:
            self.layer = True
            LS.init_for_window(self)
            LS.set_namespace(self, "glassy-panel")
            LS.set_layer(self, LS.Layer.OVERLAY)
            LS.set_keyboard_mode(self, LS.KeyboardMode.EXCLUSIVE)
            for e in (LS.Edge.TOP, LS.Edge.BOTTOM, LS.Edge.LEFT, LS.Edge.RIGHT):
                LS.set_anchor(self, e, True)
            LS.set_exclusive_zone(self, -1)
        else:
            self.set_default_size(WIDTH + 40, 560)
        print(f"[panel] layer-shell: {'an' if self.layer else 'AUS'}", file=sys.stderr, flush=True)

        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.set_child(root)
        self.panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.panel.add_css_class("gl-panel")
        self.panel.set_size_request(WIDTH, -1)

        top = Gtk.Box(spacing=6)
        top.add_css_class("gl-top")
        self.back = V.iconbtn(V.G["back"], "Zurück", lambda: self.show_page(self.home))
        top.append(self.back)
        self.title = V.label("", "gl-title")
        self.title.set_hexpand(True)
        top.append(self.title)
        self.topbar = top
        self.panel.append(top)

        self.stack = Gtk.Stack()
        self.stack.set_transition_type(Gtk.StackTransitionType.SLIDE_LEFT_RIGHT)
        self.stack.set_transition_duration(160)
        self.stack.set_vhomogeneous(False)
        self.stack.set_interpolate_size(True)
        self.views = {
            "quick": V.QuickView(self.show_page, self.run),
            "sound": V.SoundView(compact=True),
            "network": V.NetworkView(),
            "bluetooth": V.BluetoothView(),
            "calendar": V.CalendarView(),
        }
        for k, v in self.views.items():
            if k in ("sound",):
                sw = Gtk.ScrolledWindow()
                sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
                sw.set_propagate_natural_height(True)
                sw.set_max_content_height(560)
                sw.set_child(v)
                self.stack.add_named(sw, k)
            elif k in ("network", "bluetooth"):
                sw = Gtk.ScrolledWindow()
                sw.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
                sw.set_propagate_natural_height(True)
                sw.set_max_content_height(460)
                sw.set_child(v)
                self.stack.add_named(sw, k)
            else:
                self.stack.add_named(v, k)
        self.panel.append(self.stack)

        foot = Gtk.Box(spacing=4)
        foot.add_css_class("gl-foot")
        foot.append(V.iconbtn(V.G["gear"], "Alle Einstellungen (SUPER+I)", lambda: self.run(os.path.join(SCRIPTS, "settings-app.sh"))))
        sp = Gtk.Box()
        sp.set_hexpand(True)
        foot.append(sp)
        foot.append(V.iconbtn(V.G["lock"], "Sperren", lambda: self.run("pidof hyprlock || hyprlock")))
        foot.append(V.iconbtn(V.G["power"], "Ein/Aus (Strg+Alt+Entf)", lambda: self.run(os.path.join(SCRIPTS, "sessionscreen.sh"))))
        self.foot = foot
        self.panel.append(foot)

        if self.layer:
            self.panel.set_valign(Gtk.Align.START)
            self.panel.set_margin_top(MARGIN_TOP)
            click = Gtk.GestureClick()
            click.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
            click.connect("pressed", self._outside)
            self.add_controller(click)
        root.append(self.panel)

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self._key)
        self.add_controller(keys)
        self.connect("notify::is-active", self._active)
        if daemon:
            self.hypr = HyprEvents(self._hypr)
        self.tick_id = 0

    # ---------- Seiten ----------
    def show_page(self, name):
        if name not in self.views:
            name = "quick"
        self.page = name
        self.stack.set_visible_child_name(name)
        self.title.set_label(TITLES.get(name, ""))
        sub = name != self.home
        self.back.set_visible(sub)
        self.topbar.set_visible(sub or bool(TITLES.get(name)))
        self.foot.set_visible(name in ("quick", "calendar"))
        self.views[name].refresh()

    def _place(self, page, monitor):
        if not self.layer:
            return
        if monitor:
            mons = Gdk.Display.get_default().get_monitors()
            for i in range(mons.get_n_items()):
                m = mons.get_item(i)
                if m.get_connector() == monitor:
                    LS.set_monitor(self, m)
        if page == "calendar":                    # Kalender mittig unter der Island
            self.panel.set_halign(Gtk.Align.CENTER)
            self.panel.set_margin_end(0)
        else:                                     # Rest rechts unter den Leisten-Symbolen
            self.panel.set_halign(Gtk.Align.END)
            self.panel.set_margin_end(MARGIN_SIDE)

    def open(self, page, monitor=None):
        self.home = page
        self._place(page, monitor)
        self.show_page(page)
        self.opened_at = time.monotonic()
        self.was_active = False
        self.present()
        if not self.tick_id:
            self.tick_id = GLib.timeout_add_seconds(3, self._tick)

    def toggle(self, page, monitor=None):
        if self.get_visible() and self.home == page:
            self.close_panel()
        else:
            self.open(page, monitor)

    def _tick(self):
        if not self.get_visible():
            self.tick_id = 0
            return False
        if self.page in ("quick", "sound", "calendar"):      # Lautstaerke/Apps live halten
            self.views[self.page].refresh()
        return True

    def close_panel(self):
        if self.screenshot:
            return
        if self.daemon:
            self.set_visible(False)
        else:
            self.app.quit()

    def run(self, cmd):
        V.B.spawn(["sh", "-c", cmd])
        self.close_panel()

    # ---------- Schliessen bei Klick daneben ----------
    def _outside(self, g, n, x, y):
        ok, b = self.panel.compute_bounds(self)
        if ok and not (b.get_x() <= x <= b.get_x() + b.get_width() and b.get_y() <= y <= b.get_y() + b.get_height()):
            self.close_panel()

    def _key(self, c, kv, kc, st):
        if kv == Gdk.KEY_Escape:
            if self.page != self.home:
                self.show_page(self.home)
            else:
                self.close_panel()
            return True
        return False

    def _active(self, *_):
        if self.screenshot or not self.get_visible():
            return
        if self.is_active():
            self.was_active = True
        elif self.was_active and time.monotonic() - self.opened_at > 0.3:
            GLib.timeout_add(150, lambda: (self.close_panel() if self.get_visible() and not self.is_active() else None, False)[1])

    def _hypr(self, name):
        if self.get_visible() and time.monotonic() - self.opened_at > 0.35 and name in (
                "focusedmon", "focusedmonv2", "activewindow", "activewindowv2", "workspace", "workspacev2", "openwindow"):
            self.close_panel()


class App(Gtk.Application):
    def __init__(self, args):
        super().__init__(application_id="glassy.panel", flags=Gio.ApplicationFlags.DEFAULT_FLAGS)
        self.args = args
        self.win = None

    def do_startup(self):
        Gtk.Application.do_startup(self)
        prov = Gtk.CssProvider()
        css = V.CSS + PANEL_CSS
        if hasattr(prov, "load_from_string"):
            prov.load_from_string(css)
        else:
            prov.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), prov, Gtk.STYLE_PROVIDER_PRIORITY_USER + 10)
        st = Gtk.Settings.get_default()
        if st is not None:
            st.set_property("gtk-application-prefer-dark-theme", True)

    def do_activate(self):
        if self.win is not None:
            self.win.toggle(self.args.page, self.args.monitor)
            return
        self.win = Panel(self, self.args.daemon, self.args.screenshot)
        if self.args.daemon:
            self.hold()
            self._listen()
            if self.args.show:
                self.win.open(self.args.page, self.args.monitor)
            return
        self.win.open(self.args.page)
        if self.args.screenshot:
            GLib.timeout_add(int(self.args.delay * 1000), self._snap)

    def _listen(self):
        os.makedirs(CACHE, exist_ok=True)
        try:
            if os.path.exists(FIFO) and not stat.S_ISFIFO(os.stat(FIFO).st_mode):
                os.remove(FIFO)
            if not os.path.exists(FIFO):
                os.mkfifo(FIFO, 0o600)
        except OSError as e:
            print("FIFO:", e, file=sys.stderr)
            return
        self.fd = os.open(FIFO, os.O_RDWR | os.O_NONBLOCK)
        self.buf = b""
        GLib.unix_fd_add_full(GLib.PRIORITY_DEFAULT, self.fd, GLib.IOCondition.IN, self._fifo)

    def _fifo(self, fd, cond):
        try:
            self.buf += os.read(fd, 4096)
        except BlockingIOError:
            return True
        while b"\n" in self.buf:
            line, self.buf = self.buf.split(b"\n", 1)
            p = line.decode(errors="ignore").split()
            if not p:
                continue
            if p[0] == "quit":
                self.quit()
            elif p[0] == "hide":
                self.win.close_panel()
            elif p[0] in ("toggle", "show"):
                page = p[1] if len(p) > 1 else "quick"
                mon = p[2] if len(p) > 2 else None
                (self.win.toggle if p[0] == "toggle" else self.win.open)(page, mon)
        return True

    def _snap(self):
        w = self.win.panel
        pa = Gtk.WidgetPaintable.new(w)
        sn = Gtk.Snapshot()
        pa.snapshot(sn, w.get_width(), w.get_height())
        node = sn.to_node()
        if node is not None:
            self.win.get_renderer().render_texture(node, None).save_to_png(self.args.screenshot)
            print("snap", self.args.screenshot, w.get_width(), w.get_height(), flush=True)
        self.quit()
        return False


def main():
    p = argparse.ArgumentParser()
    p.add_argument("page", nargs="?", default="quick")
    p.add_argument("--daemon", action="store_true")
    p.add_argument("--show", action="store_true")
    p.add_argument("--monitor", default=None)
    p.add_argument("--screenshot", default=None, help=argparse.SUPPRESS)
    p.add_argument("--delay", type=float, default=2.0, help=argparse.SUPPRESS)
    a = p.parse_args()
    os.environ.pop("LD_PRELOAD", None)
    return App(a).run([sys.argv[0]])


if __name__ == "__main__":
    sys.exit(main())
