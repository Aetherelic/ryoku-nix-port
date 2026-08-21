// Framework-free keypress stack and placement policy, shared by QML and Node tests.

function sameKeys(a, b) {
    if (!a || !b || a.length !== b.length)
        return false;
    for (var i = 0; i < a.length; i++) {
        if (a[i] !== b[i])
            return false;
    }
    return true;
}

function addChord(rows, keys, repeat, now) {
    var out = rows ? rows.slice() : [];
    if (!keys || keys.length === 0)
        return out;
    var last = out.length > 0 ? out[out.length - 1] : null;
    if (last && sameKeys(last.keys, keys) && (repeat || now - last.time <= 650)) {
        out[out.length - 1] = {
            keys: keys.slice(),
            count: (last.count || 1) + 1,
            time: now
        };
        return out;
    }
    out.push({ keys: keys.slice(), count: 1, time: now });
    if (out.length > 3)
        out = out.slice(out.length - 3);
    return out;
}

function releaseChords(rows, keys, now) {
    var out = rows ? rows.slice() : [];
    for (var i = 0; i < out.length; i++) {
        var row = out[i];
        if (row.held !== true || !sameKeys(row.keys, keys))
            continue;
        var released = {};
        for (var field in row)
            released[field] = row[field];
        released.time = now;
        released.held = false;
        out[i] = released;
    }
    return out;
}

function expireChords(rows, now, hold) {
    var out = [];
    for (var i = 0; i < rows.length; i++) {
        if (rows[i].held === true || now - rows[i].time < hold)
            out.push(rows[i]);
    }
    return out;
}

function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value));
}

function clampTopLeft(x, y, width, height, screenWidth, screenHeight, padding) {
    return {
        x: clamp(x, padding, Math.max(padding, screenWidth - width - padding)),
        y: clamp(y, padding, Math.max(padding, screenHeight - height - padding))
    };
}

function defaultSettings() {
    return { theme: "dark", mode: "all", px: null, py: null, monitor: "" };
}

function parseSettings(text) {
    var out = defaultSettings();
    if (!text || String(text).trim().length === 0)
        return out;
    try {
        var parsed = JSON.parse(text);
        if (!parsed || typeof parsed !== "object" || Array.isArray(parsed))
            return out;
        if (parsed.theme !== undefined) {
            if (parsed.theme !== "dark" && parsed.theme !== "light")
                return out;
            out.theme = parsed.theme;
        }
        if (parsed.mode !== undefined) {
            if (parsed.mode !== "all" && parsed.mode !== "shortcuts")
                return defaultSettings();
            out.mode = parsed.mode;
        }
        var hasX = typeof parsed.px === "number" && isFinite(parsed.px);
        var hasY = typeof parsed.py === "number" && isFinite(parsed.py);
        if (hasX !== hasY || (parsed.px !== undefined && !hasX) || (parsed.py !== undefined && !hasY))
            return defaultSettings();
        if (hasX) {
            out.px = parsed.px;
            out.py = parsed.py;
            out.monitor = typeof parsed.monitor === "string" ? parsed.monitor : "";
        }
        return out;
    } catch (e) {
        return out;
    }
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { sameKeys, addChord, releaseChords, expireChords, clampTopLeft, parseSettings };
