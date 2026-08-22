-- Animation preset loader. The active preset name (plain text in
-- ~/.config/ryoku/anim-preset, written by the Hub; default "ryoku") selects one
-- self-contained set under modules/animations/. Eye-candy presets ported from
-- dusklinux/dusky. Hub per-leaf tweaks still override on top via settings.lua.
hl.config({ animations = { enabled = true } })

local function cfg(sub)
    local base = os.getenv("XDG_CONFIG_HOME")
    if not base or base == "" then
        base = (os.getenv("HOME") or "") .. "/.config"
    end
    return base .. sub
end

local function readName()
    local f = io.open(cfg("/ryoku/anim-preset"), "r")
    if not f then
        return "ryoku"
    end
    local n = (f:read("l") or ""):gsub("%s+", "")
    f:close()
    if n == "" or not n:match("^[%w_]+$") then
        return "ryoku"
    end
    return n
end

-- probe the file so a stale name never trips Hyprland's config-error overlay
local function shipped(name)
    local f = io.open(cfg("/hypr/modules/animations/" .. name .. ".lua"), "r")
    if f then
        f:close()
        return true
    end
    return false
end

local name = readName()
if not shipped(name) then
    name = "ryoku"
end
require("modules.animations." .. name)
