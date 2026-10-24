-- ==================================================================
--   Catppuccin Glass  -  Hyprland Lua Config (Hyprland 0.55+)
--   Palette: Catppuccin Mocha  |  Look: transparent / blur / glass
--   Aenderungen werden beim Speichern sofort neu geladen.
--   Wiki: https://wiki.hypr.land/Configuring/Start/
-- ==================================================================


---------------------
---- PROGRAMME   ----
---------------------
local terminal    = "kitty"
local fileManager = "dolphin"
local browser     = "firefox"
local menu        = "rofi -show drun"
local scripts     = os.getenv("HOME") .. "/.config/hypr/scripts"
local mainMod     = "SUPER"


---------------------
---- FARBEN      ----
---------------------
-- Catppuccin Mocha
local c = {
    mauve    = "rgba(cba6f7ee)",
    blue     = "rgba(89b4faee)",
    pink     = "rgba(f5c2e7ee)",
    teal     = "rgba(94e2d5ee)",
    surface0 = "rgba(31324488)",
}


------------------
---- MONITORE ----
------------------
-- Positionen bei Bedarf anpassen:  hyprctl monitors
-- DP-3 = Hauptmonitor, HDMI-A-1 links davon, DP-1 rechts davon.
-- DP-1 hochkant: transform = 1 hinzufuegen.
hl.monitor({ output = "DP-3",     mode = "highrr",    position = "0x0",        scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-left",  scale = 1 })
hl.monitor({ output = "DP-1",     mode = "preferred", position = "auto-right", scale = 1 })
-- Fallback fuer alles andere (z. B. Beamer)
hl.monitor({ output = "",         mode = "preferred", position = "auto",       scale = "auto" })

-- Workspaces 1-5 auf dem Hauptmonitor
for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-3", persistent = true })
end


-------------------------------
---- UMGEBUNGSVARIABLEN    ----
-------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- NVIDIA (RTX 5070 Ti)
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

-- Wayland ueberall bevorzugen
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")


-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd(scripts .. "/wallpaper.sh init")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("nm-applet --indicator")
end)


-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 14,
        border_size = 2,

        col = {
            -- Verlauf Mauve -> Blau -> Pink, dreht sich (siehe "borderangle" unten)
            active_border   = { colors = { c.mauve, c.blue, c.pink }, angle = 45 },
            inactive_border = c.surface0,
        },

        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        rounding       = 16,
        rounding_power = 2.5,

        active_opacity     = 1.0,
        inactive_opacity   = 0.94,
        fullscreen_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 24,
            render_power = 3,
            color        = 0x66000000,   -- in Lua: Integer (ARGB), kein rgba()-String
        },

        blur = {
            enabled           = true,
            size              = 8,
            passes            = 3,
            noise             = 0.02,
            contrast          = 1.0,
            brightness        = 0.9,
            vibrancy          = 0.25,
            new_optimizations = true,
            ignore_opacity    = true,
            xray              = false,
            popups            = true,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },

    input = {
        kb_layout          = "de",     -- Oesterreich: "de" (oder "at")
        follow_mouse       = 1,
        sensitivity        = 0,
        accel_profile      = "flat",
        numlock_by_default = true,
    },
})


--------------------
---- ANIMATIONEN ----
--------------------
hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1},    {0.32, 1}    } })
hl.curve("overshot",     { type = "bezier", points = { {0.13, 0.99}, {0.29, 1.1}  } })
hl.curve("wind",         { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.05}  } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},       {1, 1}       } })
hl.curve("bouncy",       { type = "spring", mass = 1, stiffness = 120, dampening = 14 })

hl.animation({ leaf = "global",           enabled = true, speed = 10,  bezier = "default" })
hl.animation({ leaf = "windows",          enabled = true, speed = 5,   spring = "bouncy" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 5,   spring = "bouncy", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3,   bezier = "easeOutQuint", style = "popin 85%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 5,   spring = "bouncy" })
hl.animation({ leaf = "border",           enabled = true, speed = 6,   bezier = "easeOutQuint" })
-- Rotierender Rahmen-Verlauf. Kostet etwas GPU; zum Abschalten enabled = false.
hl.animation({ leaf = "borderangle",      enabled = true, speed = 60,  bezier = "linear", style = "loop" })
hl.animation({ leaf = "fade",             enabled = true, speed = 4,   bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 4,   bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 2,   bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5,   bezier = "overshot", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5,   bezier = "wind", style = "slidefadevert 20%" })


---------------------
---- FENSTERREGELN ----
---------------------
hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Bei Vollbild (Spiele, Videos) nicht sperren / Bildschirm nicht ausschalten
hl.window_rule({
    name = "idle-inhibit-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Glas-Effekt fuer ausgewaehlte Apps (aktiv / inaktiv / Vollbild)
hl.window_rule({
    name = "glass-apps",
    match = { class = "^(org.kde.dolphin|dolphin|org.gnome.Nautilus|code-oss|Code|vesktop|discord|Spotify|spotify|obsidian)$" },
    opacity = "0.92 0.86 1.0",
})

-- Kleine Tools schwebend und zentriert
hl.window_rule({
    name = "float-tools",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|hyprland-share-picker|org.kde.kdeconnect.app)$" },
    float = true,
    center = true,
    size = { "monitor_w * 0.45", "monitor_h * 0.55" },
})

-- Datei-Dialoge schwebend
hl.window_rule({
    name = "float-dialogs",
    match = { title = "^(Open File|Save File|Open Folder|Datei .ffnen|Speichern unter|Ordner .ffnen)(.*)$" },
    float = true,
    center = true,
})

-- Firefox Bild-im-Bild: schwebend, angepinnt, unten rechts
hl.window_rule({
    name = "pip",
    match = { title = "^(Picture-in-Picture|Bild-im-Bild)$" },
    float = true,
    pin = true,
    size = { "monitor_w * 0.28", "monitor_h * 0.28" },
    move = { "monitor_w * 0.70", "monitor_h * 0.68" },
})


-------------------
---- LAYER-REGELN ----
-------------------
hl.layer_rule({ name = "waybar-glass", match = { namespace = "^waybar$" }, blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ name = "rofi-glass",   match = { namespace = "^rofi$" },   blur = true, ignore_alpha = 0.1, animation = "popin 90%" })
hl.layer_rule({
    name = "swaync-glass",
    match = { namespace = "^swaync-(control-center|notification-window)$" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "slide right",
})
hl.layer_rule({ name = "no-anim-selection", match = { namespace = "^(selection|hyprpicker)$" }, no_anim = true })


---------------------
---- KEYBINDINGS ----
---------------------
local function sh(cmd) return hl.dsp.exec_cmd(cmd) end

-- Apps
hl.bind(mainMod .. " + Return", sh(terminal))
hl.bind(mainMod .. " + Space",  sh(menu))
hl.bind(mainMod .. " + E",      sh(fileManager))
hl.bind(mainMod .. " + B",      sh(browser))

-- Fenster
hl.bind(mainMod .. " + Q",          hl.dsp.window.close())
hl.bind(mainMod .. " + F",          hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F",  hl.dsp.window.fullscreen({ mode = "maximized",  action = "toggle" }))
hl.bind(mainMod .. " + T",          hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + C",          hl.dsp.window.center())
hl.bind(mainMod .. " + SHIFT + P",  hl.dsp.window.pin({ action = "toggle" }))
hl.bind(mainMod .. " + P",          hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J",          hl.dsp.layout("togglesplit"))

-- Tools
hl.bind(mainMod .. " + L",          sh("pidof hyprlock || hyprlock"))
hl.bind(mainMod .. " + V",          sh(scripts .. "/clipboard.sh"))
hl.bind(mainMod .. " + N",          sh("swaync-client -t -sw"))
hl.bind(mainMod .. " + Escape",     sh(scripts .. "/powermenu.sh"))
hl.bind(mainMod .. " + SHIFT + W",  sh(scripts .. "/wallpaper.sh next"))
hl.bind(mainMod .. " + SHIFT + B",  sh("pkill -SIGUSR1 waybar"))                -- Bar ein/aus
hl.bind(mainMod .. " + SHIFT + R",  sh("pkill -x waybar; waybar"))             -- Bar neu starten
hl.bind(mainMod .. " + SHIFT + C",  sh("hyprpicker -a"))                       -- Farbpipette
hl.bind("Print",                    sh(scripts .. "/screenshot.sh area"))
hl.bind("SHIFT + Print",            sh(scripts .. "/screenshot.sh full"))
hl.bind(mainMod .. " + SHIFT + M",  sh("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"))

-- Fokus / Fenster verschieben / Groesse
for _, dir in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mainMod .. " + " .. dir,              hl.dsp.focus({ direction = dir }))
    hl.bind(mainMod .. " + SHIFT + " .. dir,      hl.dsp.window.move({ direction = dir }))
end
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -40, y = 0 }),  { repeating = true })
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40,  y = 0 }),  { repeating = true })
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -40 }), { repeating = true })
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 40 }),  { repeating = true })

-- Workspaces 1-10
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,           hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i, follow = true }))
    hl.bind(mainMod .. " + ALT + " .. key,     hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Scratchpad
hl.bind(mainMod .. " + S",          hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S",  hl.dsp.window.move({ workspace = "special:magic" }))

-- Mausrad / Maus
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })

-- Medien
hl.bind("XF86AudioRaiseVolume", sh("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),      { locked = true, repeating = true })
hl.bind("XF86AudioMute",        sh("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),     { locked = true })
hl.bind("XF86AudioMicMute",     sh("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),   { locked = true })
hl.bind("XF86AudioNext",        sh("playerctl next"),       { locked = true })
hl.bind("XF86AudioPrev",        sh("playerctl previous"),   { locked = true })
hl.bind("XF86AudioPlay",        sh("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause",       sh("playerctl play-pause"), { locked = true })


-- Eigene Ergaenzungen in eine extra Datei, damit Updates dieser Datei nichts kaputt machen:
-- ~/.config/hypr/custom.lua  (wird nur geladen, wenn vorhanden)
local customPath = os.getenv("HOME") .. "/.config/hypr/custom.lua"
local f = io.open(customPath, "r")
if f then
    f:close()
    pcall(dofile, customPath)
end
