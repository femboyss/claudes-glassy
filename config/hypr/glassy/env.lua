-- claudes-glassy: Umgebungsvariablen
local HOME = os.getenv("HOME")
local exists = glassy_exists

-- Shell (Quickshell-Config-Ordner, wird in Befehlen als $qsConfig benutzt)
hl.env("qsConfig", GLASSY.qsConfig)
hl.env("ILLOGICAL_IMPULSE_VIRTUAL_ENV", HOME .. "/.local/state/quickshell/.venv")

-- Cursor
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- NVIDIA (RTX, offenes Kernelmodul)
if exists("/proc/driver/nvidia/version") then
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
    -- Shader-Cache gross genug fuer Quickshell + Spiele (Standard 1 GB laeuft voll)
    hl.env("__GL_SHADER_DISK_CACHE_SIZE", "12000000000")
end

-- Wayland bevorzugen
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")

-- Flatpak-Apps im Startmenue / in der Suche
local old = os.getenv("XDG_DATA_DIRS") or ""
hl.env("XDG_DATA_DIRS", HOME .. "/.local/share/flatpak/exports/share:/var/lib/flatpak/exports/share:/usr/local/share:/usr/share:" .. old)

-- Qt/KDE-Apps (Dolphin, Kate, Ark ...): Farbschema + Stil aus KDE benutzen.
-- Ohne das fallen sie unter Hyprland auf ein helles Standard-Design zurueck.
if exists("/usr/lib/qt6/plugins/platformthemes/KDEPlasmaPlatformTheme6.so") then
    hl.env("QT_QPA_PLATFORMTHEME", "kde")
elseif exists("/usr/bin/qt6ct") then
    hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
end
hl.env("XDG_MENU_PREFIX", "plasma-")   -- Dolphin "Oeffnen mit"-Liste fuellen
