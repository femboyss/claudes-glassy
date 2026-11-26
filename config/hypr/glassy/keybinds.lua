-- claudes-glassy: Tastenkuerzel
-- Doku: https://wiki.hypr.land/Configuring/Basics/Binds/
-- Alle Kuerzel mit Beschreibung siehst du mit SUPER+H (Spickzettel).
-- Beschreibung "Gruppe: Text" -> der Spickzettel sortiert nach Gruppe.
-- Eigene Kuerzel: ~/.config/hypr/custom/keybinds.lua (wird nie ueberschrieben).

local G   = GLASSY
local M   = G.mainMod
local HOME = os.getenv("HOME")
local errors = {}

-- Look (SUPER+I -> Glassy -> Look, or: glassy --platform linux|windows|mac)
--   linux:   tap Super = start menu/search (default)
--   windows: tap Super does nothing, Ctrl+Esc = start menu, Ctrl+Super = overview
--   mac:     tap Super does nothing, Super+Space = search (Spotlight), Ctrl+Up = overview,
--            Super+Shift+3 / +4 = screenshots
local GEN = GLASSY_GEN or {}
local PLATFORM = GEN.platform or "linux"
-- Cheatsheet language follows end-4's language setting (written by glassy_theme.py sync)
local EN = {}
if GEN.lang == "en" then
    local ok, t = pcall(dofile, HOME .. "/.config/hypr/glassy/i18n.lua")
    if ok and type(t) == "table" then EN = t end
end
local function tr(text) return EN[text] or text end

local qs        = "qs -c $qsConfig"
local qsIpc     = qs .. " ipc call"
local qsAlive   = qsIpc .. " TEST_ALIVE"
local qsScripts = HOME .. "/.config/quickshell/$qsConfig/scripts"
local hyprScripts = HOME .. "/.config/hypr/hyprland/scripts"

local sh     = function(cmd) return hl.dsp.exec_cmd(cmd) end
local global = function(name) return hl.dsp.global("quickshell:" .. name) end

-- Jeder Block einzeln abgesichert: ein kaputter Bind stoppt nicht den Rest
local function try(label, fn)
    local ok, err = pcall(fn)
    if not ok then table.insert(errors, label .. ": " .. tostring(err)) end
end
local function bind(keys, action, opts)
    if opts and opts.description then opts.description = tr(opts.description) end
    local ok, err = pcall(hl.bind, keys, action, opts)
    if not ok then table.insert(errors, keys .. ": " .. tostring(err)) end
end

-------------------------------------------------
-- Workspaces (das Wichtigste zuerst)
-------------------------------------------------
try("workspaces 1-10", function()
    -- Tastencodes statt Zeichen: funktioniert mit jedem Tastaturlayout (de/at)
    local codes = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19 }
    for i = 1, 10 do
        local key = "code:" .. codes[i]
        bind(M .. " + " .. key,         hl.dsp.focus({ workspace = i }), i == 1 and { description = "Workspace: Zu Workspace 1-10 (SUPER+1..0)" } or nil)
        bind(M .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = true }), i == 1 and { description = "Fenster: Auf Workspace 1-10 schieben (mitgehen)" } or nil)
        bind(M .. " + ALT + " .. key,   hl.dsp.window.move({ workspace = i, follow = false }), i == 1 and { description = "Fenster: Auf Workspace 1-10 schieben (bleiben)" } or nil)
    end
end)

try("workspace prev/next", function()
    bind("CTRL + " .. M .. " + left",  hl.dsp.focus({ workspace = "r-1" }), { repeating = true, description = "Workspace: Vorheriger" })
    bind("CTRL + " .. M .. " + right", hl.dsp.focus({ workspace = "r+1" }), { repeating = true, description = "Workspace: Naechster" })
    bind("CTRL + " .. M .. " + SHIFT + left",  hl.dsp.window.move({ workspace = "r-1", follow = true }), { description = "Fenster: Auf vorherigen Workspace" })
    bind("CTRL + " .. M .. " + SHIFT + right", hl.dsp.window.move({ workspace = "r+1", follow = true }), { description = "Fenster: Auf naechsten Workspace" })
    -- SUPER+Tab ist jetzt die Uebersicht -> letzter Workspace auf SUPER+^
    bind(M .. " + code:49",            hl.dsp.focus({ workspace = "previous" }), { description = "Workspace: Letzter (SUPER+^)" })
    bind(M .. " + mouse_down",         hl.dsp.focus({ workspace = "e+1" }))
    bind(M .. " + mouse_up",           hl.dsp.focus({ workspace = "e-1" }))
end)

try("scratchpad", function()
    bind(M .. " + S",        hl.dsp.workspace.toggle_special("special"), { description = "Workspace: Scratchpad zeigen" })
    bind(M .. " + CTRL + S", hl.dsp.window.move({ workspace = "special:special", follow = false }), { description = "Fenster: In den Scratchpad" })
end)

-------------------------------------------------
-- Monitore
-------------------------------------------------
try("monitor by key", function()
    for i, mon in ipairs(G.monitors) do
        bind(M .. " + F" .. i,         hl.dsp.focus({ monitor = mon }), i == 1 and { description = "Monitor: Zu Monitor F1/F2/F3 (Mitte/links/rechts)" } or nil)
        bind(M .. " + SHIFT + F" .. i, hl.dsp.window.move({ monitor = mon, follow = true }), i == 1 and { description = "Fenster: Auf Monitor F1/F2/F3" } or nil)
    end
end)
try("monitor next/prev", function()
    bind(M .. " + period",         hl.dsp.focus({ monitor = "+1" }), { description = "Monitor: Naechster (SUPER+.)" })
    bind(M .. " + comma",          hl.dsp.focus({ monitor = "-1" }), { description = "Monitor: Vorheriger (SUPER+,)" })
    bind(M .. " + SHIFT + period", hl.dsp.window.move({ monitor = "+1", follow = true }), { description = "Fenster: Auf naechsten Monitor" })
    bind(M .. " + SHIFT + comma",  hl.dsp.window.move({ monitor = "-1", follow = true }), { description = "Fenster: Auf vorherigen Monitor" })
end)

-------------------------------------------------
-- Shell (Quickshell / illogical-impulse)
-------------------------------------------------
try("shell", function()
    local search = sh(qsIpc .. " search toggle || pkill fuzzel || fuzzel")
    local overview = global("overviewWorkspacesToggle")
    if PLATFORM == "windows" then
        -- Super alleine macht nichts; Strg+Esc = Start (wie bei Windows), Strg+Super = Uebersicht
        bind("CTRL + Escape", search, { description = "Shell: Startmenue / Suche (Strg+Esc)" })
        bind("CTRL + " .. M .. " + SUPER_L", overview, { release = true, description = "Shell: Uebersicht (Strg+Super)" })
        bind("CTRL + " .. M .. " + SUPER_R", overview, { release = true })
        bind(M .. " + CTRL + Control_L", overview, { release = true })
        bind(M .. " + CTRL + Control_R", overview, { release = true })
    elseif PLATFORM == "mac" then
        -- Super (= Cmd) alleine macht nichts; Cmd+Space = Spotlight, Strg+Pfeil hoch = Mission Control
        bind("CTRL + up", overview, { description = "Shell: Uebersicht (Strg+Pfeil hoch, wie Mission Control)" })
    else
        -- Super alleine antippen = Startmenue/Suche (feuert nur, wenn Super ohne andere Taste losgelassen wird)
        bind(M .. " + SUPER_L", search, { release = true, description = "Shell: Startmenue / Suche (Super antippen)" })
        bind(M .. " + SUPER_R", search, { release = true })
    end
    bind(M .. " + Space", search, { description = "Shell: Suche (Apps, Rechner, Befehle, Web)" })
    bind(M .. " + R", search)
    -- Workspace-Nummern einblenden, solange Super gehalten wird
    bind("SUPER_L", global("workspaceNumber"), { ignore_mods = true, transparent = true })
    bind("SUPER_R", global("workspaceNumber"), { ignore_mods = true, transparent = true })
    bind("SUPER_L", global("workspaceNumber"), { ignore_mods = true, transparent = true, release = true })
    bind("SUPER_R", global("workspaceNumber"), { ignore_mods = true, transparent = true, release = true })

    bind(M .. " + Tab", global("overviewWorkspacesToggle"), { description = "Shell: Uebersicht aller Fenster (wie Windows Task View)" })
    bind(M .. " + O",   global("overviewWorkspacesToggle"))
    bind(M .. " + A",   global("sidebarRightToggle"), { description = "Shell: Schnelleinstellungen + Mitteilungen (rechts)" })
    bind(M .. " + N",   global("sidebarRightToggle"), { description = "Shell: Mitteilungen (rechts)" })
    bind(M .. " + K",   global("sidebarLeftToggle"), { description = "Shell: KI-Seitenleiste (links)" })
    bind(M .. " + ALT + K", global("sidebarLeftToggleDetach"), { description = "Shell: KI-Seitenleiste als eigenes Fenster" })
    bind(M .. " + V",   global("overviewClipboardToggle"), { description = "Shell: Zwischenablage" })
    bind(M .. " + SHIFT + E", global("overviewEmojiToggle"), { description = "Shell: Emojis" })
    bind(M .. " + H",   global("cheatsheetToggle"), { description = "Shell: Spickzettel (alle Tastenkuerzel)" })
    bind(M .. " + Slash", global("cheatsheetToggle"))
    bind(M .. " + M",   global("mediaControlsToggle"), { description = "Shell: Mediensteuerung" })
    bind(M .. " + G",   global("overlayToggle"), { description = "Shell: Widget-Overlay (wie Xbox Game Bar)" })
    bind(M .. " + CTRL + K", global("oskToggle"), { description = "Shell: Bildschirmtastatur" })
    bind(M .. " + SHIFT + B", global("barToggle"), { description = "Shell: Leiste ein/aus" })
    bind(M .. " + W",   global("wallpaperSelectorToggle"), { description = "Shell: Wallpaper aussuchen" })
    bind(M .. " + SHIFT + W", global("wallpaperSelectorRandom"), { description = "Shell: Zufaelliges Wallpaper" })
    bind("CTRL + " .. M .. " + T", global("wallpaperSelectorToggle"))
    bind("CTRL + " .. M .. " + SHIFT + D", global("toggleLightDark"), { description = "Shell: Hell/Dunkel (nur Material You)" })
    bind(M .. " + SHIFT + R", sh(HOME .. "/.local/bin/glassy --reload"), { description = "Shell: Neu starten (wenn was haengt)" })
    bind("CTRL + " .. M .. " + R", sh("killall ydotool qs quickshell; " .. qs .. " &"))
    bind(M .. " + I", sh("XDG_CURRENT_DESKTOP=gnome qs -p " .. HOME .. "/.config/quickshell/$qsConfig/settings.qml"),
        { description = "Shell: Einstellungen (Glassy, Leiste, Theme ...)" })
end)

-------------------------------------------------
-- Sitzung
-------------------------------------------------
try("session", function()
    bind("CTRL + ALT + Delete", global("sessionToggle"), { description = "Sitzung: Sperren / Abmelden / Neustart / Aus" })
    bind("CTRL + ALT + Delete", sh(qsAlive .. " || pkill wlogout || wlogout -p layer-shell"))
    bind(M .. " + Escape", global("sessionToggle"))
    bind(M .. " + L", sh("loginctl lock-session"), { description = "Sitzung: Sperren" })
    bind(M .. " + SHIFT + L", sh("systemctl suspend || loginctl suspend"), { locked = true, description = "Sitzung: Standby" })
    bind(M .. " + SHIFT + M", sh("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"),
        { description = "Sitzung: Hyprland beenden" })
    bind("CTRL + SHIFT + Escape", sh(hyprScripts .. "/launch_first_available.sh 'missioncenter' 'gnome-system-monitor' 'plasma-systemmonitor --page-name Processes' 'kitty -1 btop'"),
        { description = "Sitzung: Task-Manager" })
end)

-------------------------------------------------
-- Apps
-------------------------------------------------
try("apps", function()
    bind(M .. " + Return", sh(G.terminal), { description = "App: Terminal" })
    bind("CTRL + ALT + T", sh(G.terminal))
    bind(M .. " + E", sh(G.fileManager), { description = "App: Dateimanager" })
    bind(M .. " + B", sh(G.browser), { description = "App: Browser" })
    bind("CTRL + " .. M .. " + V", sh(hyprScripts .. "/launch_first_available.sh 'pavucontrol-qt' 'pavucontrol'"), { description = "App: Lautstaerke-Mixer" })
end)

-------------------------------------------------
-- Fenster
-------------------------------------------------
try("window", function()
    bind(M .. " + Q", hl.dsp.window.close(), { description = "Fenster: Schliessen" })
    bind(M .. " + SHIFT + ALT + Q", sh("hyprctl kill"), { description = "Fenster: Abschiessen (haengt)" })
    bind(M .. " + T", hl.dsp.window.float({ action = "toggle" }), { description = "Fenster: Schwebend an/aus" })
    bind(M .. " + ALT + Space", hl.dsp.window.float({ action = "toggle" }))
    bind(M .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), { description = "Fenster: Vollbild" })
    bind(M .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), { description = "Fenster: Maximieren" })
    bind(M .. " + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
    bind(M .. " + C", hl.dsp.window.center(), { description = "Fenster: Zentrieren" })
    bind(M .. " + SHIFT + P", hl.dsp.window.pin({ action = "toggle" }), { description = "Fenster: Anheften (auf allen Workspaces)" })
    bind(M .. " + P", hl.dsp.window.pseudo(), { description = "Fenster: Pseudo-Kachel" })
    bind(M .. " + J", hl.dsp.layout("togglesplit"), { description = "Fenster: Teilung drehen" })
    bind("ALT + Tab", hl.dsp.window.cycle_next({ next = true }), { description = "Fenster: Naechstes Fenster" })
    bind("ALT + F4", hl.dsp.window.close())
end)

try("focus/move", function()
    for _, dir in ipairs({ "left", "right", "up", "down" }) do
        bind(M .. " + " .. dir, hl.dsp.focus({ direction = dir }), dir == "left" and { description = "Fenster: Fokus mit SUPER+Pfeilen" } or nil)
        bind(M .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }), dir == "left" and { description = "Fenster: Verschieben mit SUPER+SHIFT+Pfeilen" } or nil)
    end
end)

-- Groesse: Super+Alt+Pfeile (Strg+Super+Pfeile ist Workspace-Wechsel)
try("resize", function()
    bind(M .. " + ALT + left",  hl.dsp.window.resize({ x = -40, y = 0, relative = true }), { repeating = true, description = "Fenster: Groesse mit SUPER+ALT+Pfeilen" })
    bind(M .. " + ALT + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }),  { repeating = true })
    bind(M .. " + ALT + up",    hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
    bind(M .. " + ALT + down",  hl.dsp.window.resize({ x = 0, y = 40, relative = true }),  { repeating = true })
end)
try("mouse", function()
    bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true, description = "Fenster: Ziehen mit SUPER+Linksklick" })
    bind(M .. " + mouse:274", hl.dsp.window.drag(),   { mouse = true })
    bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Fenster: Groesse mit SUPER+Rechtsklick" })
end)

-------------------------------------------------
-- Werkzeuge (Screenshot, Aufnahme, OCR, Farbe ...)
-------------------------------------------------
try("tools", function()
    -- Bereich: Bildschirm friert ein, Auswahl mit Fenster-Erkennung, Bild landet in der Zwischenablage
    local snip = global("regionScreenshot")
    local snipFallback = sh(qsAlive .. " || pidof slurp || hyprshot --freeze --clipboard-only --mode region --silent")
    bind("Print", snip, { description = "Werkzeug: Screenshot Bereich (auch SUPER+SHIFT+S)" })
    bind("Print", snipFallback)
    bind(M .. " + SHIFT + S", snip)
    bind(M .. " + SHIFT + S", snipFallback)
    local grimMon = "grim -o \"$(hyprctl activeworkspace -j | jq -r '.monitor')\""
    local fullShot = sh("mkdir -p \"$(xdg-user-dir PICTURES)/Screenshots\" && f=\"$(xdg-user-dir PICTURES)/Screenshots/Screenshot_$(date '+%Y-%m-%d_%H.%M.%S').png\" && " .. grimMon .. " \"$f\" && wl-copy < \"$f\" && notify-send -a Screenshot -i \"$f\" '" .. tr("Screenshot gespeichert") .. "' \"$f\"")
    bind("SHIFT + Print", fullShot,
        { locked = true, description = "Werkzeug: Screenshot ganzer Monitor (gespeichert + kopiert)" })
    if PLATFORM == "mac" then
        bind(M .. " + SHIFT + 3", fullShot, { description = "Werkzeug: Screenshot ganzer Monitor (wie Cmd+Shift+3)" })
        bind(M .. " + SHIFT + 4", snip, { description = "Werkzeug: Screenshot Bereich (wie Cmd+Shift+4)" })
        bind(M .. " + SHIFT + 4", snipFallback)
    end
    bind(M .. " + SHIFT + A", global("regionSearch"), { description = "Werkzeug: Bereich mit Google Lens suchen" })
    bind(M .. " + SHIFT + X", global("regionOcr"), { description = "Werkzeug: Text aus Bereich erkennen (OCR)" })
    bind(M .. " + SHIFT + T", global("screenTranslate"), { description = "Werkzeug: Bildschirm uebersetzen" })
    bind(M .. " + SHIFT + C", sh("hyprpicker -a"), { description = "Werkzeug: Farbe aufnehmen" })
    -- Aufnahme an/aus (wie Windows)
    bind(M .. " + ALT + R", global("regionRecord"), { locked = true, description = "Werkzeug: Bildschirmaufnahme Bereich an/aus" })
    bind(M .. " + ALT + R", sh(qsAlive .. " || " .. qsScripts .. "/videos/record.sh"), { locked = true })
    bind("CTRL + ALT + R", sh(qsScripts .. "/videos/record.sh --fullscreen"), { locked = true, description = "Werkzeug: Aufnahme ganzer Monitor" })
    bind(M .. " + SHIFT + ALT + R", sh(qsScripts .. "/videos/record.sh --fullscreen --sound"), { locked = true, description = "Werkzeug: Aufnahme mit Ton" })
    -- Zoom
    bind(M .. " + minus", function()
        local z = hl.get_config("cursor:zoom_factor")
        hl.config({ cursor = { zoom_factor = math.max(1.0, z - 0.3) } })
    end, { repeating = true, description = "Werkzeug: Zoom raus (SUPER+-)" })
    bind(M .. " + plus", function()
        local z = hl.get_config("cursor:zoom_factor")
        hl.config({ cursor = { zoom_factor = math.min(3.0, z + 0.3) } })
    end, { repeating = true, description = "Werkzeug: Zoom rein (SUPER++)" })
end)

-------------------------------------------------
-- Medien / Lautstaerke / Helligkeit
-------------------------------------------------
try("media", function()
    bind("XF86AudioRaiseVolume", sh("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
    bind("XF86AudioLowerVolume", sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
    bind("XF86AudioMute",        sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
    bind("XF86AudioMicMute",     sh("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
    bind("XF86AudioNext",        sh("playerctl next"),       { locked = true })
    bind("XF86AudioPrev",        sh("playerctl previous"),   { locked = true })
    bind("XF86AudioPlay",        sh("playerctl play-pause"), { locked = true })
    bind("XF86AudioPause",       sh("playerctl play-pause"), { locked = true })
    bind("XF86MonBrightnessUp",   sh(qsIpc .. " brightness increment || brightnessctl s 5%+"), { locked = true, repeating = true })
    bind("XF86MonBrightnessDown", sh(qsIpc .. " brightness decrement || brightnessctl s 5%-"), { locked = true, repeating = true })
    bind(M .. " + ALT + M", sh("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, description = "Medien: Mikrofon stumm" })
end)

-------------------------------------------------
-- Virtuelle Maschinen (VMware/Windows-VM): alle Kuerzel aus, SUPER+ALT+F1 = zurueck
-------------------------------------------------
try("vm submap", function()
    hl.define_submap("virtual-machine", function()
        hl.bind(M .. " + ALT + F1", function()
            if hl.get_current_submap() == "virtual-machine" then
                hl.dispatch(hl.dsp.exec_cmd("notify-send -a Hyprland '" .. tr("VM-Modus aus") .. "' '" .. tr("Tastenkuerzel wieder an") .. "'"))
                hl.dispatch(hl.dsp.submap("reset"))
            else
                hl.dispatch(hl.dsp.exec_cmd("notify-send -a Hyprland '" .. tr("VM-Modus an") .. "' '" .. tr("Alle Kuerzel aus, SUPER+ALT+F1 = zurueck") .. "'"))
                hl.dispatch(hl.dsp.submap("virtual-machine"))
            end
        end, { submap_universal = true, description = "Sitzung: VM-Modus (alle Kuerzel aus/an)" })
    end)
end)

-- Fehler gesammelt melden
if #errors > 0 then
    glassy_notify("keybinds: " .. table.concat(errors, " | "))
end
