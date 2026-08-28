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

    // The instance this surface paints. Every per-viz knob is read from here, so
    // one draw path serves the primary and each extra visualiser alike.
    required property VizItem cfg

    readonly property string style: root.cfg.styleId
    readonly property bool polar: field.polar

    // What the placement overlay needs: the look's box, and a colour lit for the
    // same wallpaper.
    readonly property rect boxRect: field.boxRect
    readonly property color guide: root.ramp.length > 0 ? root.ramp[root.ramp.length - 1] : "white"

    Motion {
        id: motion
        cfg: root.cfg
        style: root.style
        active: root.visible && Config.enabled
    }

    // Normalised for the wallpaper luminance map: a turned look sits on a different
    // patch of picture than its box does.
    readonly property real nx: Math.max(0, Math.min(1, field.coverRect.x / Math.max(1, root.width)))
    readonly property real ny: Math.max(0, Math.min(1, field.coverRect.y / Math.max(1, root.height)))
    readonly property real nw: Math.max(0.01, Math.min(1, field.coverRect.width / Math.max(1, root.width)))
    readonly property real nh: Math.max(0.01, Math.min(1, field.coverRect.height / Math.max(1, root.height)))

    readonly property real fieldLstar: Scheme.lstarAt(root.nx, root.ny, root.nw, root.nh)
    // One direction for the whole sweep: per stop, neighbours would flip between
    // near-white and near-black over a mid-tone picture.
    readonly property int fieldSide: Scheme.side(root.fieldLstar)

    readonly property var ramp: {
        // A two-stop gradient wins: eight stops sweep from the first pinned colour
        // to the second across the spectrum, exactly as chosen, no wallpaper relight.
        if (root.cfg.gradient) {
            var g0 = root.cfg.customColor;
            var g1 = root.cfg.color2Value;
            var grad = [];
            for (var j = 0; j < 8; j++)
                grad.push(Qt.tint(g0, Qt.rgba(g1.r, g1.g, g1.b, j / 7)));
            return grad;
        }
        // A single pinned colour is respected exactly: the same gentle bass->treble
        // walk the wallpaper ramp uses, but no re-lighting against the picture.
        if (root.cfg.hasCustomColor) {
            var base = root.cfg.customColor;
            var pinned = [];
            for (var k = 0; k < 8; k++) {
                var tk = k / 7;
                var fk = 1 + (tk - 0.5) * 0.36;
                pinned.push(fk >= 1 ? Qt.lighter(base, fk) : Qt.darker(base, 1 / fk));
            }
            return pinned;
        }
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
        shape: root.cfg.shape
        thickness: root.cfg.thickness
        reflection: root.cfg.reflection
        segments: root.cfg.segments
        // cfg owns the rule, so the bar dims the switch this binding ignores.
        peakCaps: root.cfg.peaks && root.cfg.peaksApply
        glow: root.cfg.bloom
        boxX: root.cfg.x
        boxY: root.cfg.y
        boxW: root.cfg.w
        boxH: root.cfg.h
        grow: root.cfg.grow
        angle: root.cfg.angle
        tiltX: root.cfg.tiltX
        tiltY: root.cfg.tiltY
        spin: motion.spinDeg
    }
}
