// Deterministic single-menu ownership: one active menu per anchor per monitor.
// State shape is { [monitor]: { [anchor]: record } }; opening at a busy anchor
// on the same monitor replaces its record, other monitors stay independent.
function cloneState(state) {
    return state && typeof state === "object" ? JSON.parse(JSON.stringify(state)) : {};
}

function valid(menu) {
    return !!menu && typeof menu.id === "string" && menu.id.length > 0
        && typeof menu.anchor === "string" && menu.anchor.length > 0;
}

function open(state, monitor, menu) {
    if (typeof monitor !== "string" || monitor.length === 0 || !valid(menu)) return state;
    const next = cloneState(state);
    if (!next[monitor]) next[monitor] = {};
    next[monitor][menu.anchor] = JSON.parse(JSON.stringify(menu));
    return next;
}

function closeAt(state, monitor, anchor) {
    if (!state || !state[monitor] || !state[monitor][anchor]) return state;
    const next = cloneState(state);
    delete next[monitor][anchor];
    return next;
}

function activeAt(state, monitor, anchor) {
    if (!state || !state[monitor] || !state[monitor][anchor]) return null;
    return state[monitor][anchor];
}

if (typeof module !== "undefined" && module.exports) module.exports = { open, closeAt, activeAt };
