-- claudes-glassy: Autostart (nur beim Start von Hyprland, nicht beim Neuladen)
local HOME = os.getenv("HOME")

hl.on("hyprland.start", function()
    -- Shell: Leiste, Seitenleisten, Overview, Benachrichtigungen, Sperrbildschirm, Wallpaper
    hl.exec_cmd("qs -c $qsConfig")
    hl.exec_cmd(HOME .. "/.config/hypr/hyprland/scripts/start_geoclue_agent.sh")   -- Wetter / Nachtlicht
    hl.exec_cmd(HOME .. "/.config/hypr/custom/scripts/__restore_video_wallpaper.sh")

    -- Kern-Dienste
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")
    -- Vitra: Einrichtung von Paketen nachholen, die nur mit pacman aktualisiert wurden
    hl.exec_cmd("sleep 5 && command -v vtx >/dev/null && vtx deploy --quiet")
    hl.exec_cmd(HOME .. "/.local/bin/glassy --idle-start")   -- hypridle nur, wenn "Automatisch sperren" an ist
    hl.exec_cmd("dbus-update-activation-environment --all")
    hl.exec_cmd("sleep 1 && dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
    -- Bildschirm teilen (Discord, OBS, Browser): Portale mit der Hyprland-Umgebung neu starten.
    -- Sonst haengt oft noch das KDE-Portal aus der Plasma-Sitzung dran und die Auswahl kommt nie.
    hl.exec_cmd("sleep 2 && systemctl --user restart xdg-desktop-portal-hyprland xdg-desktop-portal")

    -- Zwischenablage. Lag-Fix: Text meldet Quickshell selbst (onClipboardTextChanged),
    -- nur Bilder brauchen den IPC-Aufruf. Vorher startete JEDES Strg+C einen kompletten
    -- zweiten Quickshell-Prozess.
    hl.exec_cmd("wl-paste --type text --watch cliphist -max-items 400 store")
    hl.exec_cmd("wl-paste --type image --watch bash -c 'cliphist -max-items 400 store && qs -c $qsConfig ipc call cliphistService update'")

    -- Cursor
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")

    -- claudes-glassy: neues Miku-Wallpaper (nur wenn SUPER+I -> Glassy -> Miku-Wallpaper an ist)
    hl.exec_cmd("sleep 3 && " .. HOME .. "/.local/bin/glassy --miku-wall --startup")

    -- claudes-glassy: Update-Benachrichtigung (SUPER+I -> Glassy)
    hl.exec_cmd(HOME .. "/.local/bin/glassy --watch")
end)
