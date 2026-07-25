// Refcount step for a menu that shares a poller (e.g. Toggles.watchers): given
// the last watched state and the current open state, report the new watched
// state and the delta to apply. Idempotent, so opening or closing a menu twice
// never leaks a duplicate background scan.

function watchDelta(watching, active) {
    var on = active === true;
    if (on === (watching === true)) return { watching: on, delta: 0 };
    return { watching: on, delta: on ? 1 : -1 };
}

if (typeof module !== "undefined" && module.exports) module.exports = { watchDelta };
