-- claudes-glassy: Monitore
-- Pruefen mit:  hyprctl monitors
-- Aufbau am Tisch: HDMI-A-1 links (240 Hz), DP-3 Mitte = Hauptmonitor (240 Hz), DP-1 rechts (165 Hz).
-- "highrr" = hoechste Hz-Zahl bei voller Aufloesung (sonst nimmt Hyprland oft 60 Hz).
-- DP-1 hochkant: transform = 1 ergaenzen (die Uebersicht laggt dabei jetzt nicht mehr).
-- Eigene Aenderungen lieber in ~/.config/hypr/custom/general.lua oder ~/.config/hypr/monitors.lua
-- (nwg-displays), die werden nicht ueberschrieben.

hl.monitor({ output = "DP-3",     mode = "highrr", position = "0x0",        scale = 1 })
hl.monitor({ output = "HDMI-A-1", mode = "highrr", position = "auto-left",  scale = 1 })
hl.monitor({ output = "DP-1",     mode = "highrr", position = "auto-right", scale = 1 })
hl.monitor({ output = "",         mode = "highrr", position = "auto",       scale = "auto" })

for i = 1, 5 do
    hl.workspace_rule({ workspace = tostring(i), monitor = GLASSY.mainMonitor, persistent = true })
end
