-- claudes-glassy: Monitore
-- Pruefen mit:  hyprctl monitors
-- DP-3 = Hauptmonitor, HDMI-A-1 links, DP-1 rechts.
-- DP-1 hochkant: transform = 1 ergaenzen.

hl.monitor({ output = "DP-3",     mode = "highrr",    position = "0x0",        scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "auto-left",  scale = 1 })
hl.monitor({ output = "DP-1",     mode = "preferred", position = "auto-right", scale = 1 })
hl.monitor({ output = "",         mode = "preferred", position = "auto",       scale = "auto" })

for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), monitor = GLASSY.mainMonitor, persistent = true })
end
