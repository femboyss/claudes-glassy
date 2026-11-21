-- claudes-glassy: Performance / Lag-Fixes
-- Jede Option einzeln abgesichert: gibt es eine Option in deiner Hyprland-Version
-- nicht, wird nur diese uebersprungen.
--
-- Performance-Modus (SUPER+I -> Glassy): weniger Blur, keine Schatten, kein Dimmen,
-- kuerzere Animationen. Der Spielmodus in der Seitenleiste rechts schaltet zusaetzlich
-- alles ab, solange er an ist.

local G = GLASSY_GEN or {}
local skipped = {}

local function opt(path, value)
    -- path = "misc.vfr" -> hl.config({ misc = { vfr = value } })
    local t = value
    local parts = {}
    for p in string.gmatch(path, "[^%.]+") do table.insert(parts, p) end
    for i = #parts, 1, -1 do t = { [parts[i]] = t } end
    local ok = pcall(hl.config, t)
    if not ok then table.insert(skipped, path) end
end

-- Nur neu zeichnen, wenn sich wirklich etwas aendert (spart GPU im Leerlauf)
opt("misc.vfr", true)
-- Spiele/Videos im Vollbild direkt an den Monitor geben (weniger Latenz, kein Compositing)
-- 2 = nur fuer Inhalte, die sich als Spiel/Video melden (sicherer als 1)
opt("render.direct_scanout", 2)
-- Fenster-Vorschau beim Ziehen: kein Neuberechnen pro Mausbewegung
opt("misc.animate_mouse_windowdragging", false)
opt("misc.animate_manual_resizes", false)

if G.performance == true then
    opt("decoration.blur.passes", 1)
    opt("decoration.blur.size", 5)
    opt("decoration.blur.vibrancy", 0)
    opt("decoration.shadow.enabled", false)
    opt("decoration.dim_inactive", false)
    opt("decoration.inactive_opacity", 1.0)
    pcall(hl.animation, { leaf = "global", enabled = true, speed = 4, bezier = "default" })
    pcall(hl.animation, { leaf = "windows", enabled = true, speed = 3, bezier = "easeOutQuint" })
    pcall(hl.animation, { leaf = "windowsIn", enabled = true, speed = 3, bezier = "easeOutQuint", style = "popin 90%" })
    pcall(hl.animation, { leaf = "windowsMove", enabled = true, speed = 3, bezier = "easeOutQuint" })
    pcall(hl.animation, { leaf = "workspaces", enabled = true, speed = 3, bezier = "easeOutQuint", style = "slide" })
    pcall(hl.animation, { leaf = "borderangle", enabled = false })
end

if #skipped > 0 then
    -- Kein Fehler, nur zur Info im Log (hyprctl rollinglog)
    print("[claudes-glassy] performance: in dieser Hyprland-Version nicht vorhanden: " .. table.concat(skipped, ", "))
end
