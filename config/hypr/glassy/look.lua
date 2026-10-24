-- claudes-glassy: Aussehen (Catppuccin Mocha, Glas)
-- Variablen: https://wiki.hypr.land/Configuring/Basics/Variables/

local c = {
    mauve    = "rgba(cba6f7ee)",
    blue     = "rgba(89b4faee)",
    pink     = "rgba(f5c2e7ee)",
    surface0 = "rgba(31324488)",
}

hl.config({
    general = {
        gaps_in     = 6,
        gaps_out    = 14,
        border_size = 2,
        col = {
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
        dim_inactive   = true,
        dim_strength   = 0.06,
        shadow = {
            enabled      = true,
            range        = 24,
            render_power = 3,
            color        = 0x66000000,   -- Lua: Integer ARGB, kein rgba()-String
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

    animations = { enabled = true },
    dwindle    = { preserve_split = true },

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
