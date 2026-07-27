pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Thin reader of the daemon palette for the visualiser. The theme daemon is the
// sole author of colour in Ryoku: a fixed named theme publishes its palette into
// shell.json's themePalette key, and follow-the-wallpaper mode writes the live
// palette to ~/.cache/wallust/colors.json. This reads both and resolves each
// role exactly the way the pill's Theme does -- a named scheme wins, then the
// live wallpaper palette, then the compiled default -- so the spectrum retints
// on ANY scheme change, static named theme or wallpaper-follow, with no colour
// math of its own. The compiled defaults (Everforest) only paint the first
// frames before the daemon's first write.
Singleton {
    id: root

    // The follow-the-wallpaper master (theme.json, the single colour source the
    // daemon and window borders also read).
    property bool matchWallpaper: false

    // The static named scheme's palette (shell.json themePalette; null for the
    // dynamic Default/Wallpaper variants) and the live wallpaper roles
    // (colors.json). Both are parsed straight from the file text: half the role
    // names start with "on", which JsonAdapter's signal-handler grammar rejects,
    // a removed themePalette key only reads as absent from raw text, and a bare
    // JsonAdapter does not repopulate reliably for a lazily-created singleton.
    property var namedScheme: null
    property var wall: ({})

    // A palette value is only usable when it is a non-empty hex string; a null,
    // missing or half-written role falls through to the next layer, so a partial
    // colors.json (mid-write) or a scheme missing a role never paints black.
    function usable(v) { return typeof v === "string" && v.length > 0; }

    // Resolve one role through the layer chain: a selected named scheme wins,
    // then the live wallpaper palette while Match wallpaper is on, then the base.
    function role(key, base) {
        if (namedScheme && usable(namedScheme[key]))
            return namedScheme[key];
        if (matchWallpaper && usable(wall[key]))
            return wall[key];
        return base;
    }

    // The accent leads: Material accent roles consumed verbatim (the daemon
    // already curates them for contrast). accent is the lead the floor glow and
    // oscilloscope trace paint with.
    readonly property color accent:    role("primary",   "#a7c080")
    readonly property color secondary: role("secondary", "#7fbbb3")
    readonly property color tertiary:  role("tertiary",  "#83c092")
    readonly property color err:       role("error",     "#e67e80")

    // Ordered low->high sweep the bars sample with colorAt(t): the palette's
    // accent roles laid end to end, so every band is a system colour and the
    // whole spectrum re-tunes when the palette changes.
    readonly property var stops: [accent, tertiary, secondary, err, tertiary, accent]

    // linear-interp the ramp at t in [0,1].
    function colorAt(t) {
        var s = root.stops;
        var n = s.length;
        if (n === 0)
            return root.accent;
        if (n === 1)
            return s[0];
        var x = Math.max(0, Math.min(0.999999, t)) * (n - 1);
        var i = Math.floor(x);
        var f = x - i;
        var a = s[i];
        var b = s[i + 1];
        return Qt.rgba(a.r + (b.r - a.r) * f,
                       a.g + (b.g - a.g) * f,
                       a.b + (b.b - a.b) * f, 1);
    }

    function refreshWall() {
        try {
            const t = wallFile.text();
            root.wall = t && t.length ? (JSON.parse(t) || {}) : {};
        } catch (e) {
            root.wall = {};
        }
    }
    function refreshNamed() {
        var pal = null;
        try {
            const t = shellFile.text();
            if (t) {
                const o = JSON.parse(t);
                if (o && typeof o.themePalette === "object" && o.themePalette !== null)
                    pal = o.themePalette;
            }
        } catch (e) {
            pal = null;
        }
        root.namedScheme = pal;
    }
    function refreshMatch() {
        try {
            const t = themeFile.text();
            const o = t ? JSON.parse(t) : null;
            root.matchWallpaper = !!(o && o.followWallpaper);
        } catch (e) {
            root.matchWallpaper = false;
        }
    }

    FileView {
        id: wallFile
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/wallust/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refreshWall()
    }
    FileView {
        id: shellFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refreshNamed()
    }
    FileView {
        id: themeFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/theme.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refreshMatch()
    }

    Component.onCompleted: {
        refreshWall();
        refreshNamed();
        refreshMatch();
    }
}
