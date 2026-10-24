-- claudes-glassy: Animationen
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/

hl.curve("easeOutQuint", { type = "bezier", points = { {0.23, 1},    {0.32, 1}   } })
hl.curve("overshot",     { type = "bezier", points = { {0.13, 0.99}, {0.29, 1.1} } })
hl.curve("wind",         { type = "bezier", points = { {0.05, 0.9},  {0.1, 1.05} } })
hl.curve("linear",       { type = "bezier", points = { {0, 0},       {1, 1}      } })
hl.curve("bouncy",       { type = "spring", mass = 1, stiffness = 120, dampening = 14 })

hl.animation({ leaf = "global",           enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "windows",          enabled = true, speed = 5,  spring = "bouncy" })
hl.animation({ leaf = "windowsIn",        enabled = true, speed = 5,  spring = "bouncy", style = "popin 80%" })
hl.animation({ leaf = "windowsOut",       enabled = true, speed = 3,  bezier = "easeOutQuint", style = "popin 85%" })
hl.animation({ leaf = "windowsMove",      enabled = true, speed = 5,  spring = "bouncy" })
hl.animation({ leaf = "border",           enabled = true, speed = 6,  bezier = "easeOutQuint" })
-- Rotierender Rahmen-Verlauf (kostet etwas GPU, enabled = false zum Abschalten)
hl.animation({ leaf = "borderangle",      enabled = true, speed = 60, bezier = "linear", style = "loop" })
hl.animation({ leaf = "fade",             enabled = true, speed = 4,  bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",         enabled = true, speed = 4,  bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "layersOut",        enabled = true, speed = 2,  bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspaces",       enabled = true, speed = 5,  bezier = "overshot", style = "slidefade 15%" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5,  bezier = "wind", style = "slidefadevert 20%" })
