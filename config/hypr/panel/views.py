"""claudes-glassy: Ansichten fuer Flyouts und Einstellungen (GTK4, Tokyo Night).

Jede Ansicht ist ein Gtk.Box und kann ueberall eingebaut werden:
  QuickView      Schnelleinstellungen (Kacheln, Regler, Medien)
  SoundView      Ausgabe/Eingabe-Geraete, Lautstaerke pro App
  NetworkView    WLAN an/aus, Netze, verbinden mit Passwort, Ethernet
  BluetoothView  an/aus, suchen, koppeln, verbinden, entfernen, Akku
  CalendarView   Kalender
Alle Systemaufrufe laufen in Threads (backend.py), die Oberflaeche friert nie ein.
"""
import threading
import time

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import GLib, Gtk, Pango  # noqa: E402

import backend as B  # noqa: E402

G = {
    "wifi": "\U000f05a9", "wifi_off": "\U000f05aa", "eth": "\U000f0200", "bt": "\U000f00af", "bt_off": "\U000f00b2",
    "dnd": "\U000f009b", "night": "\U000f0594", "plane": "\U000f001d", "power": "\U000f0425", "leaf": "\U000f032a",
    "bolt": "\U000f140b", "mic": "\U000f036c", "mic_off": "\U000f036d", "vol": "\U000f057e", "vol_off": "\U000f0581",
    "sun": "\U000f00e0", "gear": "\U000f0493", "chev": "\U000f0142", "back": "\U000f0141", "lock": "\U000f033e",
    "prev": "\U000f04ae", "play": "\U000f040a", "pause": "\U000f03e4", "next": "\U000f04ad", "refresh": "\U000f0450",
    "check": "\U000f012c", "trash": "\U000f0a7a", "speaker": "\U000f04c3", "headset": "\U000f02cb",
    "pad": "\U000f0297", "phone": "\U000f011c", "kbd": "\U000f030c", "mouse": "\U000f037d", "secure": "\U000f033e",
    "app": "\U000f075a", "hdmi": "\U000f0379",
}

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
@define-color tn_yellow  #e0af68;
@define-color tn_on_accent #16161e;
@define-color tn_island_bg rgba(6, 6, 10, 0.92);

.gl-view * { font-family: "Inter", "JetBrainsMono Nerd Font", sans-serif; }
.gl-view { color: @tn_fg; }
.gl-glyph { font-family: "JetBrainsMono Nerd Font"; }
.gl-head { font-size: 15px; font-weight: 800; color: @tn_fg; }
.gl-sub  { font-size: 10.5px; color: @tn_comment; }
.gl-section { font-size: 9.5px; font-weight: 800; letter-spacing: 1px; color: @tn_comment; margin: 10px 2px 4px 2px; }
.gl-msg { font-size: 11px; color: @tn_comment; margin: 8px 4px; }
.gl-msg.err { color: @tn_red; }

/* Kacheln (Schnelleinstellungen) */
.gl-tile {
    min-height: 54px; border-radius: 12px; padding: 0;
    background-color: alpha(@tn_hl, 0.55); border: 1px solid alpha(@tn_fg, 0.06);
    color: @tn_fg_dark; transition: all 140ms ease;
}
.gl-tile:hover { background-color: alpha(@tn_hl, 0.95); }
.gl-tile.on { background-color: alpha(@tn_blue, 0.85); color: @tn_on_accent; border-color: alpha(@tn_cyan, 0.6); }
.gl-tile.on:hover { background-color: @tn_blue; }
.gl-tile .t-glyph { font-family: "JetBrainsMono Nerd Font"; font-size: 17px; }
.gl-tile .t-name  { font-size: 11px; font-weight: 700; }
.gl-tile .t-sub   { font-size: 9.5px; opacity: 0.8; }
.gl-tile-main { background: none; border: none; box-shadow: none; padding: 6px 10px; border-radius: 12px; color: inherit; }
.gl-tile-arrow { background: none; border: none; box-shadow: none; min-width: 26px; padding: 0; border-radius: 0 12px 12px 0;
                 border-left: 1px solid alpha(@tn_fg, 0.08); color: inherit; font-family: "JetBrainsMono Nerd Font"; }
.gl-tile-arrow:hover { background-color: alpha(white, 0.08); }

/* Regler-Zeilen */
.gl-slider-row { margin: 4px 0; }
.gl-iconbtn {
    min-width: 32px; min-height: 32px; padding: 0; border-radius: 9px; border: none; box-shadow: none;
    background: transparent; color: @tn_fg_dark; font-family: "JetBrainsMono Nerd Font"; font-size: 15px;
}
.gl-iconbtn:hover { background-color: alpha(@tn_hl, 0.9); color: @tn_cyan; }
.gl-iconbtn.muted { color: @tn_red; }
scale.gl-scale trough { min-height: 5px; border-radius: 99px; background-color: alpha(@tn_hl, 0.95); }
scale.gl-scale highlight { border-radius: 99px; background-image: linear-gradient(90deg, @tn_purple, @tn_blue, @tn_cyan); }
scale.gl-scale slider { min-width: 15px; min-height: 15px; margin: -6px; border-radius: 99px; background-color: @tn_fg;
                        border: none; box-shadow: 0 1px 4px alpha(black, 0.5); }
.gl-pct { font-size: 11px; font-weight: 700; color: @tn_fg_dark; min-width: 36px; font-feature-settings: "tnum"; }

/* Listen (Geraete, Netze, Apps) */
.gl-list { background: transparent; }
.gl-list row { border-radius: 10px; padding: 7px 9px; margin: 1px 0; background: transparent; transition: background 120ms ease; }
.gl-list row:hover { background-color: alpha(@tn_hl, 0.75); }
.gl-list row.active { background-color: alpha(@tn_blue, 0.14); box-shadow: inset 2px 0 0 @tn_blue; }
.gl-rname { font-size: 12px; font-weight: 600; color: @tn_fg; }
.gl-rsub  { font-size: 10px; color: @tn_comment; }
.gl-rglyph { font-family: "JetBrainsMono Nerd Font"; font-size: 15px; color: @tn_fg_dark; min-width: 22px; }
.gl-list row.active .gl-rglyph, .gl-list row.active .gl-rname { color: @tn_blue; }
.gl-bat { font-size: 10px; font-weight: 700; color: @tn_green; }

button.gl-btn {
    min-height: 28px; padding: 0 12px; border-radius: 8px; font-size: 11px; font-weight: 700;
    background-color: alpha(@tn_blue, 0.16); color: @tn_blue; border: 1px solid alpha(@tn_blue, 0.3); box-shadow: none;
}
button.gl-btn:hover { background-color: alpha(@tn_blue, 0.3); }
button.gl-btn.danger { background-color: alpha(@tn_red, 0.1); color: @tn_red; border-color: alpha(@tn_red, 0.3); }
button.gl-btn.flat { background: transparent; border-color: transparent; color: @tn_fg_dark; }
entry.gl-entry {
    min-height: 30px; border-radius: 8px; padding: 0 9px; font-size: 12px;
    background-color: alpha(@tn_bg_dark, 0.9); color: @tn_fg; border: 1px solid alpha(@tn_blue, 0.25); box-shadow: none;
}
switch.gl-switch { background-color: @tn_hl; border: none; }
switch.gl-switch:checked { background-color: @tn_blue; }
switch.gl-switch slider { background-color: @tn_fg; background-image: none; border: none; box-shadow: none; min-width: 18px; min-height: 18px; }
dropdown.gl-drop > button { min-height: 26px; padding: 0 8px; border-radius: 8px; font-size: 11px;
    background-color: alpha(@tn_bg_dark, 0.9); color: @tn_fg_dark; border: 1px solid alpha(@tn_fg, 0.08); box-shadow: none; }

/* Medien */
.gl-media { border-radius: 12px; padding: 8px 10px; background-color: alpha(@tn_hl, 0.45); }
.gl-mtitle { font-size: 12px; font-weight: 700; color: @tn_fg; }
.gl-martist { font-size: 10px; color: @tn_comment; }

/* Kalender */
calendar.gl-cal { background: transparent; border: none; color: @tn_fg; padding: 4px; }
calendar.gl-cal > header { border: none; }
calendar.gl-cal > header button { background: transparent; border: none; box-shadow: none; color: @tn_fg_dark; }
calendar.gl-cal > grid > label.day-name { color: @tn_comment; font-size: 10px; font-weight: 800; }
calendar.gl-cal > grid > label.day-number { border-radius: 99px; padding: 6px; font-size: 12px; }
calendar.gl-cal > grid > label.day-number:selected { background-color: @tn_blue; color: @tn_on_accent; font-weight: 800; }
calendar.gl-cal > grid > label.day-number.other-month { color: alpha(@tn_comment, 0.5); }
calendar.gl-cal > grid > label.today { box-shadow: inset 0 0 0 2px @tn_purple; }
.gl-bigtime { font-size: 30px; font-weight: 300; color: @tn_fg; }
.gl-bigdate { font-size: 12px; font-weight: 600; color: @tn_fg_dark; }
.gl-spinner { color: @tn_blue; }
"""


# ------------------------------------------------------------------ Helfer
def bg(fn, *args, done=None):
    """fn(*args) im Thread ausfuehren, done(result) danach im GTK-Thread."""
    def work():
        try:
            res = fn(*args)
        except Exception as e:  # noqa: BLE001 - nie die Oberflaeche abschiessen
            print("[panel]", fn.__name__, e, flush=True)
            res = None
        if done is not None:
            GLib.idle_add(lambda: (done(res), False)[1])
    threading.Thread(target=work, daemon=True).start()


class Debounce:
    """Regler schicken nicht 100 Befehle pro Sekunde - nur den letzten Wert."""
    def __init__(self, ms, fn):
        self.ms, self.fn, self.id, self.val = ms, fn, 0, None

    def __call__(self, *val):
        self.val = val
        if self.id:
            GLib.source_remove(self.id)
        self.id = GLib.timeout_add(self.ms, self._fire)

    def _fire(self):
        self.id = 0
        bg(self.fn, *self.val)
        return False


def glyph(g, cls="gl-glyph"):
    l = Gtk.Label(label=g)
    l.add_css_class(cls)
    return l


def label(text, cls, xalign=0, ellipsize=True, width=None):
    l = Gtk.Label(label=text, xalign=xalign)
    l.add_css_class(cls)
    if ellipsize:
        l.set_ellipsize(Pango.EllipsizeMode.END)
    if width:
        l.set_max_width_chars(width)
    return l


def section(text):
    return label(text.upper(), "gl-section", ellipsize=False)


def iconbtn(g, tip, cb):
    b = Gtk.Button(label=g)
    b.add_css_class("gl-iconbtn")
    b.set_tooltip_text(tip)
    b.set_focusable(False)
    b.connect("clicked", lambda *_: cb())
    return b


def btn(text, cb, cls=None):
    b = Gtk.Button(label=text)
    b.add_css_class("gl-btn")
    if cls:
        b.add_css_class(cls)
    b.connect("clicked", lambda *_: cb())
    return b


def clear(box):
    while (c := box.get_first_child()) is not None:
        box.remove(c)


class SliderRow(Gtk.Box):
    """[Symbol-Knopf] [------Regler------] [45%]"""
    def __init__(self, icon_on, icon_off, on_change, on_toggle=None, extra=None):
        super().__init__(spacing=6)
        self.add_css_class("gl-slider-row")
        self.icon_on, self.icon_off = icon_on, icon_off
        self.updating = False
        self.dragging_until = 0.0
        self.ibtn = iconbtn(icon_on, "Stumm an/aus", lambda: on_toggle() if on_toggle else None)
        self.append(self.ibtn)
        self.scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        self.scale.add_css_class("gl-scale")
        self.scale.set_draw_value(False)
        self.scale.set_hexpand(True)
        self.scale.set_valign(Gtk.Align.CENTER)
        self.pct = label("0%", "gl-pct", xalign=1, ellipsize=False)
        self.cb = Debounce(70, on_change)
        self.scale.connect("value-changed", self._changed)
        self.append(self.scale)
        self.append(self.pct)
        if extra is not None:
            self.append(extra)

    def _changed(self, sc):
        v = int(sc.get_value())
        self.pct.set_label(f"{v}%")
        if not self.updating:
            self.dragging_until = time.monotonic() + 1.0
            self.cb(v)

    def set(self, value, muted=False):
        if time.monotonic() < self.dragging_until:      # nicht reinfunken, waehrend man zieht
            return
        self.updating = True
        self.scale.set_value(value)
        self.updating = False
        self.pct.set_label(f"{int(value)}%")
        self.ibtn.set_label(self.icon_off if muted else self.icon_on)
        (self.ibtn.add_css_class if muted else self.ibtn.remove_css_class)("muted")


# ------------------------------------------------------------------ Sound
class SoundView(Gtk.Box):
    def __init__(self, compact=False):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.add_css_class("gl-view")
        self.compact = compact
        self.sinks, self.sources, self.apps = [], [], []
        self.append(section("Ausgabe"))
        self.out_slider = SliderRow(G["vol"], G["vol_off"], lambda v: B.set_sink_volume(None, v),
                                    lambda: self._toggle_sink_mute())
        self.append(self.out_slider)
        self.out_list = self._list(self._pick_sink)
        self.append(self.out_list)
        self.append(section("Eingabe"))
        self.in_slider = SliderRow(G["mic"], G["mic_off"], lambda v: B.set_source_volume(None, v),
                                   lambda: self._toggle_source_mute())
        self.append(self.in_slider)
        self.in_list = self._list(self._pick_source)
        self.append(self.in_list)
        self.append(section("Lautstärkemixer"))
        self.app_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.append(self.app_box)
        self.app_rows = {}

    def _list(self, cb):
        lb = Gtk.ListBox()
        lb.add_css_class("gl-list")
        lb.set_selection_mode(Gtk.SelectionMode.NONE)
        lb.connect("row-activated", lambda l, r: cb(r._dev))
        return lb

    def _dev_row(self, d, out=True):
        row = Gtk.ListBoxRow()
        row._dev = d
        if d["default"]:
            row.add_css_class("active")
        b = Gtk.Box(spacing=8)
        n = d["desc"].lower()
        g = G["headset"] if ("bluez" in d["name"] or "headset" in n or "headphone" in n) else (
            G["hdmi"] if "hdmi" in d["name"] else (G["speaker"] if out else G["mic"]))
        b.append(glyph(g, "gl-rglyph"))
        b.append(label(d["desc"], "gl-rname"))
        sp = Gtk.Box()
        sp.set_hexpand(True)
        b.append(sp)
        if d["default"]:
            b.append(glyph(G["check"], "gl-rglyph"))
        row.set_child(b)
        return row

    def refresh(self):
        bg(lambda: (B.sinks(), B.sources(), B.apps()), done=self._fill)

    def _fill(self, res):
        if not res:
            return
        self.sinks, self.sources, self.apps = res
        clear(self.out_list)
        for d in self.sinks:
            self.out_list.append(self._dev_row(d, True))
        clear(self.in_list)
        for d in self.sources:
            self.in_list.append(self._dev_row(d, False))
        ds = next((d for d in self.sinks if d["default"]), None)
        if ds:
            self.out_slider.set(ds["volume"], ds["mute"])
        dso = next((d for d in self.sources if d["default"]), None)
        if dso:
            self.in_slider.set(dso["volume"], dso["mute"])
        self._fill_apps()

    def _fill_apps(self):
        keep = {a["index"] for a in self.apps}
        for idx in list(self.app_rows):
            if idx not in keep:
                self.app_box.remove(self.app_rows.pop(idx))
        if not self.apps and not self.app_box.get_first_child():
            self.app_box.append(label("Gerade spielt keine App Ton ab.", "gl-msg", ellipsize=False))
        elif self.apps:
            c = self.app_box.get_first_child()
            if isinstance(c, Gtk.Label):
                self.app_box.remove(c)
        names = [s["desc"] for s in self.sinks]
        for a in self.apps:
            r = self.app_rows.get(a["index"])
            if r is None:
                r = self._app_row(a, names)
                self.app_rows[a["index"]] = r
                self.app_box.append(r)
            r._slider.set(a["volume"], a["mute"])
            r._title.set_label(a["name"])
            r._a = a
            if r._drop is not None:
                si = next((i for i, s in enumerate(self.sinks) if s["index"] == a["sink"]), -1)
                if si >= 0 and r._drop.get_selected() != si:
                    r._drop_updating = True
                    r._drop.set_selected(si)
                    r._drop_updating = False

    def _app_row(self, a, names):
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        top = Gtk.Box(spacing=6)
        top.append(glyph(G["app"], "gl-rglyph"))
        t = label(a["name"], "gl-rname")
        t.set_hexpand(True)
        top.append(t)
        box._title = t
        box._a = a
        box._drop = None
        if not self.compact and len(names) > 1:
            dd = Gtk.DropDown.new_from_strings(names)
            dd.add_css_class("gl-drop")
            dd.set_tooltip_text("Ausgabegerät für diese App")
            box._drop_updating = False

            def moved(d, _p):
                if box._drop_updating:
                    return
                i = d.get_selected()
                if 0 <= i < len(self.sinks):
                    bg(B.move_app, box._a["index"], self.sinks[i]["name"])
            dd.connect("notify::selected", moved)
            box._drop = dd
            top.append(dd)
        box.append(top)
        sl = SliderRow(G["vol"], G["vol_off"], lambda v: B.set_app_volume(box._a["index"], v),
                       lambda: bg(B.set_app_mute, box._a["index"], not box._a["mute"], done=lambda _: self.refresh()))
        box._slider = sl
        box.append(sl)
        return box

    def _pick_sink(self, d):
        bg(B.set_default_sink, d["name"], done=lambda _: self.refresh())

    def _pick_source(self, d):
        bg(B.set_default_source, d["name"], done=lambda _: self.refresh())

    def _toggle_sink_mute(self):
        ds = next((d for d in self.sinks if d["default"]), None)
        if ds:
            bg(B.set_sink_mute, None, not ds["mute"], done=lambda _: self.refresh())

    def _toggle_source_mute(self):
        ds = next((d for d in self.sources if d["default"]), None)
        if ds:
            bg(B.set_source_mute, None, not ds["mute"], done=lambda _: self.refresh())


# ------------------------------------------------------------------ Netzwerk
class NetworkView(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.add_css_class("gl-view")
        head = Gtk.Box(spacing=8)
        self.head_title = label("Netzwerk", "gl-head")
        head.append(self.head_title)
        sp = Gtk.Box()
        sp.set_hexpand(True)
        head.append(sp)
        self.spinner = Gtk.Spinner()
        self.spinner.add_css_class("gl-spinner")
        head.append(self.spinner)
        self.rescan_btn = iconbtn(G["refresh"], "Neu suchen", lambda: self.refresh(rescan=True))
        head.append(self.rescan_btn)
        self.sw = Gtk.Switch()
        self.sw.add_css_class("gl-switch")
        self.sw.set_valign(Gtk.Align.CENTER)
        self.sw_updating = False
        self.sw.connect("notify::active", self._toggle)
        head.append(self.sw)
        self.append(head)
        # Kabel-Verbindungen: eine Zeile pro Anschluss
        self.eth = Gtk.ListBox()
        self.eth.add_css_class("gl-list")
        self.eth.set_selection_mode(Gtk.SelectionMode.NONE)
        self.append(self.eth)
        self.msg = label("", "gl-msg", ellipsize=False)
        self.msg.set_wrap(True)
        self.msg.set_visible(False)
        self.append(self.msg)
        self.list = Gtk.ListBox()
        self.list.add_css_class("gl-list")
        self.list.set_selection_mode(Gtk.SelectionMode.NONE)
        self.list.connect("row-activated", lambda l, r: self._expand(r))
        self.append(self.list)
        self.open_ssid = None

    def _say(self, text, err=False):
        self.msg.set_label(text)
        self.msg.set_visible(bool(text))
        (self.msg.add_css_class if err else self.msg.remove_css_class)("err")

    def refresh(self, rescan=False):
        if not B.net_available():
            self._say("NetworkManager (nmcli) ist nicht installiert.", True)
            return
        self.spinner.start()
        bg(lambda: (B.wifi_enabled(), B.net_devices(), B.wifi_list(rescan)), done=self._fill)

    def _fill(self, res):
        self.spinner.stop()
        if not res:
            return
        on, devs, nets = res
        self.sw_updating = True
        self.sw.set_active(on)
        self.sw_updating = False
        eth = [d for d in devs if d["type"] == "ethernet"]
        has_wifi = any(d["type"] == "wifi" for d in devs)
        # Verbundene Kabel zuerst; nicht verbundene nur, wenn gar nichts verbunden ist
        conn = [d for d in eth if d["state"].startswith("connected")]
        shown = conn or eth[:1]
        clear(self.eth)
        for d in shown:
            self.eth.append(self._eth_row(d))
        self.eth.set_visible(bool(shown))
        self.head_title.set_label("WLAN" if has_wifi else "Netzwerk")
        self.sw.set_visible(has_wifi)
        self.rescan_btn.set_visible(has_wifi)
        clear(self.list)
        if not has_wifi:
            self._say("" if conn else "Kein WLAN-Adapter und kein Kabel verbunden.")
            return
        if not on:
            self._say("WLAN ist aus.")
            return
        if not self.msg.has_css_class("err"):
            self._say("")
        for n in nets:
            self.list.append(self._row(n))
        if not nets:
            self._say("Keine Netze gefunden.")

    def _eth_row(self, d):
        row = Gtk.ListBoxRow()
        row.set_activatable(False)
        on = d["state"].startswith("connected")
        if on:
            row.add_css_class("active")
        b = Gtk.Box(spacing=8)
        b.append(glyph(G["eth"], "gl-rglyph"))
        tb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        tb.set_hexpand(True)
        tb.append(label(d["connection"] if on and d["connection"] else "Ethernet", "gl-rname"))
        tb.append(label(("Verbunden" if on else "Kabel nicht verbunden") + "  ·  " + d["device"], "gl-rsub"))
        b.append(tb)
        row.set_child(b)
        return row

    def _row(self, n):
        row = Gtk.ListBoxRow()
        row._net = n
        if n["active"]:
            row.add_css_class("active")
        v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        b = Gtk.Box(spacing=8)
        b.append(glyph(G["wifi"], "gl-rglyph"))
        tb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        tb.set_hexpand(True)
        tb.append(label(n["ssid"], "gl-rname"))
        sub = ("Verbunden" if n["active"] else ("Gespeichert" if n["known"] else ("Gesichert" if n["secure"] else "Offen")))
        tb.append(label(f"{sub}  ·  {n['signal']}%", "gl-rsub"))
        b.append(tb)
        if n["secure"]:
            b.append(glyph(G["secure"], "gl-rsub"))
        v.append(b)
        act = Gtk.Box(spacing=6)
        act.set_visible(self.open_ssid == n["ssid"])
        row._act = act
        if n["active"]:
            act.append(btn("Trennen", lambda: self._run(B.wifi_disconnect, "Getrennt")))
        else:
            if n["secure"] and not n["known"]:
                e = Gtk.PasswordEntry()
                e.add_css_class("gl-entry")
                e.set_show_peek_icon(True)
                e.set_hexpand(True)
                e.props.placeholder_text = "Passwort"
                e.connect("activate", lambda *_: self._connect(n["ssid"], e.get_text()))
                act.append(e)
                act.append(btn("Verbinden", lambda: self._connect(n["ssid"], e.get_text())))
            else:
                act.append(btn("Verbinden", lambda: self._connect(n["ssid"], None)))
        if n["known"]:
            act.append(btn("Vergessen", lambda: self._run(lambda: B.wifi_forget(n["ssid"]), "Vergessen"), "danger"))
        v.append(act)
        row.set_child(v)
        return row

    def _expand(self, row):
        self.open_ssid = None if self.open_ssid == row._net["ssid"] else row._net["ssid"]
        r = self.list.get_first_child()
        while r is not None:
            r._act.set_visible(self.open_ssid == r._net["ssid"])
            r = r.get_next_sibling()

    def _connect(self, ssid, pw):
        self._say(f"Verbinde mit {ssid} …")
        self.spinner.start()

        def done(res):
            ok, msg = res if res else (False, "")
            if ok:
                self.open_ssid = None
                self._say("")
            else:
                self._say("Verbinden fehlgeschlagen" + (" - falsches Passwort?" if "ecret" in msg else ": " + msg[:80]), True)
            self.refresh()
        bg(B.wifi_connect, ssid, pw or None, done=done)

    def _run(self, fn, ok_text):
        self.spinner.start()
        bg(fn, done=lambda _: (self._say(""), self.refresh()))

    def _toggle(self, sw, _p):
        if self.sw_updating:
            return
        bg(B.set_wifi, sw.get_active(), done=lambda _: GLib.timeout_add(900, lambda: (self.refresh(), False)[1]))


# ------------------------------------------------------------------ Bluetooth
class BluetoothView(Gtk.Box):
    ICON = {"audio-headset": "headset", "audio-headphones": "headset", "audio-card": "speaker",
            "input-gaming": "pad", "phone": "phone", "input-keyboard": "kbd", "input-mouse": "mouse"}

    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        self.add_css_class("gl-view")
        head = Gtk.Box(spacing=8)
        head.append(label("Bluetooth", "gl-head"))
        sp = Gtk.Box()
        sp.set_hexpand(True)
        head.append(sp)
        self.spinner = Gtk.Spinner()
        head.append(self.spinner)
        self.scan_btn = btn("Suchen", self._scan, "flat")
        head.append(self.scan_btn)
        self.sw = Gtk.Switch()
        self.sw.add_css_class("gl-switch")
        self.sw.set_valign(Gtk.Align.CENTER)
        self.sw_updating = False
        self.sw.connect("notify::active", self._toggle)
        head.append(self.sw)
        self.append(head)
        self.msg = label("", "gl-msg", ellipsize=False)
        self.msg.set_wrap(True)
        self.msg.set_visible(False)
        self.append(self.msg)
        self.list = Gtk.ListBox()
        self.list.add_css_class("gl-list")
        self.list.set_selection_mode(Gtk.SelectionMode.NONE)
        self.list.connect("row-activated", lambda l, r: self._expand(r))
        self.append(self.list)
        self.open_mac = None

    def _say(self, text, err=False):
        self.msg.set_label(text)
        self.msg.set_visible(bool(text))
        (self.msg.add_css_class if err else self.msg.remove_css_class)("err")

    def refresh(self):
        self.spinner.start()
        bg(lambda: (B.bt_available(), B.bt_powered(), B.bt_devices() if B.bt_powered() else []), done=self._fill)

    def _fill(self, res):
        self.spinner.stop()
        if not res:
            return
        avail, on, devs = res
        self.sw_updating = True
        self.sw.set_active(on)
        self.sw_updating = False
        self.sw.set_sensitive(avail)
        self.scan_btn.set_sensitive(avail and on)
        clear(self.list)
        if not avail:
            self._say("Kein Bluetooth-Adapter gefunden (oder bluetooth.service läuft nicht:  sudo systemctl enable --now bluetooth).", True)
            return
        if not on:
            self._say("Bluetooth ist aus.")
            return
        if not self.msg.has_css_class("err"):
            self._say("" if devs else "Keine Geräte. Auf „Suchen“ drücken und das Gerät in den Kopplungsmodus bringen.")
        for d in devs:
            self.list.append(self._row(d))

    def _row(self, d):
        row = Gtk.ListBoxRow()
        row._dev = d
        if d["connected"]:
            row.add_css_class("active")
        v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        b = Gtk.Box(spacing=8)
        b.append(glyph(G.get(self.ICON.get(d["icon"], ""), G["bt"]), "gl-rglyph"))
        tb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        tb.set_hexpand(True)
        tb.append(label(d["name"], "gl-rname"))
        tb.append(label("Verbunden" if d["connected"] else ("Gekoppelt" if d["paired"] else "Neu - zum Koppeln klicken"), "gl-rsub"))
        b.append(tb)
        if d["battery"] is not None:
            b.append(label(f"{d['battery']}%", "gl-bat", ellipsize=False))
        v.append(b)
        act = Gtk.Box(spacing=6)
        act.set_visible(self.open_mac == d["mac"])
        row._act = act
        if d["connected"]:
            act.append(btn("Trennen", lambda: self._do(B.bt_disconnect, d["mac"])))
        else:
            act.append(btn("Verbinden" if d["paired"] else "Koppeln & verbinden", lambda: self._connect(d)))
        if d["paired"]:
            act.append(btn("Entfernen", lambda: self._do(B.bt_remove, d["mac"]), "danger"))
        v.append(act)
        row.set_child(v)
        return row

    def _expand(self, row):
        self.open_mac = None if self.open_mac == row._dev["mac"] else row._dev["mac"]
        r = self.list.get_first_child()
        while r is not None:
            r._act.set_visible(self.open_mac == r._dev["mac"])
            r = r.get_next_sibling()

    def _connect(self, d):
        self._say(f"Verbinde mit {d['name']} …")
        self.spinner.start()

        def done(res):
            ok, msg = res if res else (False, "Fehler")
            self._say("" if ok else f"{d['name']}: {msg}", not ok)
            self.refresh()
        bg(B.bt_connect, d["mac"], done=done)

    def _do(self, fn, mac):
        self.spinner.start()
        bg(fn, mac, done=lambda _: (self._say(""), self.refresh()))

    def _scan(self):
        self._say("Suche 8 Sekunden lang …")
        self.spinner.start()
        self.scan_btn.set_sensitive(False)
        bg(B.bt_scan, 8, done=lambda _: (self._say(""), self.scan_btn.set_sensitive(True), self.refresh()))

    def _toggle(self, sw, _p):
        if self.sw_updating:
            return
        bg(B.bt_set_power, sw.get_active(), done=lambda _: GLib.timeout_add(700, lambda: (self.refresh(), False)[1]))


# ------------------------------------------------------------------ Kalender
class CalendarView(Gtk.Box):
    WD = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]
    MO = ["Jänner", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September",
          "Oktober", "November", "Dezember"]

    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.add_css_class("gl-view")
        self.time = label("", "gl-bigtime", ellipsize=False)
        self.date = label("", "gl-bigdate", ellipsize=False)
        self.append(self.time)
        self.append(self.date)
        self.cal = Gtk.Calendar()
        self.cal.add_css_class("gl-cal")
        self.cal.set_show_week_numbers(True)
        self.append(self.cal)
        h = Gtk.Box()
        h.set_halign(Gtk.Align.END)
        h.append(btn("Heute", self.today, "flat"))
        self.append(h)

    def today(self):
        self.cal.select_day(GLib.DateTime.new_now_local())

    def refresh(self):
        t = time.localtime()
        self.time.set_label(time.strftime("%H:%M", t))
        self.date.set_label(f"{self.WD[t.tm_wday]}, {t.tm_mday}. {self.MO[t.tm_mon - 1]} {t.tm_year}")
        self.today()


# ------------------------------------------------------------------ Schnelleinstellungen
class Tile(Gtk.Box):
    """Kachel: Klick = an/aus, Pfeil = Unterseite."""
    def __init__(self, g, name, on_click, on_arrow=None):
        super().__init__()
        self.add_css_class("gl-tile")
        self.set_hexpand(True)
        main = Gtk.Button()
        main.add_css_class("gl-tile-main")
        main.set_hexpand(True)
        main.set_focusable(False)
        inner = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=1)
        self.g = Gtk.Label(label=g, xalign=0)
        self.g.add_css_class("t-glyph")
        self.n = label(name, "t-name", width=12)
        self.s = label("", "t-sub", width=14)
        inner.append(self.g)
        inner.append(self.n)
        inner.append(self.s)
        main.set_child(inner)
        main.connect("clicked", lambda *_: on_click())
        self.append(main)
        if on_arrow:
            a = Gtk.Button(label=G["chev"])
            a.add_css_class("gl-tile-arrow")
            a.set_focusable(False)
            a.set_tooltip_text("Mehr")
            a.connect("clicked", lambda *_: on_arrow())
            self.append(a)

    def set(self, on, sub="", g=None):
        (self.add_css_class if on else self.remove_css_class)("on")
        self.s.set_label(sub)
        if g:
            self.g.set_label(g)


class QuickView(Gtk.Box):
    def __init__(self, open_page, run_cmd):
        """open_page(name) -> Unterseite zeigen (network/bluetooth/sound); run_cmd(shell) -> starten + Panel zu."""
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.add_css_class("gl-view")
        self.open_page, self.run_cmd = open_page, run_cmd
        self.busy = set()
        self.state = {"net": False, "wifi": False, "devs": [], "plane": False, "bt_avail": False, "bt": False,
                      "bt_conn": [], "dnd": False, "night_avail": False, "night": False, "profiles": [],
                      "profile": "", "sink": None, "source": None, "bright": None, "media": None}
        grid = Gtk.Grid(column_spacing=8, row_spacing=8, column_homogeneous=True)
        self.t_wifi = Tile(G["wifi"], "WLAN", self._wifi, lambda: open_page("network"))
        self.t_bt = Tile(G["bt"], "Bluetooth", self._bt, lambda: open_page("bluetooth"))
        self.t_dnd = Tile(G["dnd"], "Nicht stören", self._dnd)
        self.t_night = Tile(G["night"], "Nachtlicht", self._night)
        self.t_plane = Tile(G["plane"], "Flugmodus", self._plane)
        self.t_power = Tile(G["leaf"], "Energie", self._power)
        tiles = [self.t_wifi, self.t_bt, self.t_dnd, self.t_night, self.t_plane, self.t_power]
        for i, t in enumerate(tiles):
            grid.attach(t, i % 3, i // 3, 1, 1)
        self.append(grid)
        self.vol = SliderRow(G["vol"], G["vol_off"], lambda v: B.set_sink_volume(None, v), self._mute,
                             extra=iconbtn(G["chev"], "Sound-Einstellungen", lambda: open_page("sound")))
        self.append(self.vol)
        self.mic = SliderRow(G["mic"], G["mic_off"], lambda v: B.set_source_volume(None, v), self._mic_mute)
        self.append(self.mic)
        self.bright = SliderRow(G["sun"], G["sun"], lambda v: B.set_brightness(v))
        self.bright.set_visible(False)
        self.append(self.bright)
        self.media = Gtk.Box(spacing=6)
        self.media.add_css_class("gl-media")
        tb = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        tb.set_hexpand(True)
        self.m_title = label("", "gl-mtitle")
        self.m_artist = label("", "gl-martist")
        tb.append(self.m_title)
        tb.append(self.m_artist)
        self.media.append(tb)
        self.m_play = iconbtn(G["play"], "Play/Pause", lambda: self._media("play-pause"))
        self.media.append(iconbtn(G["prev"], "Zurück", lambda: self._media("previous")))
        self.media.append(self.m_play)
        self.media.append(iconbtn(G["next"], "Weiter", lambda: self._media("next")))
        self.media.set_visible(False)
        self.append(self.media)

    def refresh(self):
        # Schnelle Werte (Ton, Musik, Schalter) und langsame (Netz, Bluetooth) getrennt holen:
        # haengt bluetoothctl/nmcli, bleiben Lautstaerke & Co trotzdem sofort richtig.
        def fast():
            return {
                "dnd": B.dnd_on() if B.have("swaync-client") else False,
                "night_avail": B.nightlight_available(), "night": B.nightlight_on(),
                "profiles": B.power_profiles(), "profile": B.power_profile() if B.have("powerprofilesctl") else "",
                "sink": B.default_sink_state(), "source": B.default_source_state(),
                "bright": B.brightness(), "media": B.media(),
            }

        def slow():
            net = B.net_available()
            bt_avail = B.bt_available()
            bt = bt_avail and B.bt_powered()
            return {
                "net": net, "wifi": net and B.wifi_enabled(),
                "devs": B.net_devices() if net else [],
                "plane": B.airplane_on() if net else False,
                "bt_avail": bt_avail, "bt": bt,
                "bt_conn": [d["name"] for d in B.bt_devices() if d["connected"]] if bt else [],
            }
        for key, fn in (("fast", fast), ("slow", slow)):
            if key in self.busy:
                continue
            self.busy.add(key)
            bg(fn, done=lambda st, k=key: self._merge(k, st))

    def _merge(self, key, st):
        self.busy.discard(key)
        if st:
            self.state.update(st)
            self._fill(self.state)

    def _fill(self, st):
        if not st:
            return
        wifi_dev = next((d for d in st["devs"] if d["type"] == "wifi"), None)
        eth = next((d for d in st["devs"] if d["type"] == "ethernet" and d["state"].startswith("connected")), None)
        if wifi_dev:
            conn = wifi_dev["connection"] if wifi_dev["state"] == "connected" else ("Ein" if st["wifi"] else "Aus")
            self.t_wifi.n.set_label("WLAN")
            self.t_wifi.set(st["wifi"], conn, G["wifi"] if st["wifi"] else G["wifi_off"])
        else:
            self.t_wifi.n.set_label("Netzwerk")
            self.t_wifi.set(bool(eth), "Kabel" if eth else "Kein Netz", G["eth"])
        self.t_bt.set(st["bt"], (st["bt_conn"][0] if st["bt_conn"] else ("Ein" if st["bt"] else "Aus")) if st["bt_avail"] else "Kein Adapter",
                      G["bt"] if st["bt"] else G["bt_off"])
        self.t_dnd.set(st["dnd"], "Ein" if st["dnd"] else "Aus")
        self.t_night.set(st["night"], ("Ein" if st["night"] else "Aus") if st["night_avail"] else "hyprsunset fehlt")
        self.t_plane.set(st["plane"], "Ein" if st["plane"] else "Aus")
        prof = st["profile"]
        self.t_power.set(prof == "performance", B.PROFILE_LABEL.get(prof, "nicht verfügbar"),
                         {"power-saver": G["leaf"], "performance": G["bolt"]}.get(prof, G["power"]))
        if st["sink"]:
            self.vol.set(st["sink"]["volume"], st["sink"]["mute"])
        self.mic.set_visible(st["source"] is not None)
        if st["source"]:
            self.mic.set(st["source"]["volume"], st["source"]["mute"])
        self.bright.set_visible(st["bright"] is not None)
        if st["bright"] is not None:
            self.bright.set(st["bright"])
        m = st["media"]
        self.media.set_visible(m is not None)
        if m:
            self.m_title.set_label(m["title"])
            self.m_artist.set_label(m["artist"])
            self.m_play.set_label(G["pause"] if m["status"] == "Playing" else G["play"])

    def _after(self, delay=500):
        GLib.timeout_add(delay, lambda: (self.refresh(), False)[1])

    def _wifi(self):
        if not self.state.get("net"):
            return
        bg(B.set_wifi, not self.state.get("wifi"), done=lambda _: self._after(900))

    def _bt(self):
        if self.state.get("bt_avail"):
            bg(B.bt_set_power, not self.state.get("bt"), done=lambda _: self._after(700))

    def _dnd(self):
        bg(B.set_dnd, not self.state.get("dnd"), done=lambda _: self._after(200))

    def _night(self):
        if self.state.get("night_avail"):
            bg(B.set_nightlight, not self.state.get("night"), done=lambda _: self._after(400))

    def _plane(self):
        bg(B.set_airplane, not self.state.get("plane"), done=lambda _: self._after(1200))

    def _power(self):
        profs = self.state.get("profiles") or []
        if not profs:
            return
        order = [p for p in ("power-saver", "balanced", "performance") if p in profs]
        cur = self.state.get("profile")
        nxt = order[(order.index(cur) + 1) % len(order)] if cur in order else order[0]
        bg(B.set_power_profile, nxt, done=lambda _: self._after(200))

    def _mute(self):
        s = self.state.get("sink")
        if s:
            bg(B.set_sink_mute, None, not s["mute"], done=lambda _: self._after(150))

    def _mic_mute(self):
        s = self.state.get("source")
        if s:
            bg(B.set_source_mute, None, not s["mute"], done=lambda _: self._after(150))

    def _media(self, cmd):
        m = self.state.get("media") or {}
        bg(B.media_cmd, m.get("player"), cmd, done=lambda _: self._after(300))
