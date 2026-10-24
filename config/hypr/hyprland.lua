-- ==================================================================
--   claudes-glassy (Catppuccin Glass) - Hyprland Lua Config (0.55+)
--   Aenderungen werden beim Speichern sofort neu geladen.
--   Wiki: https://wiki.hypr.land/Configuring/Start/
--
--   Die eigentliche Config liegt in ~/.config/hypr/glassy/*.lua.
--   Jedes Modul wird einzeln und abgesichert geladen: Ein Fehler in
--   einem Modul (z. B. Fensterregeln) killt NICHT die Keybinds.
--   Fehler erscheinen als Hyprland-Benachrichtigung oben rechts.
-- ==================================================================

local HOME = os.getenv("HOME")

-- Gemeinsame Einstellungen fuer alle Module
GLASSY = {
    terminal    = "kitty",
    fileManager = "dolphin",
    browser     = "firefox",
    scripts     = HOME .. "/.config/hypr/scripts",
    startmenu   = HOME .. "/.config/hypr/scripts/startmenu.sh",
    search      = HOME .. "/.config/hypr/scripts/search.sh",
    mainMod     = "SUPER",
    mainMonitor = "DP-3",
}

-- Werte aus der Einstellungs-App (SUPER+I), falls vorhanden
local SETTINGS = {}
do
    local ok, res = pcall(dofile, HOME .. "/.config/hypr/glassy-settings.lua")
    if ok and type(res) == "table" then SETTINGS = res end
end
for k, v in pairs(SETTINGS.apps or {}) do GLASSY[k] = v end

local function load_module(name)
    local path = HOME .. "/.config/hypr/glassy/" .. name .. ".lua"
    local ok, err = pcall(dofile, path)
    if not ok then
        local msg = "glassy/" .. name .. ".lua: " .. tostring(err)
        print("[claudes-glassy] " .. msg)
        pcall(function()
            hl.notification.create({ text = msg, timeout = 15000 })
        end)
    end
end

-- Keybinds zuerst, damit du selbst bei Fehlern woanders bedienen kannst
load_module("keybinds")
load_module("monitors")
load_module("env")
load_module("look")
load_module("animations")
load_module("rules")
load_module("autostart")

-- Einstellungen aus der App zuletzt anwenden (ueberschreiben die Standardwerte)
if SETTINGS.config then
    local ok, err = pcall(hl.config, SETTINGS.config)
    if not ok then
        pcall(function() hl.notification.create({ text = "glassy-settings.lua: " .. tostring(err), timeout = 15000 }) end)
    end
end
if SETTINGS.border_anim == false then
    pcall(hl.animation, { leaf = "borderangle", enabled = false })
end

-- Eigene Ergaenzungen (wird bei Updates nicht ueberschrieben)
local custom = HOME .. "/.config/hypr/custom.lua"
local f = io.open(custom, "r")
if f then
    f:close()
    local ok, err = pcall(dofile, custom)
    if not ok then
        pcall(function() hl.notification.create({ text = "custom.lua: " .. tostring(err), timeout = 15000 }) end)
    end
end
