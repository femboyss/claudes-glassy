-- claudes-glassy: Fenster- und Layer-Regeln
-- Basis: illogical-impulse (end-4), plus Glassy-Regeln unten.
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- https://wiki.hypr.land/configuring/core/rules/layer-rules/
-- Jede Regel einzeln abgesichert: eine kaputte Regel stoppt nicht den Rest.

local errors = {}
local function try(fn, t)
    local ok, err = pcall(fn, t)
    if not ok then
        local m = t and t.match and (t.match.class or t.match.title or t.match.namespace) or "?"
        table.insert(errors, tostring(m) .. ": " .. tostring(err))
    end
end
function wrule(t) try(hl.window_rule, t) end
function lrule(t) try(hl.layer_rule, t) end
function wsrule(t) try(hl.workspace_rule, t) end

-- ######## Window rules ########

-- Disable blur for xwayland context menus

-- Disable blur for every window

-- Floating
wrule({match = {title = "^(Open File)(.*)$" },                      center = true})
wrule({match = {title = "^(Open File)(.*)$" },                      float = true})
wrule({match = {title = "^(Select a File)(.*)$" },                  center = true})
wrule({match = {title = "^(Select a File)(.*)$" },                  float = true})
wrule({match = {title = "^(Choose wallpaper)(.*)$" },               center = true})
wrule({match = {title = "^(Choose wallpaper)(.*)$" },               float = true})
wrule({match = {title = "^(Choose wallpaper)(.*)$" },               size = {"(monitor_w*0.60)", "(monitor_h*0.65)"} })
wrule({match = {title = "^(Open Folder)(.*)$" },                    center = true})
wrule({match = {title = "^(Open Folder)(.*)$" },                    float = true})
wrule({match = {title = "^(Select the mod file to import)(.*)$" },  center = true}) -- Gale
wrule({match = {title = "^(Select the mod file to import)(.*)$" },  float = true})
wrule({match = {title = "^(Save As)(.*)$" },                        center = true})
wrule({match = {title = "^(Save As)(.*)$" },                        float = true})
wrule({match = {title = "^(Library)(.*)$" },                        center = true})
wrule({match = {title = "^(Library)(.*)$" },                        float = true})
wrule({match = {title = "^(File Upload)(.*)$" },                    center = true})
wrule({match = {title = "^(File Upload)(.*)$" },                    float = true})
wrule({match = {title = "^(.*)(wants to save)$" },                  center = true})
wrule({match = {title = "^(.*)(wants to save)$" },                  float = true})
wrule({match = {title = "^(.*)(wants to open)$" },                  center = true})
wrule({match = {title = "^(.*)(wants to open)$" },                  float = true})
wrule({match = {class = "^(blueberry\\.py)$" },                     float = true})
wrule({match = {class = "^(guifetch)$" },                           float = true}) -- FlafyDev/guifetch
wrule({match = {class = "^(pavucontrol)$" },                        float = true})
wrule({match = {class = "^(pavucontrol)$" },                        size = {"(monitor_w*0.45)", "(monitor_h*0.45)"} })
wrule({match = {class = "^(pavucontrol)$" },                        center = true})
wrule({match = {class = "^(org.pulseaudio.pavucontrol)$" },         float = true})
wrule({match = {class = "^(org.pulseaudio.pavucontrol)$" },         size = {"(monitor_w*0.45)", "(monitor_h*0.45)"} })
wrule({match = {class = "^(org.pulseaudio.pavucontrol)$" },         center = true})
wrule({match = {class = "^(nm-connection-editor)$" },               float = true})
wrule({match = {class = "^(nm-connection-editor)$" },               size = {"(monitor_w*0.45)", "(monitor_h*0.45)"} })
wrule({match = {class = "^(nm-connection-editor)$" },               center = true})
wrule({match = {class = ".*plasmawindowed.*" },                     float = true})
wrule({match = {class = "kcm_.*" },                                  float = true})
wrule({match = {class = ".*bluedevilwizard" },                      float = true})
wrule({match = {title = ".*Welcome" },                              float = true})
wrule({match = {title = "^(illogical-impulse Settings)$" },         float = true})
wrule({match = {title = ".*Shell conflicts.*" },                    float = true})
wrule({match = {class = "org.freedesktop.impl.portal.desktop.kde" }, float = true})
wrule({match = {class = "org.freedesktop.impl.portal.desktop.kde" }, size = {"(monitor_w*0.60)", "(monitor_h*0.65)"} })
wrule({match = {class = "^(Zotero)$" },                             float = true})
wrule({match = {class = "^(Zotero)$" },                             size = {"(monitor_w*0.45)", "(monitor_h*0.45)"} })

-- Move
-- kde-material-you-colors spawns a window when changing dark/light theme. This is to make sure it doesn't interfere at all.
wrule({match = {class = "^(plasma-changeicons)$" }, float = true})
wrule({match = {class = "^(plasma-changeicons)$" }, no_initial_focus = true})
wrule({match = {class = "^(plasma-changeicons)$" }, move = {999999, 999999}})
-- stupid dolphin copy
wrule({match = {title = "^(Copying — Dolphin)$" }, move = {40, 80}})

-- Tiling
-- Ignore app maximize requests so restored window states do not override tiling.
wrule({match = {class = ".*" }, suppress_event = "maximize"})
wrule({match = {class = "^dev\\.warp\\.Warp$" }, tile = true})

-- Picture-in-Picture
wrule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, float = true})
wrule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, keep_aspect_ratio = true})
wrule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, move = {"(monitor_w*0.73)", "(monitor_h*0.72)"} })
wrule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, size = {"(monitor_w*0.25)", "(monitor_h*0.25)"} })
wrule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, float = true})
wrule({match = {title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, pin = true})

-- Screen sharing
wrule({match = {title = ".*is sharing (a window|your screen).*" }, float = true})
wrule({match = {title = ".*is sharing (a window|your screen).*" }, pin = true})
wrule({match = {title = ".*is sharing (a window|your screen).*" }, move = {"(monitor_w*.5-window_w*.5)", "(monitor_h-window_h-12)"} })

-- --- Tearing ---
wrule({match = {title = ".*\\.exe" }, immediate = true})
wrule({match = {title = ".*minecraft.*" }, immediate = true})
wrule({match = {class = "^(steam_app).*" }, immediate = true})

-- No shadow for tiled windows
wrule({match = {float = 0 }, no_shadow = true})

-- ######## Workspace rules ########
wsrule({ workspace = "special:special", gaps_out = 30 })

-- ######## Layer rules ########
lrule({ match = { namespace = ".*" }, xray = true})
lrule({ match = { namespace = "walker" }, no_anim = true})
lrule({ match = { namespace = "selection" }, no_anim = true})
lrule({ match = { namespace = "overview" }, no_anim = true})
lrule({ match = { namespace = "anyrun" }, no_anim = true})
lrule({ match = { namespace = "indicator.*" }, no_anim = true})
lrule({ match = { namespace = "osk" }, no_anim = true})
lrule({ match = { namespace = "hyprpicker" }, no_anim = true})

lrule({ match = { namespace = "noanim" }, no_anim = true})
lrule({ match = { namespace = "gtk-layer-shell" }, blur = true})
lrule({ match = { namespace = "gtk-layer-shell" }, ignore_alpha = 0})
lrule({ match = { namespace = "launcher" }, blur = true})
lrule({ match = { namespace = "launcher" }, ignore_alpha = 0.5})
lrule({ match = { namespace = "notifications" }, blur = true})
lrule({ match = { namespace = "notifications" }, ignore_alpha = 0.69})
lrule({ match = { namespace = "logout_dialog" }, blur = true}) -- wlogout

-- ags
lrule({ match = { namespace = "sideleft.*" }, animation = "slide left"})
lrule({ match = { namespace = "sideright.*" }, animation = "slide right"})
lrule({ match = { namespace = "session[0-9]*" }, blur = true})
lrule({ match = { namespace = "bar[0-9]*" }, blur = true})
lrule({ match = { namespace = "bar[0-9]*" }, ignore_alpha = 0.6})
lrule({ match = { namespace = "barcorner.*" }, blur = true})
lrule({ match = { namespace = "barcorner.*" }, ignore_alpha = 0.6})
lrule({ match = { namespace = "dock[0-9]*" }, blur = true})
lrule({ match = { namespace = "dock[0-9]*" }, ignore_alpha = 0.6})
lrule({ match = { namespace = "indicator.*" }, blur = true})
lrule({ match = { namespace = "indicator.*" }, ignore_alpha = 0.6})
lrule({ match = { namespace = "overview[0-9]*" }, blur = true})
lrule({ match = { namespace = "overview[0-9]*" }, ignore_alpha = 0.6})
lrule({ match = { namespace = "cheatsheet[0-9]*" }, blur = true})
lrule({ match = { namespace = "cheatsheet[0-9]*" }, ignore_alpha = 0.6})
lrule({ match = { namespace = "sideright[0-9]*" }, blur = true})
lrule({ match = { namespace = "sideright[0-9]*" }, ignore_alpha = 0.6})
lrule({ match = { namespace = "sideleft[0-9]*" }, blur = true})
lrule({ match = { namespace = "sideleft[0-9]*" }, ignore_alpha = 0.6})
lrule({ match = { namespace = "indicator.*" }, blur = true})
lrule({ match = { namespace = "indicator.*" }, ignore_alpha = 0.6})
lrule({ match = { namespace = "osk[0-9]*" }, blur = true})
lrule({ match = { namespace = "osk[0-9]*" }, ignore_alpha = 0.6})

-- Quickshell
-- Quickshell: illogical-impulse
lrule({ match = { namespace = "quickshell:.*" }, blur_popups = true})
lrule({ match = { namespace = "quickshell:.*" }, blur = true})
lrule({ match = { namespace = "quickshell:.*" }, ignore_alpha = 0.3}) -- claudes-glassy: Glas-Panels sind durchsichtiger, sonst kein Blur
lrule({ match = { namespace = "quickshell:background" }, blur = false})
lrule({ match = { namespace = "quickshell:bar" }, animation = "slide"})
lrule({ match = { namespace = "quickshell:actionCenter" }, no_anim = true})
lrule({ match = { namespace = "quickshell:cheatsheet" }, animation = "slide bottom"})
lrule({ match = { namespace = "quickshell:dock" }, animation = "slide bottom"})
lrule({ match = { namespace = "quickshell:screenCorners" }, animation = "popin 120%"})
lrule({ match = { namespace = "quickshell:lockWindowPusher" }, no_anim = true})
lrule({ match = { namespace = "quickshell:notificationPopup" }, animation = "fade"})
lrule({ match = { namespace = "quickshell:overlay" }, no_anim = true})
lrule({ match = { namespace = "quickshell:overlay" }, ignore_alpha = 1})
lrule({ match = { namespace = "quickshell:overview" }, no_anim = true})
lrule({ match = { namespace = "quickshell:osk" }, animation = "slide bottom"})
lrule({ match = { namespace = "quickshell:polkit" }, no_anim = true})
lrule({ match = { namespace = "quickshell:popup" }, xray = false}) -- No weird color for bar tooltips (this in theory should suffice)
lrule({ match = { namespace = "quickshell:popup" }, ignore_alpha = 1}) -- No weird color for bar tooltips (but somehow this is necessary)
lrule({ match = { namespace = "quickshell:mediaControls" }, ignore_alpha = 1}) -- Same as above
lrule({ match = { namespace = "quickshell:reloadPopup" }, animation = "slide"})
lrule({ match = { namespace = "quickshell:regionSelector" }, no_anim = true})
lrule({ match = { namespace = "quickshell:screenshot" }, no_anim = true})
lrule({ match = { namespace = "quickshell:session" }, blur = true})
lrule({ match = { namespace = "quickshell:session" }, no_anim = true})
lrule({ match = { namespace = "quickshell:session" }, ignore_alpha = 0})
lrule({ match = { namespace = "quickshell:sidebarRight" }, animation = "slide right"})
lrule({ match = { namespace = "quickshell:sidebarLeft" }, animation = "slide left"})
lrule({ match = { namespace = "quickshell:verticalBar" }, animation = "slide"})
lrule({ match = { namespace = "quickshell:osk" }, order = -1})
-- Quickshell: waffles
lrule({ match = { namespace = "quickshell:wallpaperSelector" }, animation = "slide top"})
lrule({ match = { namespace = "quickshell:wNotificationCenter" }, no_anim = true})
lrule({ match = { namespace = "quickshell:wOnScreenDisplay" }, no_anim = true})
lrule({ match = { namespace = "quickshell:wStartMenu" }, no_anim = true})
lrule({ match = { namespace = "quickshell:wTaskView" }, ignore_alpha = 0})
lrule({ match = { namespace = "quickshell:wTaskView" }, no_anim = true})

-- Launchers need to be FAST
lrule({ match = { namespace = "gtk4-layer-shell" }, no_anim = true})

-- ######## claudes-glassy ########

-- Vollbild (Spiele/Videos): nicht sperren, Bildschirm bleibt an
wrule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- XWayland-Drag&Drop-Geisterfenster nicht fokussieren
wrule({ match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false }, no_focus = true })

-- Glas fuer ausgewaehlte Apps (aktiv / inaktiv / Vollbild)
wrule({
    match = { class = "^(org.kde.dolphin|dolphin|org.gnome.Nautilus|code-oss|Code|vesktop|discord|Spotify|spotify|obsidian)$" },
    opacity = "0.94 0.88 1.0",
})

-- Kleine Tools schwebend und zentriert
wrule({
    match = { class = "^(blueman-manager|hyprland-share-picker|io.missioncenter.MissionCenter|org.gnome.SystemMonitor)$" },
    float = true,
    center = true,
    size = { "monitor_w * 0.55", "monitor_h * 0.65" },
})
wrule({ match = { title = "^(Datei .ffnen|Speichern unter|Ordner .ffnen)(.*)$" }, float = true })
wrule({ match = { title = "^(Datei .ffnen|Speichern unter|Ordner .ffnen)(.*)$" }, center = true })
wrule({ match = { title = "^(Bild-im-Bild)$" }, float = true })
wrule({ match = { title = "^(Bild-im-Bild)$" }, pin = true })

-- Einstellungen (SUPER+I) schwebend und mittig
wrule({ match = { title = "^(illogical-impulse Settings)$" }, center = true })
wrule({ match = { title = "^(illogical-impulse Settings)$" }, size = { "monitor_w * 0.55", "monitor_h * 0.7" } })

-- Anima Engine (Desktop-Pets/Sticker ueber Proton): ohne Rahmen, Ecken, Schatten, Blur
-- Fuer echte Transparenz braucht es GE-Proton + Startoption WINE_LAYERED_OVERLAY_SHAPE=1 (siehe README)
local anima = { class = "^(steam_app_3474900|anima ?engine.*|AnimaEngine.*)$" }
wrule({ match = anima, float = true, pin = true, border_size = 0, rounding = 0 })
wrule({ match = anima, no_shadow = true, no_blur = true, no_dim = true })
wrule({ match = { title = "^(Anima Engine)$" }, float = true, pin = true, border_size = 0, rounding = 0 })

-- Spiele: kein Dimmen, keine Transparenz (FPS)
wrule({ match = { class = "^(steam_app_.*|gamescope|genshinimpact.exe|.*\\.exe)$" }, no_dim = true })
wrule({ match = { class = "^(steam_app_.*|gamescope|genshinimpact.exe|.*\\.exe)$" }, opaque = true })

if #errors > 0 then
    glassy_notify("rules: " .. table.concat(errors, " | "))
end
