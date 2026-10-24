-- claudes-glassy: Fenster- und Layer-Regeln
-- https://wiki.hypr.land/Configuring/Basics/Window-Rules/
-- https://wiki.hypr.land/configuring/core/rules/layer-rules/

local errors = {}
local function rule(kind, t)
    local ok, err = pcall(kind == "layer" and hl.layer_rule or hl.window_rule, t)
    if not ok then table.insert(errors, (t.name or "?") .. ": " .. tostring(err)) end
end

---------------- Fenster ----------------
rule("window", { name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })

rule("window", {
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

-- Vollbild (Spiele/Videos): nicht sperren, Bildschirm bleibt an
rule("window", { name = "idle-inhibit-fullscreen", match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- Glas fuer ausgewaehlte Apps (aktiv / inaktiv / Vollbild)
rule("window", {
    name = "glass-apps",
    match = { class = "^(org.kde.dolphin|dolphin|org.gnome.Nautilus|code-oss|Code|vesktop|discord|Spotify|spotify|obsidian)$" },
    opacity = "0.92 0.86 1.0",
})

-- Kleine Tools schwebend und zentriert
rule("window", {
    name = "float-tools",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|nm-connection-editor|blueman-manager|hyprland-share-picker|io.missioncenter.MissionCenter|glassy-taskmgr)$" },
    float = true,
    center = true,
    size = { "monitor_w * 0.55", "monitor_h * 0.65" },
})

rule("window", {
    name = "float-dialogs",
    match = { title = "^(Open File|Save File|Open Folder|Datei .ffnen|Speichern unter|Ordner .ffnen)(.*)$" },
    float = true,
    center = true,
})

rule("window", {
    name = "pip",
    match = { title = "^(Picture-in-Picture|Bild-im-Bild)$" },
    float = true,
    pin = true,
    size = { "monitor_w * 0.28", "monitor_h * 0.28" },
    move = { "monitor_w * 0.70", "monitor_h * 0.68" },
})

-- Anima Engine (Desktop-Pets/Sticker ueber Proton): ohne Rahmen, Ecken, Schatten, Blur
-- Fuer echte Transparenz braucht es GE-Proton + Startoption WINE_LAYERED_OVERLAY_SHAPE=1 (siehe README)
local anima = { class = "^(steam_app_3474900|anima ?engine.*|AnimaEngine.*)$" }
rule("window", { name = "anima-core", match = anima, float = true, pin = true, border_size = 0, rounding = 0 })
rule("window", { name = "anima-clean", match = anima, no_shadow = true, no_blur = true, no_dim = true })
rule("window", { name = "anima-title", match = { title = "^(Anima Engine)$" }, float = true, pin = true, border_size = 0, rounding = 0 })

---------------- Layer (Glas-Blur) ----------------
rule("layer", { name = "waybar-glass", match = { namespace = "^waybar$" }, blur = true, ignore_alpha = 0.1 })
rule("layer", { name = "rofi-glass",   match = { namespace = "^rofi$" },   blur = true, ignore_alpha = 0.05, animation = "popin 92%" })
rule("layer", {
    name = "swaync-glass",
    match = { namespace = "^swaync-(control-center|notification-window)$" },
    blur = true,
    ignore_alpha = 0.1,
    animation = "slide right",
})
-- Startmenue (GTK4, Layer-Shell): Blur nur hinter dem Panel, nicht hinter der transparenten Flaeche
rule("layer", { name = "startmenu-glass", match = { namespace = "^glassy-startmenu$" }, blur = true, ignore_alpha = 0.35, animation = "fade" })
-- Fallback ohne gtk4-layer-shell: normales Fenster oben links
rule("window", {
    name = "startmenu-window",
    match = { class = "^glassy.startmenu$" },
    float = true,
    pin = true,
    border_size = 0,
    move = { "14", "54" },
})
-- Zwischenablage (GTK4, Layer-Shell)
rule("layer", { name = "clipboard-glass", match = { namespace = "^glassy-clipboard$" }, blur = true, ignore_alpha = 0.35, animation = "popin 94%" })
-- Dynamic Island
rule("layer", { name = "island", match = { namespace = "^glassy-island$" }, blur = true, ignore_alpha = 0.6, animation = "slide top" })  -- 0.6: Schatten nicht mitblurren
rule("layer", { name = "no-anim-selection", match = { namespace = "^(selection|hyprpicker)$" }, no_anim = true })

if #errors > 0 then
    local msg = "rules: " .. table.concat(errors, " | ")
    print("[claudes-glassy] " .. msg)
    pcall(function() hl.notification.create({ text = msg, timeout = 20000 }) end)
end
