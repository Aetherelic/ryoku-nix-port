pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Thin reader of the daemon palette for the desktop widgets. The theme daemon is
// the sole author of colour in Ryoku: a fixed named theme publishes its palette
// into shell.json's themePalette key, and follow-the-wallpaper mode writes the
// live palette to ~/.cache/ryoku/colors.json. This resolves each role the
// pill's way -- a named scheme wins, then the live wallpaper palette, then the
// compiled default -- so the clock, its card and the right-click menu retint on
// ANY scheme change (static named theme or wallpaper-follow) with no colour math
// of its own. Defaults are a cool near-black so widgets read before the daemon's
// first write. base/elevated/deep/line map onto the palette's own surface depth
// ramp; accent/accent2 are Material accent roles consumed verbatim.
Singleton {
    id: root

    // Follow-the-wallpaper master (theme.json), the static named scheme's palette
    // (shell.json themePalette; null for the dynamic variants) and the live
    // wallpaper roles (colors.json). All three are parsed straight from the file
    // text: half the role names start with "on" (which JsonAdapter's
    // signal-handler grammar rejects), a removed themePalette key only reads as
    // absent from raw text, and a bare JsonAdapter does not repopulate reliably
    // for a lazily-created singleton.
    property bool matchWallpaper: false
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

    // --- surface depth ramp (the menu plate and the clock card sit on these) --
    readonly property color surface:  role("surface", "#17161d")
    readonly property color base:     surface
    readonly property color elevated: role("surfaceContainer", "#26242d")
    readonly property color deep:     role("surfaceContainerLowest", "#0f0c07")
    readonly property color line:     role("outlineVariant", "#3d484d")

    // --- ink, resolved from the palette so text stays legible on its surface.
    // Declared plain and set via Binding: QML's signal-handler grammar parses an
    // inline `onSurface:` as a change-handler for the sibling `surface` property
    // and silently drops the binding (the transparent-black trap), so a Binding
    // element assigns the role by name instead. ---
    property color onSurface
    property color onSurfaceVariant
    Binding { target: root; property: "onSurface";        value: root.role("onSurface", "#f5f3ff") }
    Binding { target: root; property: "onSurfaceVariant"; value: root.role("onSurfaceVariant", "#9aa3c8") }

    // --- accents: Material accent roles, verbatim (the daemon curates them) ----
    readonly property color accent:    role("primary", "#e2342a")
    readonly property color accent2:   role("secondary", "#7fbbb3")
    readonly property color tertiary:  role("tertiary", "#83c092")
    readonly property color err:       role("error", "#e67e80")

    // Ordered sweep the ring clock and gradients sample with colorAt(t): the
    // palette's accent roles laid end to end, so the sweep re-tunes with the
    // theme.
    readonly property var stops: [accent, tertiary, accent2, err, tertiary, accent]

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
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/colors.json"
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
