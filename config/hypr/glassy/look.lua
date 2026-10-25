-- claudes-glassy: Aussehen (Farben kommen vom Theme)
-- Variablen: https://wiki.hypr.land/Configuring/Basics/Variables/

local c = {
    mauve    = "rgba(bb9af7ee)",
    blue     = "rgba(7aa2f7ee)",
    pink     = "rgba(ff79c6ee)",
    surface0 = "rgba(292e4288)",
}
-- Rahmenfarben vom aktiven Theme (SUPER+I -> Aussehen -> Theme)
do
    local ok, t = pcall(dofile, os.getenv("HOME") .. "/.config/hypr/glassy-theme.lua")
    if ok and type(t) == "table" then
        c.mauve, c.blue, c.pink = t.border_a or c.mauve, t.border_b or c.blue, t.border_c or c.pink
        c.surface0 = t.border_inactive or c.surface0
    end
end

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
