pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/clock.js" as Clk

/**
 * Banner face: one big, clean sans-serif time (hh:mm with AM/PM set inline and
 * small), the way NibrasShell draws its clock -- a wide, calm time that fills the
 * space and pairs with the depth effect, the cut-out subject drifting beside it.
 * The colon carries the accent; ink is picked against the wallpaper beneath, so
 * it reads on any backdrop. No shadow -- Ryoku emphasises with ink, not glow.
 */
Item {
    id: face

    property real underL: Scheme.wallLstar
    readonly property color ink: Theme.inkOn(face.underL)
    readonly property color inkDim: Theme.inkDimOn(face.underL)
    readonly property color accent: Clk.pickAccent(Config.clockAccent, Theme.accentOn(face.underL), Theme.brand, face.ink)

    readonly property var t: Clk.parts(Now.date, Config.clock24h)
    readonly property real px: Math.round(184 * Config.clockScale)
    readonly property real track: Math.round(face.px * -0.015)

    implicitWidth: row.implicitWidth
    implicitHeight: hm.implicitHeight

    Row {
        id: row
        spacing: Math.round(face.px * 0.14)

        Row {
            id: hm
            spacing: 0
            Text {
                text: face.t.hh
                color: face.ink
                font.family: Theme.font
                font.weight: Font.Bold
                font.pixelSize: face.px
                font.letterSpacing: face.track
            }
            Text {
                text: ":"
                color: face.accent
                font.family: Theme.font
                font.weight: Font.Bold
                font.pixelSize: face.px
                font.letterSpacing: face.track
            }
            Text {
                text: face.t.mm
                color: face.ink
                font.family: Theme.font
                font.weight: Font.Bold
                font.pixelSize: face.px
                font.letterSpacing: face.track
            }
        }

        // AM/PM inline and small, sitting on the time's baseline.
        Text {
            visible: !Config.clock24h
            anchors.bottom: hm.bottom
            anchors.bottomMargin: Math.round(face.px * 0.16)
            text: face.t.ampm
            color: face.inkDim
            font.family: Theme.font
            font.weight: Font.DemiBold
            font.pixelSize: Math.round(face.px * 0.2)
            font.letterSpacing: 2
        }
    }
}
