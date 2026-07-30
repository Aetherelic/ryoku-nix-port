pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import "../../../Singletons"
import "../../.." as Pill
import "../../shared" as Shared
import "../../nacre/popouts" as Popouts

// Obi resources: twin compact ring gauges (CPU then RAM) bound live to Sysinfo,
// each a subtle track with a monochrome fill and a tiny glyph in the centre.
// Hovering opens a popout with labelled CPU/RAM/temperature bars.
Item {
    id: root

    implicitWidth: rings.implicitWidth
    implicitHeight: 26

    // Sysinfo only polls while an owner claims it, so keep it alive on show.
    Component.onCompleted: Sysinfo.setActive(root, true)
    Component.onDestruction: Sysinfo.setActive(root, false)

    HoverHandler { id: hh }

    component RingGauge: Item {
        id: gauge

        property real value: 0
        property string glyph: ""

        readonly property real dim: 22
        readonly property real sw: 2.5

        property real anim: 0
        onValueChanged: gauge.anim = Math.max(0, Math.min(1, gauge.value))
        Component.onCompleted: gauge.anim = Math.max(0, Math.min(1, gauge.value))
        Behavior on anim {
            enabled: !Motion.reduce
            NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
        }

        implicitWidth: gauge.dim
        implicitHeight: gauge.dim

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.15)
                strokeWidth: gauge.sw
                fillColor: "transparent"
                PathAngleArc {
                    centerX: gauge.dim / 2
                    centerY: gauge.dim / 2
                    radiusX: gauge.dim / 2 - gauge.sw / 2
                    radiusY: gauge.dim / 2 - gauge.sw / 2
                    startAngle: -90
                    sweepAngle: 360
                }
            }
            ShapePath {
                strokeColor: Theme.onSurface
                strokeWidth: gauge.sw
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: gauge.dim / 2
                    centerY: gauge.dim / 2
                    radiusX: gauge.dim / 2 - gauge.sw / 2
                    radiusY: gauge.dim / 2 - gauge.sw / 2
                    startAngle: -90
                    sweepAngle: 360 * gauge.anim
                }
            }
        }

        Pill.MaterialIcon {
            anchors.centerIn: parent
            text: gauge.glyph
            color: Theme.onSurfaceVariant
            font.pixelSize: 11
        }
    }

    Row {
        id: rings
        anchors.centerIn: parent
        spacing: 8

        RingGauge { value: Sysinfo.cpu; glyph: "memory" }
        RingGauge { value: Sysinfo.mem; glyph: "memory_alt" }
    }

    Shared.Popout {
        target: root
        targetHovered: hh.hovered
        namespace: "ryoku-obi-popout"
        content: popContent
    }

    Component {
        id: popContent
        Popouts.ResourcesPopout {}
    }
}
