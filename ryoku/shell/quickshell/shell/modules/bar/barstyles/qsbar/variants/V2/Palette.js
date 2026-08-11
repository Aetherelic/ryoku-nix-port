.pragma library

// WANTED maps the daemon's palette keys onto this shell's semantic slots, and it
// resolves each slot the desktop Scheme's way so the bar retints with the rest
// of the system rather than diverging. The theme daemon is the sole author of
// colour: a fixed named theme publishes its palette into shell.json's
// themePalette, and follow-the-wallpaper mode writes the live palette to
// ~/.cache/ryoku/colors.json. Both carry the sixteen terminal colours
// (color0..color15) and the Material roles; the semantic slots take the Material
// roles verbatim (primary is the accent the whole desktop uses, surface /
// onSurface / onSurfaceVariant are its surface ramp), and the base16 keys are
// legacy fallbacks. The remaining widget-accent slots stay on the terminal
// palette so the bar keeps its full spread of wallpaper hues. Keys are lowercase
// because parseAll folds case (Material roles arrive camelCase).
const WANTED = [
    { target: "paper",      keys: ["surface", "background", "bg"] },
    { target: "ink",        keys: ["onsurface", "foreground", "fg"] },
    { target: "color01",    keys: ["primary", "color1", "red"] },
    { target: "color02",    keys: ["color2", "green"] },
    { target: "color03",    keys: ["color3", "yellow"] },
    { target: "color04",    keys: ["color4", "blue"] },
    { target: "color05",    keys: ["color5", "magenta"] },
    { target: "color06",    keys: ["color6", "cyan"] },
    { target: "color07",    keys: ["color7", "bright_fg", "light_fg"] },
    { target: "sumi",       keys: ["onsurfacevariant", "outline", "color8", "muted", "dark_fg"] },
    { target: "accentHint", keys: ["primary", "accent"] },
];

function lowerKeys(obj) {
    const out = {};
    if (obj && typeof obj === "object")
        for (const k in obj) out[String(k).toLowerCase()] = obj[k];
    return out;
}

function parseAll(text) {
    if (!text) return {};
    try {
        const raw = JSON.parse(text);
        return (raw && typeof raw === "object") ? lowerKeys(raw) : {};
    } catch (e) {}
    return {};
}

// The fixed named theme's palette from shell.json, or null when no static theme
// is selected (the dynamic wallpaper variants). Half the Material role names
// start with "on", which a JsonAdapter's signal-handler grammar rejects, so it
// is parsed straight from the file text like the desktop Scheme does.
function parseNamed(shellText) {
    try {
        const o = JSON.parse(shellText || "");
        if (o && typeof o.themePalette === "object" && o.themePalette !== null)
            return lowerKeys(o.themePalette);
    } catch (e) {}
    return null;
}

// The follow-the-wallpaper master from theme.json. Default ON when the file is
// absent or omits the key, matching the daemon's matchWallpaperOn and the
// desktop Scheme: only an explicit false locks the wallpaper palette out.
function parseFollow(themeText) {
    try {
        const o = themeText ? JSON.parse(themeText) : null;
        return (o && typeof o.followWallpaper === "boolean") ? o.followWallpaper : true;
    } catch (e) {}
    return true;
}

function validColor(value) {
    return typeof value === "string" && /^#([0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$/.test(value);
}

function pick(source, keys) {
    if (!source) return null;
    for (let j = 0; j < keys.length; j++)
        if (validColor(source[keys[j]])) return source[keys[j]];
    return null;
}

function mapKeys(raw) {
    const out = {};
    if (!raw) return out;
    for (let i = 0; i < WANTED.length; i++) {
        const v = pick(raw, WANTED[i].keys);
        if (v) out[WANTED[i].target] = v;
    }
    return out;
}

function parse(text) {
    return mapKeys(parseAll(text));
}

function setColor(theme, key, value) {
    if (validColor(value)) theme[key] = value;
}

// Write a parsed palette onto a Theme.qml instance. Missing slots are left at
// their current value so a partial or malformed palette never blanks the live
// theme. Ryoku colors.json values are #RRGGBB; #RRGGBBAA is accepted too.
function apply(theme, palette) {
    if (!palette) return;
    setColor(theme, "paper",      palette.paper);
    setColor(theme, "ink",        palette.ink);
    setColor(theme, "sumi",       palette.sumi);
    setColor(theme, "color01",    palette.color01);
    setColor(theme, "color02",    palette.color02);
    setColor(theme, "color03",    palette.color03);
    setColor(theme, "color04",    palette.color04);
    setColor(theme, "color05",    palette.color05);
    setColor(theme, "color06",    palette.color06);
    setColor(theme, "color07",    palette.color07);
    setColor(theme, "accentHint", palette.accentHint);
}

// Resolve every slot through the daemon's layer chain and write it onto the
// Theme: a fixed named scheme wins, then the live wallpaper palette while
// followWallpaper is on, then the shell's compiled default (base[slot], captured
// before any daemon write). The base layer is what makes turning the wallpaper
// off revert to the shipped look instead of freezing the last wallpaper.
function applyResolved(theme, base, named, wall, follow) {
    for (let i = 0; i < WANTED.length; i++) {
        const slot = WANTED[i];
        var v = pick(named, slot.keys);
        if (!v && follow) v = pick(wall, slot.keys);
        if (!v && base) v = base[slot.target];
        setColor(theme, slot.target, v);
    }
}
