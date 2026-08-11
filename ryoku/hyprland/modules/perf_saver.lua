-- Power Saver compositor strip. The shell (shell.qml) writes the effective
-- "saver" flag to ~/.cache/ryoku/hypr-perf.json and reloads Hyprland when the
-- active power profile changes, but only while Performance's "Follow the power
-- profile" is on. hyprland.lua loads this AFTER settings.lua, so on Power Saver
-- the profile wins over the Hub's decoration tweaks and drops compositor blur and
-- shadow, the heaviest present-time GPU cost; a hand-written user.lua still wins,
-- since it loads last. A missing or unreadable cache reads false, so nothing
-- changes and blur/shadow follow the Hub and performance.json as before.
local home = os.getenv("HOME") or ""

local function saver()
  local f = io.open(home .. "/.cache/ryoku/hypr-perf.json", "r")
  if not f then return false end
  local s = f:read("*a")
  f:close()
  return s:match('"saver"%s*:%s*true') ~= nil
end

if saver() then
  hl.config({ decoration = { blur = { enabled = false }, shadow = { enabled = false } } })
end
