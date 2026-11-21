-- claudes-glassy: Animationen
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

local G = GLASSY_GEN or {}
local errors = {}
local function curve(name, t)
    local ok, err = pcall(hl.curve, name, t)
    if not ok then table.insert(errors, name .. ": " .. tostring(err)) end
end
local function anim(t)
    local ok, err = pcall(hl.animation, t)
    if not ok then table.insert(errors, t.leaf .. ": " .. tostring(err)) end
end

curve("easeOutQuint",    { type = "bezier", points = { {0.23, 1},    {0.32, 1}   } })
curve("overshot",        { type = "bezier", points = { {0.13, 0.99}, {0.29, 1.1} } })
curve("wind",            { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.05} } })
curve("linear",          { type = "bezier", points = { {0, 0},       {1, 1}      } })
curve("emphasizedDecel", { type = "bezier", points = { {0.05, 0.7},  {0.1, 1}    } })
curve("menu_decel",      { type = "bezier", points = { {0.1, 1},     {0, 1}      } })
curve("menu_accel",      { type = "bezier", points = { {0.52, 0.03}, {0.72, 0.08} } })
curve("bouncy",          { type = "spring", mass = 1, stiffness = 120, dampening = 14 })

anim({ leaf = "global",           enabled = true, speed = 10, bezier = "default" })
anim({ leaf = "windows",          enabled = true, speed = 5,  spring = "bouncy" })
anim({ leaf = "windowsIn",        enabled = true, speed = 5,  spring = "bouncy", style = "popin 80%" })
anim({ leaf = "windowsOut",       enabled = true, speed = 3,  bezier = "easeOutQuint", style = "popin 85%" })
anim({ leaf = "windowsMove",      enabled = true, speed = 5,  spring = "bouncy" })
anim({ leaf = "border",           enabled = true, speed = 6,  bezier = "easeOutQuint" })
-- Rotierender Rahmen-Verlauf: zwingt Hyprland, auf ALLEN Monitoren jeden Frame neu
-- zu zeichnen (bei 240 Hz spuerbar). Standard jetzt aus, einschalten in SUPER+I -> Glassy.
anim({ leaf = "borderangle",      enabled = G.border_anim == true, speed = 60, bezier = "linear", style = "loop" })
anim({ leaf = "fade",             enabled = true, speed = 4,  bezier = "easeOutQuint" })
-- Shell-Panels (Seitenleisten, Overview ...) wie bei illogical-impulse
anim({ leaf = "layersIn",         enabled = true, speed = 3,  bezier = "emphasizedDecel", style = "popin 93%" })
anim({ leaf = "layersOut",        enabled = true, speed = 1.6, bezier = "menu_accel", style = "popin 94%" })
anim({ leaf = "fadeLayersIn",     enabled = true, speed = 0.5, bezier = "menu_decel" })
anim({ leaf = "fadeLayersOut",    enabled = true, speed = 2.7, bezier = "menu_accel" })
anim({ leaf = "workspaces",       enabled = true, speed = 5,  bezier = "overshot", style = "slidefade 15%" })
anim({ leaf = "specialWorkspace", enabled = true, speed = 5,  bezier = "wind", style = "slidefadevert 20%" })

if #errors > 0 then glassy_notify("animations: " .. table.concat(errors, " | ")) end
