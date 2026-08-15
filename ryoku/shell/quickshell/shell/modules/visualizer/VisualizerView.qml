pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui
import "Singletons"

// The desktop spectrum: geometry and colour only. Motion eases cava into levels,
// Ryoku.Ui.SpectrumField draws them in one GPU pass, and this decides what the
// wallpaper behind should make them look like. Eight ramp stops are lit slice by
// slice across the region the look covers, so a spectrum crossing a bright sky
// and a dark tree stays legible along its whole width.
Item {
    id: root

    readonly property string style: Config.styleId
    readonly property bool polar: field.polar

    // What the placement overlay needs: the look's box, and a colour lit for the
    // same wallpaper.
    readonly property rect boxRect: field.boxRect
    readonly property color guide: root.ramp.length > 0 ? root.ramp[root.ramp.length - 1] : "white"

    Motion {
        id: motion
        style: root.style
        active: root.visible && Config.enabled
    }

    // The region the look covers, normalised, for the wallpaper luminance map.
    readonly property real nx: Math.max(0, Math.min(1, field.passRect.x / Math.max(1, root.width)))
    readonly property real ny: Math.max(0, Math.min(1, field.passRect.y / Math.max(1, root.height)))
    readonly property real nw: Math.max(0.01, Math.min(1, field.passRect.width / Math.max(1, root.width)))
    readonly property real nh: Math.max(0.01, Math.min(1, field.passRect.height / Math.max(1, root.height)))

    readonly property real fieldLstar: Scheme.lstarAt(root.nx, root.ny, root.nw, root.nh)
    // One direction for the whole sweep: per stop, neighbours would flip between
    // near-white and near-black over a mid-tone picture.
    readonly property int fieldSide: Scheme.side(root.fieldLstar)

    readonly property var ramp: {
        var out = [];
        for (var i = 0; i < 8; i++) {
            var t = i / 7;
            // A polar look reads one tone: its stops sweep a ring, not the picture.
            var l = root.polar ? root.fieldLstar
                : (field.vertical ? Scheme.lstarAt(root.nx, root.ny + t * root.nh * 0.875, root.nw, root.nh / 8)
                                  : Scheme.lstarAt(root.nx + t * root.nw * 0.875, root.ny, root.nw / 8, root.nh));
            out.push(Scheme.colorAt(t, l, root.fieldSide));
        }
        return out;
    }

    SpectrumField {
        id: field
        anchors.fill: parent

        levels: motion.levels
        peaks: motion.peaks
        energy: motion.energy
        fade: motion.fade
        ramp: root.ramp

        style: root.style
        shape: Config.shape
        thickness: Config.thickness
        reflection: Config.reflection
        segments: Config.segments
        // Peak caps are a bar reading: on a curve or a ring they float free of
        // anything, so they are simply not offered there.
        peakCaps: Config.peaks && (root.style === "bars" || root.style === "segments")
        glow: Config.bloom
        boxX: Config.x
        boxY: Config.y
        boxW: Config.w
        boxH: Config.h
        grow: Config.grow
        spin: motion.spinDeg
    }
}
