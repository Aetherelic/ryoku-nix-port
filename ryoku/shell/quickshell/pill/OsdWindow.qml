pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

// One OSD window (contract 12 sec 1/2): a small overlay layer surface anchored
// to the bottom edge, pushed up a fixed 200 px, shown on every monitor. `kind`
// selects volume-out, mic-in, or brightness; three of these are mapped per
// screen. Exclusive zone 0 (reserves nothing, respects other layers), never
// takes focus, click-through. It maps only while the OSD flashes; there is no
// show or hide animation.
//
// Placement: the surface is anchored left+right+bottom with exclusive zone 0, so
// the compositor clamps it to the desktop HOLE between the frame's bar reserves
// (spanning reserveLeft .. output-reserveRight). The box is then simply centred
// in that surface, which lands it on the hole centre the reference OSD uses
// (measured y=997 bottom edge, hole-centred, on the 1200 reference), with no
// manual reserve arithmetic.
//
// Size is FIXED logical px (icon 48, padding 20, inner box 300, margin 200),
// scaled only by the accessibility font scale -- never by monitor height. The
// reference OSD is a fixed-size window that does not grow with the output, so a
// monitor-proportional scale would oversize it.
PanelWindow {
    id: win

    required property var modelData
    required property string kind
    readonly property real pad: 20

    // This monitor's visible workspace holds a fullscreen window: the whole
    // shell hides then, so the OSD stays down too. Shares the hyprctl-backed
    // Fullscreen map with the pill.
    readonly property bool monFullscreen: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === (modelData ? modelData.name : ""))
                return mons[i].activeWorkspace ? (Fullscreen.byWs[mons[i].activeWorkspace.id] === true) : false;
        return false;
    }

    screen: modelData
    visible: osd.flashing
    color: "transparent"
    // Exclusive zone 0: reserve nothing, but respect other layers' zones
    // (contract 12 sec 1). ExclusionMode.Ignore would request -1 instead.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-osd"

    // Span the desktop hole (compositor clamps to it), pinned 200 px up.
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    margins.bottom: 200

    implicitHeight: osd.implicitHeight + win.pad * 2

    // The surface material: warm surface fill + hairline border, rounded like a
    // small panel, centred on the desktop hole. Static opacity, never animated
    // (contract 12 sec 5).
    Rectangle {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        width: osd.implicitWidth + win.pad * 2
        height: parent.height
        radius: Theme.radiusWindow
        color: Theme.surface
        opacity: Theme.windowOpacity
        border.width: Theme.borderWidth
        border.color: Theme.outline
        antialiasing: true

        Osd {
            id: osd
            anchors.fill: parent
            anchors.margins: win.pad
            kind: win.kind
            suppressed: win.monFullscreen
        }
    }

    // Click-through: the OSD is a passive readout, never eats a press.
    mask: Region {}
}
