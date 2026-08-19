.pragma library

// Pure Hyprland key-combo helpers, shared so the Keybinds page and the Import
// page reason about shortcuts the same way, with one copy of the rules. Nothing
// here holds state or touches QML: normalisation and conflict classification are
// string work, and the chord reader turns a KeyEvent into the token binds.lua
// writes. The engine owns the authoritative norm on the wire; the UI uses these
// only to compare and to record, never to invent a key.

// normalise a combo for compare: case, spacing and modifier order collapse, so
// "SUPER + Q", "super+q" and "Q + Super" are one key.
function normKeys(s) {
    if (!s)
        return "";
    var parts = ("" + s).split("+");
    var out = [];
    for (var i = 0; i < parts.length; i++) {
        var t = parts[i].trim().toLowerCase();
        if (t.length)
            out.push(t);
    }
    out.sort();
    return out.join("+");
}

// the effective combo a shipped bind fires on: a rebind wins over the default.
function effectiveCombo(rebinds, defCombo) {
    var r = rebinds ? rebinds[defCombo] : undefined;
    return (r && r.length) ? r : defCombo;
}

// the set of normalised combos the shipped legend holds (rebinds applied), keyed
// for O(1) shadow lookups. `categories` is the `ryoku-hub keybinds` legend.
function shippedKeys(categories, rebinds) {
    var set = {};
    categories = categories || [];
    for (var c = 0; c < categories.length; c++) {
        var binds = categories[c].binds || [];
        for (var b = 0; b < binds.length; b++) {
            var k = normKeys(effectiveCombo(rebinds, binds[b].combo || ""));
            if (k.length)
                set[k] = true;
        }
    }
    return set;
}

// how many custom rows hold a given normalised combo.
function customCount(customRows, norm) {
    customRows = customRows || [];
    var n = 0;
    for (var i = 0; i < customRows.length; i++)
        if (normKeys(customRows[i].keys) === norm)
            n++;
    return n;
}

// classify custom row i: "" none, "shipped" shadows a Ryoku bind, "duplicate"
// repeats another custom one. `shipped` is a shippedKeys() set.
function rowConflict(customRows, i, shipped) {
    customRows = customRows || [];
    shipped = shipped || {};
    var k = normKeys((customRows[i] || {}).keys);
    if (!k)
        return "";
    if (shipped[k])
        return "shipped";
    return customCount(customRows, k) > 1 ? "duplicate" : "";
}

// Qt key code -> the token Hyprland binds on. Covers letters, digits, the
// function row, navigation, and the common punctuation; anything unmapped
// returns "" so the recorder keeps waiting (and the field stays typeable for
// the exotic rest).
function qtKeyName(k) {
    if (k >= Qt.Key_A && k <= Qt.Key_Z)
        return String.fromCharCode(k);
    if (k >= Qt.Key_0 && k <= Qt.Key_9)
        return String.fromCharCode(k);
    if (k >= Qt.Key_F1 && k <= Qt.Key_F12)
        return "F" + (k - Qt.Key_F1 + 1);
    switch (k) {
    case Qt.Key_Return: case Qt.Key_Enter: return "Return";
    case Qt.Key_Space: return "Space";
    case Qt.Key_Tab: return "Tab";
    case Qt.Key_Left: return "Left";
    case Qt.Key_Right: return "Right";
    case Qt.Key_Up: return "Up";
    case Qt.Key_Down: return "Down";
    case Qt.Key_Backspace: return "BackSpace";
    case Qt.Key_Delete: return "Delete";
    case Qt.Key_Home: return "Home";
    case Qt.Key_End: return "End";
    case Qt.Key_PageUp: return "Prior";
    case Qt.Key_PageDown: return "Next";
    case Qt.Key_Insert: return "Insert";
    case Qt.Key_Print: return "Print";
    case Qt.Key_Minus: return "minus";
    case Qt.Key_Equal: return "equal";
    case Qt.Key_Comma: return "comma";
    case Qt.Key_Period: return "period";
    case Qt.Key_Slash: return "slash";
    case Qt.Key_Backslash: return "backslash";
    case Qt.Key_Semicolon: return "semicolon";
    case Qt.Key_Apostrophe: return "apostrophe";
    case Qt.Key_BracketLeft: return "bracketleft";
    case Qt.Key_BracketRight: return "bracketright";
    case Qt.Key_QuoteLeft: return "grave";
    }
    return "";
}

// build the Hyprland combo from a KeyEvent: held modifiers + the main key, in
// the order binds.lua writes them. "" until a non-modifier key lands.
function chordFrom(event) {
    var name = qtKeyName(event.key);
    if (name === "")
        return "";
    var mods = [];
    if (event.modifiers & Qt.MetaModifier) mods.push("SUPER");
    if (event.modifiers & Qt.ControlModifier) mods.push("CTRL");
    if (event.modifiers & Qt.AltModifier) mods.push("ALT");
    if (event.modifiers & Qt.ShiftModifier) mods.push("SHIFT");
    mods.push(name);
    return mods.join(" + ");
}
