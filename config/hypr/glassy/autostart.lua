-- claudes-glassy: Autostart (nur beim Start von Hyprland, nicht beim Neuladen)
hl.on("hyprland.start", function()
    hl.exec_cmd("waybar")
    hl.exec_cmd("swaync")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd(GLASSY.scripts .. "/wallpaper.sh init")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("nm-applet --indicator")
    hl.exec_cmd(GLASSY.scripts .. "/startmenu.sh --start-daemon")   -- Startmenue vorladen = sofort offen
    hl.exec_cmd(GLASSY.scripts .. "/island.sh")                     -- Dynamic Island oben in der Mitte
    hl.exec_cmd(GLASSY.scripts .. "/clipboard.sh --start-daemon")   -- Zwischenablage vorladen
    hl.exec_cmd(GLASSY.scripts .. "/panel.sh --start-daemon")       -- Flyouts der Leiste vorladen
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/glassy --watch")  -- Update-Benachrichtigung (SUPER+I -> Updates)
end)
