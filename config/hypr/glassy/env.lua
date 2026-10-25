-- claudes-glassy: Umgebungsvariablen
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- NVIDIA
hl.env("LIBVA_DRIVER_NAME", "nvidia")
hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
hl.env("NVD_BACKEND", "direct")

-- Wayland bevorzugen
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")

-- Qt/KDE-Apps (Dolphin, Kate, Ark ...): Farbschema + Stil aus KDE benutzen.
-- Ohne das fallen sie unter Hyprland auf ein helles Standard-Design zurueck.
local function exists(p) local f = io.open(p, "r") if f then f:close() return true end return false end
if exists("/usr/lib/qt6/plugins/platformthemes/KDEPlasmaPlatformTheme6.so") then
    hl.env("QT_QPA_PLATFORMTHEME", "kde")            -- plasma-integration installiert
elseif exists("/usr/bin/qt6ct") then
    hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
end
hl.env("XDG_MENU_PREFIX", "plasma-")                 -- Dolphin "Oeffnen mit"-Liste fuellen
