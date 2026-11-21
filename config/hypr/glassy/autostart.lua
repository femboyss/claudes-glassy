-- claudes-glassy: Autostart (nur beim Start von Hyprland, nicht beim Neuladen)
local HOME = os.getenv("HOME")

hl.on("hyprland.start", function()
    -- Shell: Leiste, Seitenleisten, Overview, Benachrichtigungen, Sperrbildschirm, Wallpaper
    hl.exec_cmd("qs -c $qsConfig")
    hl.exec_cmd(HOME .. "/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")   -- Wetter / Nachtlicht
    hl.exec_cmd(HOME .. "/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")

    -- Kern-Dienste
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")

    -- Zwischenablage. Lag-Fix: Text meldet Quickshell selbst (onClipboardTextChanged),
    -- nur Bilder brauchen den IPC-Aufruf. Vorher startete JEDES Strg+C einen kompletten
    -- zweiten Quickshell-Prozess.
    hl.exec_cmd("wl-paste --type text --watch cliphist -max-items 400 store")
    hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist -max-items 400 store && qs -c $qsConfig ipc call cliphistService update'")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")

    -- claudes-glassy: Update-Benachrichtigung (SUPER+I -> Glassy)
    hl.exec_cmd(HOME .. "/.local/bin/glassy --watch")
end)
