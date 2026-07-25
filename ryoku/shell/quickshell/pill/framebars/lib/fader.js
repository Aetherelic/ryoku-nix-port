// Fader value math shared by HFader and the audio frame menus: clamp to the
// 0..1 track and nudge by a signed percent. Pure so the wheel/keyboard step is
// unit-tested and every fader agrees on the bounds.

function clamp01(v) {
    return Math.max(0, Math.min(1, v));
}

function stepped(value, deltaPct) {
    return clamp01(value + deltaPct / 100);
}

if (typeof module !== "undefined" && module.exports) module.exports = { clamp01, stepped };
