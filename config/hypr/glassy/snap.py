#!/usr/bin/env python3
# claudes-glassy (Windows-Look): Fenster an den Bildschirmrand ziehen = andocken, wie bei Windows
#   links/rechts = halbe Seite, Ecken = Viertel, oben = maximieren
#   waehrend des Ziehens zeigt Quickshell eine durchsichtige Vorschau (qs ipc snapPreview)
# Laeuft nur im Windows-Look, nur einmal (Sperrdatei), beendet sich selbst beim Look-Wechsel.
import fcntl, json, os, socket, subprocess, sys, time

RUN = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
SIG = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
SOCK = f"{RUN}/hypr/{SIG}/.socket.sock"
GEN = os.path.expanduser("~/.config/hypr/glassy-generated.lua")
EDGE = 3          # px vom Rand = "am Rand"
CORNER = 120      # px von der Ecke = Viertel statt Haelfte
POLL = 0.04

lock = open(f"{RUN}/glassy-snap-{SIG}.lock", "w")
try:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
except OSError:
    sys.exit(0)   # laeuft schon


def hypr(cmd):
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(0.5)
        s.connect(SOCK)
        s.sendall(cmd.encode())
        data = b""
        while True:
            chunk = s.recv(65536)
            if not chunk:
                break
            data += chunk
        s.close()
        return data.decode(errors="replace")
    except OSError:
        return ""


def hj(cmd):
    try:
        return json.loads(hypr("j/" + cmd))
    except ValueError:
        return None


def platform():
    try:
        with open(GEN) as f:
            for line in f:
                if "platform" in line:
                    return line.split('"')[1]
    except OSError:
        pass
    return "linux"


def qs(*args):
    subprocess.Popen(["qs", "-c", "ii", "ipc", "call", "snapPreview", *map(str, args)],
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def zone_for(cur, mon):
    x, y = cur["x"], cur["y"]
    mx, my = mon["x"], mon["y"]
    mw, mh = mon["width"] / mon.get("scale", 1), mon["height"] / mon.get("scale", 1)
    left, right = x <= mx + EDGE, x >= mx + mw - 1 - EDGE
    top, bottom = y <= my + EDGE, y >= my + mh - 1 - EDGE
    if left and y < my + CORNER: return "topleft"
    if left and y > my + mh - CORNER: return "bottomleft"
    if right and y < my + CORNER: return "topright"
    if right and y > my + mh - CORNER: return "bottomright"
    if top and x < mx + CORNER: return "topleft"
    if top and x > mx + mw - CORNER: return "topright"
    if left: return "left"
    if right: return "right"
    if top: return "up"
    return None


def preview_rect(zone, mon):
    r = mon.get("reserved", [0, 0, 0, 0])   # links, oben, rechts, unten
    x = mon["x"] + r[0]
    y = mon["y"] + r[1]
    w = mon["width"] / mon.get("scale", 1) - r[0] - r[2]
    h = mon["height"] / mon.get("scale", 1) - r[1] - r[3]
    hw, hh = w / 2, h / 2
    return {
        "left": (x, y, hw, h), "right": (x + w - hw, y, hw, h), "up": (x, y, w, h),
        "topleft": (x, y, hw, hh), "topright": (x + w - hw, y, hw, hh),
        "bottomleft": (x, y + h - hh, hw, hh), "bottomright": (x + w - hw, y + h - hh, hw, hh),
    }[zone]


def monitor_at(cur, mons):
    for m in mons:
        w, h = m["width"] / m.get("scale", 1), m["height"] / m.get("scale", 1)
        if m["x"] <= cur["x"] < m["x"] + w and m["y"] <= cur["y"] < m["y"] + h:
            return m
    return None


last = None          # (addr, at, size, cursor-offset)
moving_since = 0
still_since = 0
zone = None
shown = None
unsnapped = set()
check = 0

while True:
    time.sleep(POLL)
    check += 1
    if check % 50 == 0 and platform() != "windows":
        if shown: qs("hide")
        sys.exit(0)

    win = hj("activewindow")
    cur = hj("cursorpos")
    if not win or not cur or not win.get("floating") or win.get("fullscreen"):
        last = None
        continue
    addr, at, size = win["address"], tuple(win["at"]), tuple(win["size"])
    off = (cur["x"] - at[0], cur["y"] - at[1])
    now = time.time()

    if last and last[0] == addr and last[2] == size and at != last[1] and off == last[3]:
        # Fenster wandert mit der Maus mit -> wird gezogen
        if not moving_since:
            moving_since = now
            if addr not in unsnapped:
                hypr('/eval glassy_win_key("unsnap")')
                unsnapped.add(addr)
        still_since = 0
        mons = hj("monitors") or []
        mon = monitor_at(cur, mons)
        zone = zone_for(cur, mon) if mon else None
        if zone and shown != (zone, mon["name"]):
            qs("show", *[int(v) for v in preview_rect(zone, mon)])
            shown = (zone, mon["name"])
        elif not zone and shown:
            qs("hide")
            shown = None
    elif moving_since and last and last[0] == addr and at == last[1]:
        # steht still: kurz warten, dann gilt das Ziehen als beendet
        if not still_since:
            still_since = now
        elif now - still_since > 0.18:
            if zone:
                hypr(f'/eval glassy_win_key("{zone}")')
            if shown:
                qs("hide")
                shown = None
            moving_since = 0
            still_since = 0
            zone = None
            unsnapped.discard(addr)
    last = (addr, at, size, off)
