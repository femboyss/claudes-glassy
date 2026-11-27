-- claudes-glassy: Look (SUPER+I -> Glassy -> Look) jenseits der Tastenkuerzel
--   windows: Titelleisten mit Minimieren / Maximieren / Schliessen (Plugin hyprbars),
--            freie Fenster wie bei Windows, keine Luecken, 8px-Ecken, duenner Rahmen,
--            Win+Pfeile docken an, Minimieren + Wiederherstellen ueber die Taskleiste
--   mac:     Titelleisten mit roten / gelben / gruenen Knoepfen links, Titel mittig,
--            freie Fenster, 10px-Ecken, grosse weiche Schatten
--   linux:   nichts davon (Plugin wird nicht geladen -> Hyprland entlaedt es)
-- Plugin: ~/.local/share/glassy/plugins/hyprbars.so (glassy --plugins baut es passend
-- zu deinem Hyprland) oder /usr/lib/libhyprbars.so (AUR: hyprland-plugin-hyprbars)

local GEN = GLASSY_GEN or {}
local PLATFORM = GEN.platform or "linux"
local HOME = os.getenv("HOME")
local errors = {}
local function try(label, fn)
    local ok, err = pcall(fn)
    if not ok then table.insert(errors, label .. ": " .. tostring(err)) end
end

-- WICHTIG: hl.plugin.load ist eine Erklaerung ("gehoert zur Config"), keine einmalige Aktion.
-- Es muss bei JEDEM Laden der Config aufgerufen werden. Laesst man es weg, entlaedt Hyprland
-- das Plugin und laedt die Config neu -> naechster Durchlauf laedt es wieder -> Endlosschleife
-- (Hyprland friert ein). Im Linux-/Mac-Look einfach nicht aufrufen: dann entlaedt Hyprland es.
local function load_hyprbars()
    for _, path in ipairs({ HOME .. "/.local/share/glassy/plugins/hyprbars.so", "/usr/lib/libhyprbars.so" }) do
        if glassy_exists(path) then
            local ok, err = pcall(hl.plugin.load, path)
            if ok then return true end
            table.insert(errors, "hyprbars (" .. path .. "): " .. tostring(err))
        end
    end
    return false
end

-- Ereignisse vom letzten Laden der Config entfernen (sonst feuern sie doppelt)
if GLASSY_PLATFORM_SUBS then
    for _, sub in ipairs(GLASSY_PLATFORM_SUBS) do pcall(function() sub:remove() end) end
end
GLASSY_PLATFORM_SUBS = {}

-- Win+Pfeile (aus keybinds.lua); ausserhalb von Windows tun sie hier nichts
function glassy_win_key(dir) end
function glassy_show_desktop() end
function glassy_minimize_all() end
function glassy_restore_all() end

if PLATFORM ~= "windows" and PLATFORM ~= "mac" then
    -- hyprbars wird hier nicht geladen -> Hyprland entlaedt es selbst
    if #errors > 0 then glassy_notify("platform: " .. table.concat(errors, " | ")) end
    return
end

-------------------------------------------------
-- Aussehen: Windows 11 bzw. macOS
-------------------------------------------------
try("look", function()
    if PLATFORM == "windows" then
        hl.config({ general = {
            gaps_in = 0, gaps_out = 0, border_size = 1,
            col = { active_border = "rgba(ffffff38)", inactive_border = "rgba(ffffff14)" },
        } })
        hl.config({ decoration = {
            rounding = 8, rounding_power = 2.0, dim_inactive = false, inactive_opacity = 1.0,
            shadow = { enabled = true, range = 26, render_power = 3, offset = { 0, 8 }, color = 0x77000000 },
        } })
    else
        hl.config({ general = {
            gaps_in = 0, gaps_out = 0, border_size = 1,
            col = { active_border = "rgba(ffffff2a)", inactive_border = "rgba(ffffff12)" },
        } })
        hl.config({ decoration = {
            rounding = 10, rounding_power = 2.0, dim_inactive = false, inactive_opacity = 1.0,
            shadow = { enabled = true, range = 40, render_power = 3, offset = { 0, 14 }, color = 0x88000000 },
        } })
    end
end)

-- Menueleiste + Dock (Mac) mit Unschaerfe dahinter
if PLATFORM == "mac" then
    try("layer blur", function()
        for _, ns in ipairs({ "quickshell:macbar", "quickshell:macdock" }) do
            hl.layer_rule({ match = { namespace = ns }, blur = true })
            hl.layer_rule({ match = { namespace = ns }, ignore_alpha = 0.05 })
        end
    end)
end

-- Freie Fenster wie bei Windows / macOS (statt Kacheln)
try("float", function() hl.window_rule({ match = { class = ".*" }, float = true }) end)

-------------------------------------------------
-- Titelleiste: Titel links, Minimieren / Maximieren / Schliessen rechts
-------------------------------------------------
local MIN = [[hyprctl dispatch 'hl.dsp.window.move({ workspace = "special:minimized", follow = false })']]
local MAX = [[hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })']]
local CLOSE = [[hyprctl dispatch 'hl.dsp.window.close()']]

local BARS = load_hyprbars()   -- genau einmal pro Durchlauf aufrufen
if BARS and PLATFORM == "windows" then
    try("hyprbars", function()
        hl.config({ plugin = { hyprbars = {
            enabled = true,
            bar_height = 32,
            bar_color = "rgb(202020)",
            ["col.text"] = "rgb(ffffff)",
            bar_title_enabled = true,
            bar_text_size = 10,
            bar_text_font = "Noto Sans",
            bar_text_align = "left",
            bar_buttons_alignment = "right",
            bar_padding = 14,
            bar_button_padding = 20,
            bar_part_of_window = true,
            bar_precedence_over_border = true,
            icon_on_hover = false,
            inactive_button_color = "rgba(00000000)",
            on_double_click = MAX,
        } } })
        -- Reihenfolge: von rechts nach links
        local add = hl.plugin.hyprbars.add_button
        local clear = "rgba(00000000)"
        add({ bg_color = clear, fg_color = "rgb(ffffff)", size = 14, icon = "✕", action = CLOSE })
        add({ bg_color = clear, fg_color = "rgb(ffffff)", size = 14, icon = "☐", action = MAX })
        add({ bg_color = clear, fg_color = "rgb(ffffff)", size = 14, icon = "—", action = MIN })
    end)
elseif BARS and PLATFORM == "mac" then
    try("hyprbars", function()
        hl.config({ plugin = { hyprbars = {
            enabled = true,
            bar_height = 28,
            bar_color = "rgb(2c2c2e)",
            ["col.text"] = "rgb(d8d8dc)",
            bar_title_enabled = true,
            bar_text_size = 10,
            bar_text_font = "Noto Sans",
            bar_text_weight = "semibold",
            bar_text_align = "center",
            bar_buttons_alignment = "left",
            bar_padding = 12,
            bar_button_padding = 8,
            bar_part_of_window = true,
            bar_precedence_over_border = true,
            icon_on_hover = true,                       -- x - + erst beim Drueberfahren, wie am Mac
            inactive_button_color = "rgb(4a4a4d)",      -- graue Ampel bei inaktiven Fenstern
            on_double_click = MAX,
        } } })
        -- Reihenfolge: von links nach rechts (Schliessen, Minimieren, Zoomen)
        local add = hl.plugin.hyprbars.add_button
        local fg = "rgb(4d0000)"
        add({ bg_color = "rgb(ff5f57)", fg_color = fg, size = 12, icon = "×", action = CLOSE })
        add({ bg_color = "rgb(febc2e)", fg_color = fg, size = 12, icon = "−", action = MIN })
        add({ bg_color = "rgb(28c840)", fg_color = fg, size = 12, icon = "+", action = MAX })
    end)
end

-------------------------------------------------
-- Minimieren / Wiederherstellen
-------------------------------------------------
local function to_minimized()
    hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", follow = false }))
end

try("events", function()
    -- App will sich selbst minimieren (z. B. eigener Knopf in Firefox)
    table.insert(GLASSY_PLATFORM_SUBS, hl.on("window.minimize", function(w) to_minimized() end))
    -- Klick in der Taskleiste auf ein minimiertes Fenster: zurueck auf den aktuellen Workspace
    table.insert(GLASSY_PLATFORM_SUBS, hl.on("window.active", function(w)
        if not w or not w.workspace then return end
        if not tostring(w.workspace.name or ""):find("minimized") then return end
        local m = hl.get_active_monitor()
        local ws = m and m.active_workspace
        if not ws then return end
        hl.dispatch(hl.dsp.window.move({ workspace = ws.id, follow = true }))
    end))
end)

-------------------------------------------------
-- Win+Pfeile wie bei Windows
-------------------------------------------------
local snapped = {}   -- Fenster-Adresse -> vorherige Groesse/Position (zum Wiederherstellen)

local function area(m)
    local r = m.reserved or {}
    local x = m.position.x + (r.left or 0)
    local y = m.position.y + (r.top or 0)
    local w = m.size.width / (m.scale or 1) - (r.left or 0) - (r.right or 0)
    local h = m.size.height / (m.scale or 1) - (r.top or 0) - (r.bottom or 0)
    return math.floor(x), math.floor(y), math.floor(w), math.floor(h)
end

local function place(x, y, w, h)
    hl.dispatch(hl.dsp.window.resize({ x = w, y = h }))
    hl.dispatch(hl.dsp.window.move({ x = x, y = y }))
end

function glassy_win_key(dir)
    local win = hl.get_active_window()
    local m = hl.get_active_monitor()
    if not win or not m then return end
    local maximized = (win.fullscreen or 0) ~= 0
    if dir == "up" then
        if not maximized then hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })) end
        return
    end
    if dir == "down" then
        if maximized then
            hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
        elseif snapped[win.address] then
            local s = snapped[win.address]; snapped[win.address] = nil
            place(s.x, s.y, s.w, s.h)
        else
            to_minimized()
        end
        return
    end
    -- Beim Wegziehen eines angedockten Fensters: alte Groesse zurueck, Position bleibt (wie Windows)
    if dir == "unsnap" then
        local s = snapped[win.address]
        if s then
            snapped[win.address] = nil
            hl.dispatch(hl.dsp.window.resize({ x = s.w, y = s.h }))
        end
        return
    end
    if maximized then hl.dispatch(hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })) end
    if not snapped[win.address] then
        snapped[win.address] = { x = win.at.x, y = win.at.y, w = win.size.x, h = win.size.y }
    end
    local x, y, w, h = area(m)
    local hw, hh = math.floor(w / 2), math.floor(h / 2)
    if dir == "left" then place(x, y, hw, h)
    elseif dir == "right" then place(x + w - hw, y, hw, h)
    elseif dir == "topleft" then place(x, y, hw, hh)
    elseif dir == "topright" then place(x + w - hw, y, hw, hh)
    elseif dir == "bottomleft" then place(x, y + h - hh, hw, hh)
    elseif dir == "bottomright" then place(x + w - hw, y + h - hh, hw, hh)
    end
end

-------------------------------------------------
-- Win+D (Desktop anzeigen), Win+M (alle minimieren), Win+Shift+M (alle zurueck)
-------------------------------------------------
GLASSY_DESKTOP_HIDDEN = GLASSY_DESKTOP_HIDDEN or {}

local function current_windows()
    local ws = hl.get_active_workspace()
    local out = {}
    if not ws then return out end
    for _, w in ipairs(hl.get_windows()) do
        if w.workspace and w.workspace.id == ws.id then table.insert(out, w) end
    end
    return out, ws
end

function glassy_minimize_all()
    local wins, ws = current_windows()
    if #wins == 0 then return end
    GLASSY_DESKTOP_HIDDEN = { workspace = ws.id, list = {} }
    for _, w in ipairs(wins) do
        table.insert(GLASSY_DESKTOP_HIDDEN.list, w.address)
        hl.dispatch(hl.dsp.window.move({ workspace = "special:minimized", follow = false, window = w }))
    end
end

function glassy_restore_all()
    local h = GLASSY_DESKTOP_HIDDEN
    if not h or not h.list then return end
    for _, addr in ipairs(h.list) do
        local w = hl.get_window("address:" .. addr)
        if w then hl.dispatch(hl.dsp.window.move({ workspace = h.workspace, follow = false, window = w })) end
    end
    GLASSY_DESKTOP_HIDDEN = {}
end

function glassy_show_desktop()
    if #current_windows() > 0 then glassy_minimize_all() else glassy_restore_all() end
end

-------------------------------------------------
-- Fenster an den Rand ziehen = andocken (Hilfsprogramm snap.py, nur im Windows-Look)
-------------------------------------------------
if PLATFORM == "windows" then
    hl.dispatch(hl.dsp.exec_cmd("python3 " .. HOME .. "/.config/hypr/glassy/snap.py"))
end

if #errors > 0 then glassy_notify("platform: " .. table.concat(errors, " | ")) end
