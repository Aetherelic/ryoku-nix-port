pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The one place Ryoku's look is defined. Everything that draws imports this;
// nothing hardcodes a hex, a size or a duration.
//
// Colour resolves live from the daemon palette the same way the pill's Theme
// does: a fixed named colour scheme (shell.json themePalette) wins, then the
    // live wallpaper palette (~/.cache/ryoku/colors.json Material roles), then the
// compiled signature default. So every Ryoku app (the Hub, Ryowalls, ...)
// retints on ANY scheme change, a named theme or a wallpaper switch, with no
// colour math of its own. The kit's role names are kept; only their source moved
// onto the Material roles.
Singleton {
    id: t

    // Follow-the-wallpaper master (theme.json), the static named scheme's palette
    // (shell.json themePalette; null for the dynamic variants) and the live
    // wallpaper roles (colors.json), each parsed straight from the file text: the
    // "on" role names defeat JsonAdapter's signal-handler grammar, a removed
    // themePalette key only reads as absent from raw text, and a bare adapter does
    // not repopulate reliably for a lazily-created singleton.
    property bool matchWallpaper: true
    property var namedScheme: null
    property var wall: ({})

    // A palette value is only usable when it is a non-empty hex string; a null,
    // missing or half-written role falls through to the next layer, so a partial
    // colors.json (mid-write) or a scheme missing a role never paints black.
    function usable(v) { return typeof v === "string" && v.length > 0; }

    // Resolve one Material role through the layer chain: a named scheme wins,
    // then the live wallpaper palette while Match wallpaper is on, then the base.
    function role(key, base) {
        if (namedScheme && usable(namedScheme[key]))
            return namedScheme[key];
        if (matchWallpaper && usable(wall[key]))
            return wall[key];
        return base;
    }

    // ── default signature constants (the base each role falls back to) ───────
    readonly property color defaultPaper: "#000000"
    readonly property color defaultPaperLift: "#0a0a0a"
    readonly property color defaultInk: "#cdc4ba"
    readonly property color defaultInkDim: "#b0a9a0"
    readonly property color defaultInkMuted: "#958f87"
    readonly property color defaultInkFaint: "#7a756e"

    // ── paper ────────────────────────────────────────────────────────────
    readonly property color paper: role("surface", defaultPaper)
    readonly property color paperLift: role("surfaceContainerLow", defaultPaperLift)

    // ── ink, on paper ────────────────────────────────────────────────────
    readonly property color ink: role("onSurface", defaultInk)
    readonly property color inkDim: role("onSurfaceVariant", defaultInkDim)
    readonly property color inkMuted: role("outline", defaultInkMuted)
    readonly property color inkFaint: role("outlineVariant", defaultInkFaint)

    // ── bone stock (inverted): the Material inverse-surface pair, so the light
    // plate and its dark ink keep contrast on a light OR dark theme ───────────
    readonly property color bone: role("inverseSurface", defaultInk)
    readonly property color inkOnBone: role("inverseOnSurface", "#000000")
    readonly property color inkOnBoneDim: Qt.rgba(inkOnBone.r, inkOnBone.g, inkOnBone.b, 0.62)
    readonly property color lineOnBone: Qt.rgba(inkOnBone.r, inkOnBone.g, inkOnBone.b, 0.26)

    // ── recording keycaps: fixed media stock, independent of wallpaper tint ─
    readonly property color keycapDark: "#17171a"
    readonly property color keycapLight: "#f4f2ed"
    readonly property color keycapOnDark: "#ffffff"
    readonly property color keycapOnLight: "#0d0d0f"

    // ── hairlines and tints (ink-derived, so they follow the resolved ink) ────
    readonly property color line: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.26)
    readonly property color lineSoft: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.13)
    readonly property color lineStrong: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.42)
    readonly property color tint5: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.05)   // surface hover
    readonly property color tint10: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.10)  // control hover
    readonly property color tint16: Qt.rgba(t.ink.r, t.ink.g, t.ink.b, 0.16)  // pressed

    // ── colour: sun is the live accent (the palette primary); alert stays a
    // fixed attention red so a badge always reads as an alert ─────────────────
    readonly property color sun: role("primary", "#e2342a")
    readonly property color sunDeep: Qt.darker(sun, 1.3)
    readonly property color alert: "#e2342a"

    // ── type ─────────────────────────────────────────────────────────────
    readonly property string display: "Fraunces"
    readonly property string ui: "Space Grotesk"
    readonly property string mono: "SpaceMono Nerd Font"
    readonly property string jp: "Noto Sans CJK JP"

    readonly property int fTitle: 46    // page title, Fraunces
    readonly property int fHero: 34     // a headline readout
    readonly property int fValue: 26    // a cell's value
    readonly property int fRow: 15      // a row name
    readonly property int fBody: 14
    readonly property int fSmall: 13    // descriptions
    readonly property int fMicro: 11    // tracked labels
    readonly property int fTiny: 9      // corner tags, struck defaults

    readonly property real trackLabel: 1.4   // letter-spacing for micro labels
    readonly property real trackMark: 2.2    // for eyebrows and section marks

    // ── space ────────────────────────────────────────────────────────────
    readonly property int s1: 4
    readonly property int s2: 8
    readonly property int s3: 12
    readonly property int s4: 16
    readonly property int s5: 24
    readonly property int s6: 32
    readonly property int s7: 48

    // ── geometry ─────────────────────────────────────────────────────────
    readonly property int radius: 6
    readonly property real border: 1
    readonly property int rowH: 48
    readonly property int cellH: 104
    readonly property int railW: 268
    readonly property int ctlH: 26

    // ── motion ───────────────────────────────────────────────────────────
    // Every Ryoku animation runs its duration through dur(): a global scale and a
    // reduce-motion switch (shell.json theme.motion, written by the Hub) retime
    // the whole desktop live, and accessibility can turn motion off. A raw literal
    // migrated to dur(N) keeps its exact timing at scale 1.
    property real motionScale: 1.0
    property bool reduceMotion: false
    function dur(ms) { return reduceMotion ? 0 : Math.round(ms * motionScale); }

    readonly property int snap: dur(90)     // hover, press, state flip
    readonly property int move: dur(170)    // a selector travelling
    readonly property int swap: dur(210)    // content exchanging
    readonly property int flap: dur(110)    // a value changing
    readonly property int ease: Easing.OutCubic
    readonly property int easeSnap: Easing.OutQuad

    // Material 3 expressive motion: the duration + curve vocabulary Anim selects
    // from. Durations are the Material tokens (ms at scale 1, run through dur());
    // curves are cubic beziers as easing.bezierCurve control-point lists. Ported
    // from caelestia-dots/shell (plugin Config/tokens.hpp) under its terms.
    readonly property int durSmall: dur(200)
    readonly property int durNormal: dur(400)
    readonly property int durLarge: dur(600)
    readonly property int durXl: dur(1000)
    readonly property int durFastSpatial: dur(350)
    readonly property int durDefaultSpatial: dur(500)
    readonly property int durSlowSpatial: dur(650)
    readonly property int durFastEffects: dur(150)
    readonly property int durDefaultEffects: dur(200)
    readonly property int durSlowEffects: dur(300)

    readonly property var curveStandard: [0.2, 0, 0, 1, 1, 1]
    readonly property var curveEmphasized: [0.05, 0, 0.133333, 0.06, 0.166667, 0.4, 0.208333, 0.82, 0.25, 1, 1, 1]
    readonly property var curveFastSpatial: [0.42, 1.67, 0.21, 0.9, 1, 1]
    readonly property var curveDefaultSpatial: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property var curveSlowSpatial: [0.39, 1.29, 0.35, 0.98, 1, 1]
    readonly property var curveFastEffects: [0.31, 0.94, 0.34, 1, 1, 1]
    readonly property var curveDefaultEffects: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property var curveSlowEffects: [0.34, 0.88, 0.34, 1, 1, 1]

    // ── grain ────────────────────────────────────────────────────────────
    readonly property real grainOpacity: 0.10

    // ── daemon palette readers ───────────────────────────────────────────────
    function refreshWall() {
        try {
            const txt = paletteFile.text();
            t.wall = txt && txt.length ? (JSON.parse(txt) || {}) : {};
        } catch (e) {
            t.wall = {};
        }
    }
    function refreshNamed() {
        var pal = null;
        var scale = 1.0;
        var reduce = false;
        try {
            const txt = shellFile.text();
            if (txt) {
                const o = JSON.parse(txt);
                if (o && typeof o.themePalette === "object" && o.themePalette !== null)
                    pal = o.themePalette;
                const m = o && o.theme && o.theme.motion;
                if (m) {
                    if (typeof m.scale === "number" && m.scale > 0)
                        scale = m.scale;
                    reduce = m.reduce === true;
                }
            }
        } catch (e) {
            pal = null;
        }
        t.namedScheme = pal;
        t.motionScale = scale;
        t.reduceMotion = reduce;
    }
    function refreshMatch() {
        try {
            const txt = themeFile.text();
            const o = txt ? JSON.parse(txt) : null;
            // Default ON when theme.json is absent or omits the key, matching
            // services/Config.qml and the daemon's matchWallpaperOn: a fresh box
            // follows the wallpaper. Only an explicit false locks it off.
            t.matchWallpaper = (o && typeof o.followWallpaper === "boolean") ? o.followWallpaper : true;
        } catch (e) {
            t.matchWallpaper = true;
        }
    }

    FileView {
        id: themeFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/theme.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: t.refreshMatch()
    }
    FileView {
        id: shellFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: t.refreshNamed()
    }
    FileView {
        id: paletteFile
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: t.refreshWall()
    }

    Component.onCompleted: {
        refreshWall();
        refreshNamed();
        refreshMatch();
    }
}
