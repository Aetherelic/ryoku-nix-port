// Deduplicate the compositor's screen list to one surface set per physical
// output. Two situations make Quickshell.screens misrepresent the real outputs:
// QtWayland briefly exposes a nameless 0x0 placeholder before any output exists,
// and a monitor re-announce (a modeset -- e.g. a GPU-accelerated app such as
// EasyEffects initialising its render context on first launch) can leave two live
// ShellScreen objects for the same physical output at once. Every per-monitor
// surface (the bar, notification popups, the OSDs, the per-screen state slices) is
// fanned across this list, so an un-deduped duplicate maps two of each -- the
// visible symptom is two stacked bars, the rest is the desktop "tweaking out".
//
// Keep the first valid occurrence of each output name: one physical output always
// maps to exactly one surface, and holding the first (stable) object keeps
// ShellState.forScreen()'s identity match consistent across every consumer.
function uniqueByName(screens) {
    var out = [];
    var seen = [];
    var count = screens ? screens.length : 0;
    for (var i = 0; i < count; i++) {
        var s = screens[i];
        if (!s || s.name === "" || !(s.width > 0) || !(s.height > 0))
            continue;
        if (seen.indexOf(s.name) !== -1)
            continue;
        seen.push(s.name);
        out.push(s);
    }
    return out;
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { uniqueByName };
