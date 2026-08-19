// The qsbar dock: a cluster of frosted app islands on the screen edge opposite
// the bar, with the reactor wave flowing in the gaps between them, so it reads as
// a true twin of the bar. Full-width fixed-height strip so nothing resizes the
// window; the input mask is the island band, keeping the margins and the magnify
// headroom click-through. Layout is fixed at rest (stable reactor); magnify
// overflows the band.
import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services as Svc
import "modules"

PanelWindow {
    id: dockSlot
    required property var root

    readonly property bool atBottom: dockSlot.root.barPosition === "top"
    readonly property string dockEdge: dockSlot.atBottom ? "bottom" : "top"
    readonly property int bandHeight: dockRow.baseSize
    readonly property int edgeGap: 8
    // Room for magnified icons to rise into; collapses when magnify is off.
    readonly property int headroom: dockSlot.root.dockMagnify ? 46 : 0

    property bool ready: false
    Component.onCompleted: dockSlot.ready = true

    color: "transparent"
    visible: dockSlot.root.dockEnabled === true

    anchors {
        left: true
        right: true
        top: !dockSlot.atBottom
        bottom: dockSlot.atBottom
    }
    implicitHeight: dockSlot.bandHeight + dockSlot.edgeGap + dockSlot.headroom
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: dockSlot.visible ? dockSlot.bandHeight + dockSlot.edgeGap : 0
    WlrLayershell.namespace: "ryoku-dock"

    mask: Region {
        x: Math.round(band.x)
        y: Math.round(band.y)
        width: Math.round(band.width)
        height: Math.round(band.height)
    }

    Item {
        id: band
        width: Math.max(1, dockRow.implicitWidth)
        height: dockSlot.bandHeight
        x: Math.round((dockSlot.width - width) / 2)
        readonly property real restY: dockSlot.atBottom
            ? dockSlot.height - height - dockSlot.edgeGap
            : dockSlot.edgeGap
        y: Math.round(restY + (dockSlot.ready ? 0 : (dockSlot.atBottom ? 14 : -14)))
        opacity: dockSlot.ready ? 1 : 0
        Behavior on y { enabled: !Svc.Perf.reduceMotion; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        Behavior on opacity { enabled: !Svc.Perf.reduceMotion; NumberAnimation { duration: 220 } }

        ReactorLayer {
            anchors.fill: parent
            z: 0
            theme: dockSlot.root
            monitor: dockSlot.screen ? dockSlot.screen.name : ""
            shellVisible: dockSlot.visible
            gapInset: 0
            pillRects: dockRow.pillRects
        }

        DockRow {
            id: dockRow
            anchors.fill: parent
            z: 1
            theme: dockSlot.root
            edge: dockSlot.dockEdge
            reservedDepth: dockSlot.bandHeight + dockSlot.edgeGap
        }
    }
}
