pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"

// One of the four background reservation surfaces of the frame. It paints
// nothing and takes no input; its exclusive zone reserves the revealed bar's
// thickness plus the frame border so tiled windows clear the bar. A hidden or
// empty-collapsed bar reserves nothing, releasing the edge. Every bar and menu
// is content inside the single ryoku-frame overlay, never here. The four edges
// carry the whole screen reservation so the overlay can span the output with
// exclusiveZone -1 and still let a bar hide without unmapping the frame.
PanelWindow {
    id: frameEdge

    required property string edge          // "top" | "bottom" | "left" | "right"
    required property real reserve         // target exclusive zone in px, 0 = released
    readonly property bool horizontal: edge === "top" || edge === "bottom"

    // Reserve and surface size animate together, so a reveal slides the edge in
    // and a hide slides it out instead of snapping. It matches the measured
    // ease-out-cubic over 250 ms of the edge reservation reveal.
    property real zone: reserve
    Behavior on zone {
        NumberAnimation { duration: Motion.barReveal; easing.type: Motion.barRevealCurve }
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ryoku-frame-edge"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Math.round(zone)

    // Anchor sets from contract 01 sec 1: horizontal edges span the full width
    // (both side anchors), vertical edges span the height left by the top and
    // bottom reservations. Each edge omits only its opposite edge.
    anchors {
        top: edge !== "bottom"
        bottom: edge !== "top"
        left: edge !== "right"
        right: edge !== "left"
    }
    implicitWidth: horizontal ? 0 : Math.round(zone)
    implicitHeight: horizontal ? Math.round(zone) : 0

    // A fully released edge (zone 0) unmaps instead of committing a zero
    // thickness surface; it re-maps as soon as the reveal animates back up.
    visible: zone > 0.5

    mask: Region {}
}
