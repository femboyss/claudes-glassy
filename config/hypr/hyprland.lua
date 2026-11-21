-- ==================================================================
--   claudes-glassy 2  -  Hyprland Lua Config (0.55+)
--   Shell: Quickshell (illogical-impulse von end-4, mit Glassy-Look)
--   Aenderungen werden beim Speichern sofort neu geladen.
--   Wiki: https://wiki.hypr.land/Configuring/Start/
--
--   Aufbau:
--     ~/.config/hypr/glassy/*.lua      claudes-glassy (wird bei Updates ersetzt)
--     ~/.config/hypr/hyprland/         Teile von illogical-impulse (Skripte, Farben)
--     ~/.config/hypr/custom/*.lua      DEINE Sachen (wird nie ueberschrieben)
--     ~/.config/hypr/custom.lua        DEINE Sachen (alte Glassy-Datei, geht weiterhin)
--
--   Jedes Modul wird einzeln und abgesichert geladen: Ein Fehler in
--   einem Modul (z. B. Fensterregeln) killt NICHT die Keybinds.
--   Fehler erscheinen als Hyprland-Benachrichtigung oben rechts.
-- ==================================================================

HOME = os.getenv("HOME")
local HYPR = HOME .. "/.config/hypr"

-- Gemeinsame Einstellungen fuer alle Module
GLASSY = {
    terminal    = "kitty -1",
    fileManager = "dolphin",
    browser     = "firefox",
    qsConfig    = "ii",
    mainMod     = "SUPER",
    mainMonitor = "DP-3",
    -- F1/F2/F3 = diese Monitore (Reihenfolge wie auf dem Tisch: Mitte, links, rechts)
    monitors    = { "DP-3", "HDMI-A-1", "DP-1" },
}

local function exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end
glassy_exists = exists

local function notify(msg)
    print("[claudes-glassy] " .. msg)
    pcall(function() hl.notification.create({ text = msg, timeout = 15000 }) end)
end
glassy_notify = notify

-- Werte aus SUPER+I -> Glassy (Rahmenfarben, Rahmen-Animation, Performance-Modus)
GLASSY_GEN = {}
do
    local ok, res = pcall(dofile, HYPR .. "/glassy-generated.lua")
    if ok and type(res) == "table" then GLASSY_GEN = res end
end

local function load(path, label, optional)
    if optional and not exists(path) then return end
    local ok, err = pcall(dofile, path)
    if not ok then notify((label or path) .. ": " .. tostring(err)) end
end

local function glassy(name) load(HYPR .. "/glassy/" .. name .. ".lua", "glassy/" .. name .. ".lua") end
local function custom(name) load(HYPR .. "/custom/" .. name .. ".lua", "custom/" .. name .. ".lua", true) end

-- Hilfsfunktionen von illogical-impulse (is_file_exists, workspace_in_group ...)
load(HYPR .. "/hyprland/lib/init.lua", "hyprland/lib")

-- Keybinds zuerst, damit du selbst bei Fehlern woanders bedienen kannst
custom("variables")
glassy("keybinds")
glassy("env")
custom("env")
glassy("monitors")
load(HYPR .. "/hyprland/colors.lua", "hyprland/colors.lua", true)   -- vom Theme erzeugt
glassy("look")
glassy("animations")
glassy("performance")
glassy("rules")
glassy("autostart")

-- Deine Ergaenzungen
custom("execs")
custom("general")
custom("rules")
custom("keybinds")
load(HYPR .. "/custom.lua", "custom.lua", true)

-- nwg-displays
load(HYPR .. "/workspaces.lua", "workspaces.lua", true)
load(HYPR .. "/monitors.lua", "monitors.lua", true)

-- Aenderungen aus der Shell (Spielmodus, Einstellungen) zuletzt
load(HYPR .. "/hyprland/shellOverrides/main.lua", "shellOverrides", true)
