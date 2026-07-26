pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Blobs
import "Singletons"

// One bar edge: a fixed-thickness band pinned to its screen edge, holding the
// three zones. It creates no surface (it is content inside the frame overlay).
// A hidden bar slides its content off the screen edge; a 1px hover strip stays
// (exposed by the overlay input mask), so pointer proximity reveals the bar as
// an overlay without re-reserving the edge (contract 02 sec 4).
Item {
    id: root

    required property string edge
    required property var rail
    required property var style
    // Reveal/reserve baseline for this edge (from the shared reveal model);
    // hover reveals the bar on top of this without touching the reserve.
    required property bool revealed
    property Component delegate: null

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real band: rail.size
    // reveal_child = revealed || hovered (contract 02 sec 4).
    readonly property bool shown: revealed || bandHover.hovered

    // Fixed-thickness band pinned to its edge, spanning the perpendicular axis.
    width: horizontal ? parent.width : band
    height: horizontal ? band : parent.height
    anchors.top: edge === "top" ? parent.top : undefined
    anchors.bottom: edge === "bottom" ? parent.bottom : undefined
    anchors.left: edge === "left" ? parent.left : undefined
    anchors.right: edge === "right" ? parent.right : undefined

    // Hover proximity over the band (only the edge strip is reachable while the
    // bar is hidden, since the overlay mask exposes just that 1px there).
    HoverHandler { id: bandHover }

    // Content slides off the screen edge when hidden and back in when shown;
    // the reveal envelope is the measured bar reveal (250 ms ease-out-cubic).
    Item {
        id: content
        width: root.width
        height: root.height
        x: (!root.horizontal && !root.shown) ? (root.edge === "left" ? -root.band : root.band) : 0
        y: (root.horizontal && !root.shown) ? (root.edge === "top" ? -root.band : root.band) : 0
        Behavior on x { NumberAnimation { duration: Motion.barReveal; easing.type: Motion.barRevealCurve } }
        Behavior on y { NumberAnimation { duration: Motion.barReveal; easing.type: Motion.barRevealCurve } }

        BlobRect {
            anchors.fill: parent
            group: root.style.group
            topLeftRadius: 0
            topRightRadius: 0
            bottomLeftRadius: 0
            bottomRightRadius: 0
            sinks: false
        }

        Row {
            visible: root.horizontal
            width: parent.width
            height: parent.height

            RailZone {
                width: parent.width / 3
                height: parent.height
                ids: root.rail.start
                horizontal: true
                align: "start"
                delegate: root.delegate
            }
            RailZone {
                width: parent.width / 3
                height: parent.height
                ids: root.rail.center
                horizontal: true
                align: "center"
                delegate: root.delegate
            }
            RailZone {
                width: parent.width / 3
                height: parent.height
                ids: root.rail.end
                horizontal: true
                align: "end"
                delegate: root.delegate
            }
        }

        Column {
            visible: !root.horizontal
            width: parent.width
            height: parent.height

            RailZone {
                width: parent.width
                height: parent.height / 3
                ids: root.rail.top
                horizontal: false
                align: "start"
                delegate: root.delegate
            }
            RailZone {
                width: parent.width
                height: parent.height / 3
                ids: root.rail.center
                horizontal: false
                align: "center"
                delegate: root.delegate
            }
            RailZone {
                width: parent.width
                height: parent.height / 3
                ids: root.rail.bottom
                horizontal: false
                align: "end"
                delegate: root.delegate
            }
        }
    }
}
