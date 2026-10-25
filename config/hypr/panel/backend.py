"""claudes-glassy: System-Backend fuer Panel-Flyouts und Einstellungen.

Alles laeuft ueber die normalen Kommandozeilen-Tools, die auf Arch sowieso da sind:
  Audio      pactl (pipewire-pulse)       Netzwerk  nmcli (NetworkManager)
  Bluetooth  bluetoothctl (bluez-utils)   Mitteil.  swaync-client
  Nachtlicht hyprsunset                   Energie   powerprofilesctl
  Helligkeit brightnessctl (nur Laptops / Monitore mit Backlight)
Fehlt ein Tool, liefert die Funktion None / [] und die Oberflaeche blendet den Teil aus.
"""
import json
import os
import re
import shutil
import subprocess

ENV = dict(os.environ)
ENV.pop("LD_PRELOAD", None)          # gtk4-layer-shell nicht an Kindprozesse vererben
ENV["LC_ALL"] = "C"                  # englische, parsebare Ausgaben


def have(cmd):
    return shutil.which(cmd) is not None


def run(argv, timeout=6, input_text=None):
    """(ok, stdout) - ok = Exit-Code 0."""
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=timeout, env=ENV, input=input_text)
        return r.returncode == 0, (r.stdout or "") + ("" if r.returncode == 0 else (r.stderr or ""))
    except (OSError, subprocess.SubprocessError) as e:
        return False, str(e)


def spawn(argv):
    """Im Hintergrund starten, nicht warten."""
    try:
        subprocess.Popen(argv, env=ENV, start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except OSError:
        return False


# ------------------------------------------------------------------ Audio
def _vol(obj):
    vals = []
    for ch in (obj.get("volume") or {}).values():
        p = str(ch.get("value_percent", "0%")).rstrip("%")
        try:
            vals.append(int(p))
        except ValueError:
            pass
    return round(sum(vals) / len(vals)) if vals else 0


def _pactl_json(kind):
    if not have("pactl"):
        return []
    ok, out = run(["pactl", "-f", "json", "list", kind])
    if not ok:
        return []
    try:
        return json.loads(out)
    except ValueError:
        return []


def _default(kind):
    ok, out = run(["pactl", f"get-default-{kind}"])
    return out.strip() if ok else ""


def sinks():
    d = _default("sink")
    return [{"name": s.get("name", ""), "desc": s.get("description") or s.get("name", ""),
             "volume": _vol(s), "mute": bool(s.get("mute")), "default": s.get("name") == d,
             "index": s.get("index")}
            for s in _pactl_json("sinks")]


def sources():
    d = _default("source")
    out = []
    for s in _pactl_json("sources"):
        name = s.get("name", "")
        if name.endswith(".monitor") or (s.get("properties") or {}).get("device.class") == "monitor":
            continue
        out.append({"name": name, "desc": s.get("description") or name, "volume": _vol(s),
                    "mute": bool(s.get("mute")), "default": name == d, "index": s.get("index")})
    return out


def apps():
    """Programme, die gerade Ton ausgeben (Lautstaerkemixer)."""
    res = []
    for s in _pactl_json("sink-inputs"):
        p = s.get("properties") or {}
        if p.get("media.role") == "event":          # Systemklaenge ausblenden
            continue
        binary = p.get("application.process.binary") or ""
        name = p.get("application.name") or binary or "Unbekannt"
        if binary and name in ("WEBRTC VoiceEngine", "Chromium", "AudioStream", "ALSA plug-in [java]", "PulseAudio Volume Control"):
            name = {"vesktop": "Discord", "discord": "Discord", "java": "Minecraft"}.get(binary.lower(), binary.capitalize())
        res.append({"index": s.get("index"), "name": name, "title": p.get("media.name", ""),
                    "icon": p.get("application.icon_name") or (p.get("application.process.binary") or "").lower(),
                    "volume": _vol(s), "mute": bool(s.get("mute")), "sink": s.get("sink")})
    return res


def set_default_sink(name):
    return run(["pactl", "set-default-sink", name])[0]


def set_default_source(name):
    return run(["pactl", "set-default-source", name])[0]


def set_sink_volume(name, pct):
    return run(["pactl", "set-sink-volume", name or "@DEFAULT_SINK@", f"{int(max(0, min(100, pct)))}%"])[0]


def set_sink_mute(name, mute):
    return run(["pactl", "set-sink-mute", name or "@DEFAULT_SINK@", "1" if mute else "0"])[0]


def set_source_volume(name, pct):
    return run(["pactl", "set-source-volume", name or "@DEFAULT_SOURCE@", f"{int(max(0, min(100, pct)))}%"])[0]


def set_source_mute(name, mute):
    return run(["pactl", "set-source-mute", name or "@DEFAULT_SOURCE@", "1" if mute else "0"])[0]


def set_app_volume(index, pct):
    return run(["pactl", "set-sink-input-volume", str(index), f"{int(max(0, min(100, pct)))}%"])[0]


def set_app_mute(index, mute):
    return run(["pactl", "set-sink-input-mute", str(index), "1" if mute else "0"])[0]


def move_app(index, sink_name):
    return run(["pactl", "move-sink-input", str(index), sink_name])[0]


def default_sink_state():
    for s in sinks():
        if s["default"]:
            return s
    return None


def default_source_state():
    for s in sources():
        if s["default"]:
            return s
    return None


# ------------------------------------------------------------------ Netzwerk
def _split_t(line):
    """nmcli -t trennt mit ':' und maskiert ':' im Inhalt als '\\:'."""
    out, cur, i = [], "", 0
    while i < len(line):
        c = line[i]
        if c == "\\" and i + 1 < len(line):
            cur += line[i + 1]
            i += 2
            continue
        if c == ":":
            out.append(cur)
            cur = ""
        else:
            cur += c
        i += 1
    out.append(cur)
    return out


def net_available():
    return have("nmcli")


def wifi_enabled():
    ok, out = run(["nmcli", "radio", "wifi"])
    return ok and out.strip() == "enabled"


def set_wifi(on):
    return run(["nmcli", "radio", "wifi", "on" if on else "off"])[0]


def net_devices():
    ok, out = run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"])
    res = []
    if not ok:
        return res
    for line in out.splitlines():
        f = _split_t(line)
        if len(f) >= 4 and f[1] in ("wifi", "ethernet"):
            res.append({"device": f[0], "type": f[1], "state": f[2], "connection": f[3]})
    return res


def has_wifi_device():
    return any(d["type"] == "wifi" for d in net_devices())


def wifi_list(rescan=False):
    ok, out = run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list",
                   "--rescan", "yes" if rescan else "auto"], timeout=20)
    if not ok:
        return []
    known = set(known_wifi())
    best = {}
    for line in out.splitlines():
        f = _split_t(line)
        if len(f) < 4 or not f[1]:
            continue
        try:
            sig = int(f[2])
        except ValueError:
            sig = 0
        e = {"ssid": f[1], "signal": sig, "secure": bool(f[3]) and f[3] != "--", "security": f[3],
             "active": f[0].strip() == "*", "known": f[1] in known}
        old = best.get(f[1])
        if old is None or e["active"] or (sig > old["signal"] and not old["active"]):
            best[f[1]] = e
    return sorted(best.values(), key=lambda e: (not e["active"], not e["known"], -e["signal"]))


def known_wifi():
    ok, out = run(["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"])
    if not ok:
        return []
    return [f[0] for f in (_split_t(l) for l in out.splitlines()) if len(f) >= 2 and f[1] == "802-11-wireless"]


def wifi_connect(ssid, password=None):
    if ssid in known_wifi() and not password:
        ok, out = run(["nmcli", "connection", "up", "id", ssid], timeout=40)
    else:
        argv = ["nmcli", "device", "wifi", "connect", ssid]
        if password:
            argv += ["password", password]
        ok, out = run(argv, timeout=40)
    return ok, out.strip().splitlines()[-1] if out.strip() else ""


def wifi_disconnect():
    for d in net_devices():
        if d["type"] == "wifi" and d["state"] == "connected":
            return run(["nmcli", "device", "disconnect", d["device"]])[0]
    return False


def wifi_forget(ssid):
    return run(["nmcli", "connection", "delete", "id", ssid])[0]


def airplane_on():
    ok, out = run(["nmcli", "radio", "all"])
    # Ausgabe: "WIFI-HW  WIFI     WWAN-HW  WWAN\nenabled  disabled ..."
    if not ok:
        return False
    rows = out.strip().splitlines()
    if len(rows) < 2:
        return False
    vals = rows[1].split()
    return len(vals) >= 2 and vals[1] == "disabled" and not bt_powered()


def set_airplane(on):
    run(["nmcli", "radio", "all", "off" if on else "on"])
    if bt_available():
        bt_set_power(not on)
    return True


# ------------------------------------------------------------------ Bluetooth
_BT_DEAD_UNTIL = [0.0]


def bt_available():
    """Ohne laufenden bluetoothd haengt bluetoothctl ewig ("Waiting to connect...").
    Dann 60 s lang gar nicht mehr fragen, damit das Panel flott bleibt."""
    import time
    if not have("bluetoothctl") or time.monotonic() < _BT_DEAD_UNTIL[0]:
        return False
    ok, out = run(["bluetoothctl", "show"], timeout=2)
    if not ok or "Controller" not in out:
        _BT_DEAD_UNTIL[0] = time.monotonic() + 60
        return False
    return True


def bt_powered():
    if not have("bluetoothctl"):
        return False
    ok, out = run(["bluetoothctl", "show"], timeout=4)
    return ok and re.search(r"^\s*Powered:\s*yes", out, re.M) is not None


def bt_set_power(on):
    return run(["bluetoothctl", "power", "on" if on else "off"], timeout=8)[0]


def bt_info(mac):
    ok, out = run(["bluetoothctl", "info", mac], timeout=4)
    if not ok:
        return None
    def field(name):
        m = re.search(rf"^\s*{name}:\s*(.+)$", out, re.M)
        return m.group(1).strip() if m else ""
    bat = None
    m = re.search(r"Battery Percentage:\s*\S+\s*\((\d+)\)", out)
    if m:
        bat = int(m.group(1))
    return {"mac": mac, "name": field("Alias") or field("Name") or mac, "icon": field("Icon") or "bluetooth",
            "paired": field("Paired") == "yes", "connected": field("Connected") == "yes",
            "trusted": field("Trusted") == "yes", "battery": bat}


def bt_devices():
    ok, out = run(["bluetoothctl", "devices"], timeout=5)
    if not ok:
        return []
    res = []
    for line in out.splitlines():
        m = re.match(r"^Device\s+([0-9A-F:]{17})\s+(.*)$", line.strip(), re.I)
        if not m:
            continue
        info = bt_info(m.group(1))
        if info:
            if info["name"] == info["mac"] and m.group(2):
                info["name"] = m.group(2)
            res.append(info)
    # verbundene zuerst, dann gekoppelte, dann neue
    return sorted(res, key=lambda d: (not d["connected"], not d["paired"], d["name"].lower()))


def bt_scan(seconds=8):
    return run(["bluetoothctl", "--timeout", str(seconds), "scan", "on"], timeout=seconds + 5)[0]


def bt_connect(mac):
    info = bt_info(mac) or {}
    if not info.get("paired"):
        ok, out = run(["bluetoothctl", "--timeout", "25", "pair", mac], timeout=30)
        if not ok and "AlreadyExists" not in out:
            return False, "Koppeln fehlgeschlagen"
        run(["bluetoothctl", "trust", mac])
    ok, out = run(["bluetoothctl", "--timeout", "20", "connect", mac], timeout=25)
    return ok, ("" if ok else "Verbinden fehlgeschlagen")


def bt_disconnect(mac):
    return run(["bluetoothctl", "disconnect", mac], timeout=10)[0]


def bt_remove(mac):
    return run(["bluetoothctl", "remove", mac], timeout=10)[0]


# ------------------------------------------------------------------ Schnellschalter
def dnd_on():
    ok, out = run(["swaync-client", "-D"], timeout=3)
    return ok and out.strip() == "true"


def set_dnd(on):
    return run(["swaync-client", "-dn" if on else "-df"], timeout=3)[0]


NIGHT_TEMP_FILE = os.path.expanduser("~/.config/hypr/glassy-settings.json")


def night_temp():
    try:
        with open(NIGHT_TEMP_FILE, encoding="utf-8") as f:
            return int(json.load(f).get("night_temp", 4500))
    except (OSError, ValueError, TypeError):
        return 4500


def nightlight_available():
    return have("hyprsunset")


def nightlight_on():
    ok, _ = run(["pgrep", "-x", "hyprsunset"], timeout=2)
    return ok


def set_nightlight(on, temp=None):
    run(["pkill", "-x", "hyprsunset"], timeout=2)
    if on:
        return spawn(["hyprsunset", "-t", str(temp or night_temp())])
    return True


def power_profiles():
    if not have("powerprofilesctl"):
        return []
    ok, out = run(["powerprofilesctl", "list"])
    if not ok:
        return []
    return [m.group(1) for m in re.finditer(r"^\s*\*?\s*([a-z-]+):\s*$", out, re.M)]


def power_profile():
    ok, out = run(["powerprofilesctl", "get"])
    return out.strip() if ok else ""


def set_power_profile(p):
    return run(["powerprofilesctl", "set", p])[0]


PROFILE_LABEL = {"power-saver": "Energiesparen", "balanced": "Ausgeglichen", "performance": "Leistung"}


def brightness():
    """Helligkeit in % oder None (Desktop-Monitore ohne Backlight)."""
    if not have("brightnessctl"):
        return None
    ok, out = run(["brightnessctl", "-m", "-c", "backlight"])
    if not ok or not out.strip():
        return None
    try:
        return int(out.strip().split(",")[3].rstrip("%"))
    except (IndexError, ValueError):
        return None


def set_brightness(pct):
    return run(["brightnessctl", "-c", "backlight", "set", f"{int(max(1, min(100, pct)))}%"])[0]


# ------------------------------------------------------------------ Medien
def media():
    if not have("playerctl"):
        return None
    ok, out = run(["playerctl", "metadata", "--format", "{{status}}\t{{title}}\t{{artist}}\t{{playerInstance}}"], timeout=3)
    if not ok or not out.strip():
        return None
    f = out.strip().split("\t")
    if len(f) < 4 or not f[1]:
        return None
    return {"status": f[0], "title": f[1], "artist": f[2], "player": f[3]}


def media_cmd(player, cmd):
    return run(["playerctl"] + (["-p", player] if player else []) + [cmd])[0]
