-- claudes-glassy: Aussehen (Farben kommen vom Theme, SUPER+I -> Glassy)
-- Variablen: https://wiki.hypr.land/Configuring/Basics/Variables/

local G = GLASSY_GEN or {}
local c = {
    a        = G.border_a or "rgba(7aa2f7ee)",
    b        = G.border_b or "rgba(bb9af7ee)",
    c        = G.border_c or "rgba(ff79c6ee)",
    inactive = G.border_inactive or "rgba(292e4288)",
}

-- Jeder Abschnitt einzeln: eine unbekannte Option (andere Hyprland-Version)
-- macht nicht gleich das ganze Aussehen kaputt
local errors = {}
local function section(name, t)
    local ok, err = pcall(hl.config, { [name] = t })
    if not ok then table.insert(errors, name .. ": " .. tostring(err)) end
end

local S = {
    general = {
        gaps_in          = 6,
        gaps_out         = 14,
        gaps_workspaces  = 50,
        border_size      = 2,
        col = {
            active_border   = { colors = { c.a, c.b, c.c }, angle = 45 },
            inactive_border = c.inactive,
        },
        resize_on_border  = true,
        no_focus_fallback = true,
        allow_tearing     = true,      -- nur fuer Fenster mit "immediate"-Regel (Spiele), siehe rules.lua
        layout            = "dwindle",
        snap = {
            enabled      = true,
            window_gap   = 6,
            monitor_gap  = 14,
            respect_gaps = true,
        },
    },

    decoration = {
        rounding       = 16,
        rounding_power = 2.5,
        active_opacity     = 1.0,
        inactive_opacity   = 0.95,
        fullscreen_opacity = 1.0,
        dim_inactive   = true,
        dim_strength   = 0.05,
        dim_special    = 0.2,
        shadow = {
            enabled      = true,
            range        = 20,
            render_power = 3,
            offset       = { 0, 2 },
            color        = 0x55000000,   -- Lua: Integer ARGB, kein rgba()-String
        },
        blur = {
            enabled           = true,
            -- Lag-Fix: 2 statt 3 Durchgaenge sieht fast gleich aus, kostet ein Drittel weniger
            size              = 8,
            passes            = 2,
            noise             = 0.02,
            contrast          = 0.95,
            brightness        = 0.9,
            vibrancy          = 0.3,
            vibrancy_darkness = 0.3,
            new_optimizations = true,
            ignore_opacity    = true,
            -- xray = Glas zeigt das Wallpaper statt der Fenster dahinter. Viel billiger:
            -- der Blur wird einmal berechnet und gecacht statt bei jedem Frame neu.
            xray              = true,
            special           = false,
            popups            = true,
            popups_ignorealpha = 0.6,
            input_methods     = true,
            input_methods_ignorealpha = 0.8,
        },
    },

    animations = { enabled = true },

    dwindle = {
        preserve_split = true,
        smart_split    = false,
        smart_resizing = false,
    },

    gestures = {
        workspace_swipe_distance = 700,
        workspace_swipe_cancel_ratio = 0.2,
        workspace_swipe_min_speed_to_force = 5,
        workspace_swipe_direction_lock = true,
        workspace_swipe_direction_lock_threshold = 10,
        workspace_swipe_create_new = true,
    },

    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        disable_splash_rendering = true,
        animate_manual_resizes  = false,
        animate_mouse_windowdragging = false,
        enable_swallow          = false,
        focus_on_activate       = true,
        middle_click_paste      = false,
    },

    input = {
        kb_layout          = "de",     -- Oesterreich: "de" (oder "at")
        follow_mouse       = 1,
        sensitivity        = 0,
        accel_profile      = "flat",
        numlock_by_default = true,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
        },
    },

    binds = {
        scroll_event_delay = 0,
        hide_special_on_workspace_change = true,
    },

    cursor = {
        zoom_factor = 1,
        zoom_rigid  = false,
    },
}
for _, name in ipairs({ "general", "decoration", "animations", "dwindle", "gestures", "misc", "input", "binds", "cursor" }) do
    section(name, S[name])
end
if #errors > 0 then glassy_notify("look: " .. table.concat(errors, " | ")) end

-- Touchpad-Gesten (Laptop)
pcall(function()
    hl.gesture({ fingers = 3, direction = "swipe", action = "move" })
    hl.gesture({ fingers = 3, direction = "pinch", action = "fullscreen" })
    hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
    hl.gesture({ fingers = 4, direction = "up", action = function()
        hl.dispatch(hl.dsp.global("quickshell:overviewWorkspacesToggle"))
    end })
end)
