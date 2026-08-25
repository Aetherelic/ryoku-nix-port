pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import shell.services

// The shared AudioBars cava feed as a mirrored vertical waveform: a dashed spine
// with MusicBars' sideways bars stacked down it. The caller owns the feed.
Item {
    id: root

    property int bands: 42
    property bool running: true
    property real s: 1
    property color lowColor: Theme.primary
    property color highColor: Theme.tertiary
    property color axisColor: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.22)

    implicitWidth: 104 * root.s
    implicitHeight: 268 * root.s

    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.axisColor
            strokeWidth: Math.max(1, Math.round(root.s))
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [1.6, 3.2]
            capStyle: ShapePath.RoundCap
            startX: root.width / 2
            startY: 6 * root.s
            PathLine {
                x: root.width / 2
                y: root.height - 6 * root.s
            }
        }
    }

    MusicBars {
        anchors.fill: parent
        anchors.topMargin: 6 * root.s
        anchors.bottomMargin: 6 * root.s
        orient: "horizontal"
        bands: root.bands
        s: root.s
        running: root.running
        lowColor: root.lowColor
        highColor: root.highColor
    }
}
