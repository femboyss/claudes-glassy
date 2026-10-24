-- claudes-glassy: Tastenkuerzel
-- Doku: https://wiki.hypr.land/Configuring/Basics/Binds/

local G   = GLASSY
local M   = G.mainMod
local sh  = function(cmd) return hl.dsp.exec_cmd(cmd) end
local errors = {}

-- Jeder Block einzeln abgesichert: ein kaputter Bind stoppt nicht den Rest
local function try(label, fn)
    local ok, err = pcall(fn)
    if not ok then table.insert(errors, label .. ": " .. tostring(err)) end
end

-------------------------------------------------
-- Workspaces (das Wichtigste zuerst)
-------------------------------------------------
try("workspaces 1-10", function()
    for i = 1, 10 do
        local key = tostring(i % 10)          -- 10 -> Taste 0
        hl.bind(M .. " + " .. key,           hl.dsp.focus({ workspace = i }))
        hl.bind(M .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i, follow = true }))
        hl.bind(M .. " + ALT + " .. key,     hl.dsp.window.move({ workspace = i, follow = false }))
    end
end)

-- Wie bei end-4 / KDE: Strg+Super+Pfeile = vorheriger / naechster Workspace
try("workspace prev/next", function()
    hl.bind("CTRL + " .. M .. " + left",  hl.dsp.focus({ workspace = "-1" }), { repeating = true })
    hl.bind("CTRL + " .. M .. " + right", hl.dsp.focus({ workspace = "+1" }), { repeating = true })
    hl.bind("CTRL + " .. M .. " + SHIFT + left",  hl.dsp.window.move({ workspace = "-1", follow = true }))
    hl.bind("CTRL + " .. M .. " + SHIFT + right", hl.dsp.window.move({ workspace = "+1", follow = true }))
    hl.bind(M .. " + Tab",               hl.dsp.focus({ workspace = "previous" }))
    hl.bind(M .. " + mouse_down",        hl.dsp.focus({ workspace = "e+1" }))
    hl.bind(M .. " + mouse_up",          hl.dsp.focus({ workspace = "e-1" }))
end)

try("scratchpad", function()
    hl.bind(M .. " + S",          hl.dsp.workspace.toggle_special("magic"))
    hl.bind(M .. " + CTRL + S",   hl.dsp.window.move({ workspace = "special:magic" }))
end)

-------------------------------------------------
-- Monitore
-- SUPER + F1/F2/F3          = zu Monitor springen
-- SUPER + SHIFT + F1/F2/F3  = Fenster auf Monitor schieben (und mitgehen)
-- SUPER + . / ,             = naechster / vorheriger Monitor
-- SUPER + SHIFT + . / ,     = Fenster auf naechsten / vorherigen Monitor
-------------------------------------------------
local monitors = { "DP-3", "HDMI-A-1", "DP-1" }   -- F1 = Hauptmonitor
try("monitor by key", function()
    for i, mon in ipairs(monitors) do
        hl.bind(M .. " + F" .. i,           hl.dsp.focus({ monitor = mon }))
        hl.bind(M .. " + SHIFT + F" .. i,   hl.dsp.window.move({ monitor = mon, follow = true }))
    end
end)
try("monitor next/prev", function()
    hl.bind(M .. " + period",          hl.dsp.focus({ monitor = "+1" }))
    hl.bind(M .. " + comma",           hl.dsp.focus({ monitor = "-1" }))
    hl.bind(M .. " + SHIFT + period",  hl.dsp.window.move({ monitor = "+1", follow = true }))
    hl.bind(M .. " + SHIFT + comma",   hl.dsp.window.move({ monitor = "-1", follow = true }))
end)

-------------------------------------------------
-- Fenster-Umschalter
-- ALT + Tab        = zum naechsten Fenster
-- SUPER + O      = Liste aller offenen Fenster (alle Workspaces/Monitore)
-------------------------------------------------
try("window switcher", function()
    hl.bind("ALT + Tab",   hl.dsp.window.cycle_next({ next = true }))
    hl.bind(M .. " + O",   sh("pkill -x rofi || rofi -show window"))
end)

-------------------------------------------------
-- Super alleine antippen = Startmenue (wie Windows)
-- Feuert nur, wenn Super ohne andere Taste losgelassen wird.
-------------------------------------------------
try("super tap", function()
    hl.bind(M .. " + SUPER_L", sh(G.startmenu), { release = true })
end)

-------------------------------------------------
-- Apps
-------------------------------------------------
try("apps", function()
    hl.bind(M .. " + Return", sh(G.terminal))
    hl.bind(M .. " + Space",  sh(G.search))       -- Suche
    hl.bind(M .. " + R",      sh(G.search))
    hl.bind(M .. " + A",      sh(G.startmenu))    -- Startmenue (falls Super-Tap mal nicht will)
    hl.bind(M .. " + E",      sh(G.fileManager))
    hl.bind(M .. " + B",      sh(G.browser))
end)

-------------------------------------------------
-- Fenster
-------------------------------------------------
try("close", function() hl.bind(M .. " + Q", hl.dsp.window.close()) end)
try("float", function() hl.bind(M .. " + T", hl.dsp.window.float({ action = "toggle" })) end)
try("fullscreen", function()
    hl.bind(M .. " + F",         hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
    hl.bind(M .. " + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }))
end)
try("center", function() hl.bind(M .. " + C", hl.dsp.window.center()) end)
try("pin",    function() hl.bind(M .. " + SHIFT + P", hl.dsp.window.pin({ action = "toggle" })) end)
try("pseudo", function() hl.bind(M .. " + P", hl.dsp.window.pseudo()) end)
try("split",  function() hl.bind(M .. " + J", hl.dsp.layout("togglesplit")) end)

try("focus", function()
    for _, dir in ipairs({ "left", "right", "up", "down" }) do
        hl.bind(M .. " + " .. dir, hl.dsp.focus({ direction = dir }))
    end
end)
try("move window", function()
    for _, dir in ipairs({ "left", "right", "up", "down" }) do
        hl.bind(M .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
    end
end)
-- Groesse: Super+Alt+Pfeile (Strg+Super+Pfeile ist jetzt Workspace-Wechsel)
try("resize", function()
    hl.bind(M .. " + ALT + left",  hl.dsp.window.resize({ x = -40, y = 0, relative = true }),  { repeating = true })
    hl.bind(M .. " + ALT + right", hl.dsp.window.resize({ x = 40, y = 0, relative = true }),  { repeating = true })
    hl.bind(M .. " + ALT + up",    hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
    hl.bind(M .. " + ALT + down",  hl.dsp.window.resize({ x = 0, y = 40, relative = true }),  { repeating = true })
end)
try("mouse", function()
    hl.bind(M .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
    hl.bind(M .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
end)

-------------------------------------------------
-- Tools
-------------------------------------------------
try("tools", function()
    local S = G.scripts
    hl.bind(M .. " + L",          sh("pidof hyprlock || hyprlock"))
    hl.bind(M .. " + V",          sh(S .. "/clipboard.sh"))
    hl.bind(M .. " + N",          sh("swaync-client -t -sw"))
    hl.bind(M .. " + I",          sh(S .. "/settings-app.sh"))         -- Einstellungen (wie Windows)
    hl.bind(M .. " + Escape",     sh(S .. "/powermenu.sh"))
    hl.bind(M .. " + W",          sh(S .. "/wallpaper.sh pick"))
    hl.bind(M .. " + SHIFT + W",  sh(S .. "/wallpaper.sh next"))
    hl.bind(M .. " + SHIFT + B",  sh("pkill -SIGUSR1 waybar"))
    hl.bind(M .. " + SHIFT + R",  sh("pkill -x waybar; setsid -f waybar; " .. S .. "/island.sh restart"))
    hl.bind(M .. " + SHIFT + C",  sh("hyprpicker -a"))
    hl.bind("Print",              sh(S .. "/screenshot.sh area"))
    hl.bind("SHIFT + Print",      sh(S .. "/screenshot.sh full"))
    hl.bind(M .. " + SHIFT + S",  sh(S .. "/screenshot.sh area"))     -- wie bei Windows
    hl.bind(M .. " + ALT + R",    sh(S .. "/record.sh"))               -- Bildschirmaufnahme an/aus (wie Windows)
    hl.bind(M .. " + SHIFT + M",  sh("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))
end)

-- Strg+Alt+Entf: Vollbild-Menue mit allen Optionen
try("ctrl alt del", function()
    hl.bind("CTRL + ALT + Delete",        sh(G.scripts .. "/sessionscreen.sh"))
    hl.bind("CTRL + SHIFT + Escape",      sh(G.scripts .. "/taskmanager.sh"))
end)

-------------------------------------------------
-- Medien
-------------------------------------------------
try("media", function()
    hl.bind("XF86AudioRaiseVolume", sh("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
    hl.bind("XF86AudioLowerVolume", sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
    hl.bind("XF86AudioMute",        sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
    hl.bind("XF86AudioMicMute",     sh("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
    hl.bind("XF86AudioNext",        sh("playerctl next"),       { locked = true })
    hl.bind("XF86AudioPrev",        sh("playerctl previous"),   { locked = true })
    hl.bind("XF86AudioPlay",        sh("playerctl play-pause"), { locked = true })
    hl.bind("XF86AudioPause",       sh("playerctl play-pause"), { locked = true })
end)

-- Fehler gesammelt melden
if #errors > 0 then
    local msg = "keybinds: " .. table.concat(errors, " | ")
    print("[claudes-glassy] " .. msg)
    pcall(function() hl.notification.create({ text = msg, timeout = 20000 }) end)
end
