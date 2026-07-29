const islands = ["left", "center", "right"];
const widgets = [
    "brand", "media", "activeWindow", "clock", "workspaces", "resources",
    "connectivity", "audio", "battery", "tray", "weather", "utils"
];
const ranges = {
    height: [32, 56],
    opacity: [0.45, 1],
    padding: [6, 24],
    spacing: [2, 18],
    islandGap: [6, 32]
};

function clone(value) {
    return JSON.parse(JSON.stringify(value));
}

function object(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function defaultConfig() {
    return {
        islands: {
            left: ["brand", "media", "activeWindow"],
            center: ["clock", "workspaces", "resources"],
            right: ["connectivity", "audio", "battery", "tray"]
        },
        height: 40,
        opacity: 0.82,
        padding: 12,
        spacing: 8,
        islandGap: 14,
        occupiedWorkspaces: true
    };
}

function number(value, key, fallback) {
    if (typeof value !== "number" || !isFinite(value))
        return fallback;
    const range = ranges[key];
    const clamped = Math.max(range[0], Math.min(range[1], value));
    return key === "opacity" ? clamped : Math.round(clamped);
}

function normalize(raw) {
    const source = object(raw) ? raw : {};
    const base = defaultConfig();
    const output = defaultConfig();
    const seen = {};

    for (const island of islands) {
        const supplied = object(source.islands) && Array.isArray(source.islands[island]);
        const values = supplied ? source.islands[island] : base.islands[island];
        output.islands[island] = [];
        for (const id of values) {
            if (typeof id === "string" && widgets.includes(id) && !seen[id]) {
                seen[id] = true;
                output.islands[island].push(id);
            }
        }
    }

    for (const key of Object.keys(ranges))
        output[key] = number(source[key], key, base[key]);
    output.occupiedWorkspaces = typeof source.occupiedWorkspaces === "boolean"
        ? source.occupiedWorkspaces : base.occupiedWorkspaces;
    return output;
}

function locate(config, widgetId) {
    for (const island of islands) {
        const index = config.islands[island].indexOf(widgetId);
        if (index >= 0)
            return { island, index };
    }
    return null;
}

function move(config, widgetId, sourceIsland, targetIsland, targetIndex) {
    const output = normalize(config);
    if (!widgets.includes(widgetId) || !islands.includes(targetIsland))
        return output;

    const current = locate(output, widgetId);
    if ((sourceIsland === "" && current) || (sourceIsland !== "" && (!current || current.island !== sourceIsland)))
        return output;

    let position = typeof targetIndex === "number" && isFinite(targetIndex)
        ? Math.round(targetIndex) : output.islands[targetIsland].length;
    if (current) {
        output.islands[current.island].splice(current.index, 1);
        if (current.island === targetIsland && current.index < position)
            position--;
    }
    const target = output.islands[targetIsland];
    target.splice(Math.max(0, Math.min(position, target.length)), 0, widgetId);
    return output;
}

function remove(config, widgetId) {
    const output = normalize(config);
    const current = locate(output, widgetId);
    if (current)
        output.islands[current.island].splice(current.index, 1);
    return output;
}

function setValue(config, key, value) {
    const output = normalize(config);
    if (ranges[key])
        output[key] = value;
    else if (key === "occupiedWorkspaces")
        output[key] = value;
    else
        return output;
    return normalize(output);
}

function widgetIds() {
    return widgets.slice();
}

function unused(config) {
    const output = normalize(config);
    return widgets.filter(id => locate(output, id) === null);
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { defaultConfig, normalize, move, remove, setValue, widgetIds, unused };
