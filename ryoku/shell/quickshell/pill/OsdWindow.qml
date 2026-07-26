pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

// One OSD window (contract 12 sec 1/2): a small overlay layer surface anchored
// to the bottom edge, pushed up a fixed 200 px, shown on every monitor. `kind`
// selects volume-out, mic-in, or brightness; three of these are mapped per
// screen. Exclusive zone 0 (reserves nothing), never takes focus, click-through.
// It maps only while the OSD flashes; there is no show or hide animation.
PanelWindow {
    id: win

    required property var modelData
    required property string kind
    readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))
    readonly property real pad: 20 * s

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
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-osd"

    anchors.bottom: true
    margins.bottom: 200 * s

    implicitWidth: osd.implicitWidth + win.pad * 2
    implicitHeight: osd.implicitHeight + win.pad * 2

    // The surface material: warm surface fill + hairline border, rounded like a
    // small panel. Static opacity, never animated (contract 12 sec 5).
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWindow
        color: Theme.surface
        opacity: Theme.windowOpacity
        border.width: Theme.borderWidth
        border.color: Theme.outline
        antialiasing: true
    }

    Osd {
        id: osd
        anchors.fill: parent
        anchors.margins: win.pad
        s: win.s
        kind: win.kind
        suppressed: win.monFullscreen
    }

    // Click-through: the OSD is a passive readout, never eats a press.
    mask: Region {}
}
