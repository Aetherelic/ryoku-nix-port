-- A hotplug redoes DPI autoscale and repaints the wallpaper. On add, login
-- alone misses the new output's scale; on remove (undock), the monitors that
-- stay keep the gone display's position, so autoscale re-lays them out from x=0
-- and re-scales -- unplugging an external no longer strands the remaining panel
-- at an offset with a blank wallpaper. The sleep 1 lets autoscale settle the
-- mode first, else awww caches the image at the wrong resolution.
local function rescale()
    hl.exec_cmd("command -v ryoku-monitor >/dev/null 2>&1 && ryoku-monitor autoscale")
    hl.exec_cmd("command -v ryoku-shell >/dev/null 2>&1 && { sleep 1; ryoku-shell wallpaper refresh; }")
end
hl.on("monitor.added", rescale)
hl.on("monitor.removed", rescale)
