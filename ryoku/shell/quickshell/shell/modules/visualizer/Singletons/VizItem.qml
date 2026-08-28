pragma ComponentBehavior: Bound
import QtQuick

// One visualiser's settings, normalised. A plain JSON object goes in as `data`
// (the primary's flat keys, or one entry of the extras list); reactive,
// defaulted, derived properties come out. The renderer (VisualizerView, Motion)
// reads a VizItem rather than the Config singleton, so one draw path serves
// every instance on the desktop. Config builds one of these for the instance
// being edited; the Visualizer surface builds one per instance it paints.
QtObject {
    id: item

    // The raw per-viz object. Missing keys fall back to the canonical defaults
    // below, so a half-written extras entry never paints black or nothing.
    property var data: ({})

    function val(key, def) {
        var d = item.data;
        return (d && d[key] !== undefined && d[key] !== null) ? d[key] : def;
    }

    // The looks the renderer knows; the polar three sit at the tail so one index
    // decides the family, and `frame` is the whole-screen edge look.
    readonly property var knownStyles: ["bars", "split", "dots", "segments", "wave",
                                        "ribbon", "curtain", "line", "frame", "radial", "orb", "spiral"]

    readonly property string rawStyle: "" + item.val("style", "bars")
    readonly property string styleId: item.knownStyles.indexOf(item.rawStyle) >= 0 ? item.rawStyle
        : (item.rawStyle === "circle" ? "orb" : "bars")
    readonly property bool isPolar: item.knownStyles.indexOf(item.styleId) >= 9
    readonly property bool peaksApply: item.styleId === "bars" || item.styleId === "segments"
        || item.styleId === "frame"
    readonly property bool mirrorApplies: !item.isPolar && item.styleId !== "frame"

    readonly property string shape:  "" + item.val("shape", "rounded")
    readonly property int bars:      Math.max(16, Math.min(128, Math.round(item.val("bars", 64))))
    readonly property real thickness: item.val("thickness", 0.58)
    readonly property real bloom:    item.val("bloom", 0.6)
    readonly property real reflection: item.val("reflection", 0.1)
    readonly property bool idleWave: item.val("idleWave", true)
    readonly property bool mirror:   item.val("mirror", false)
    readonly property int segments:  item.val("segments", 10)
    readonly property real gain:     item.val("gain", 1.0)
    readonly property real smoothing: item.val("smoothing", 0.5)
    readonly property bool peaks:    item.val("peaks", false)
    readonly property real spin:     item.val("spin", 0)

    readonly property real x:    item.val("x", 0)
    readonly property real y:    item.val("y", 0.58)
    readonly property real w:    item.val("w", 1)
    readonly property real h:    item.val("h", 0.42)
    readonly property string grow: "" + item.val("grow", "up")
    readonly property real angle: item.val("angle", 0)
    readonly property real tiltX: item.val("tiltX", 0)
    readonly property real tiltY: item.val("tiltY", 0)

    // Colour: an exact pinned #rrggbb, or "" to follow the wallpaper/theme accent.
    // A gradient adds a second stop; both must be valid hex for it to apply.
    readonly property string rawColor:  "" + item.val("color", "")
    readonly property string rawColor2: "" + item.val("color2", "")
    readonly property bool hasCustomColor: /^#[0-9a-fA-F]{6}$/.test(item.rawColor)
    readonly property bool hasColor2: /^#[0-9a-fA-F]{6}$/.test(item.rawColor2)
    readonly property color customColor: item.hasCustomColor ? item.rawColor : "#a7c080"
    readonly property color color2Value: item.hasColor2 ? item.rawColor2 : "#7fae52"
    readonly property bool gradient: item.val("gradient", false) === true
        && item.hasCustomColor && item.hasColor2
}
