pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import shell.services
import Ryoku.Ui.Singletons

// One OSD window (contract 12 sec 1/2): a small overlay layer surface anchored
// to the bottom centre, shown on every monitor. `kind` selects volume-out,
// mic-in, or brightness; three of these are mapped per screen. Exclusive zone 0
// (reserves nothing, respects other layers), never takes focus, click-through.
//
// It reads as a smooth bottom-centre popup: a compact panel fades in and slides
// up as the OSD flashes, holds, then eases back down and fades out. The window
// stays mapped through the ease-out (visible tracks the eased `prog`, not the
// raw flash), so the panel never blinks off mid-animation.
//
// The surface spans the desktop hole (compositor clamps it between the frame's
// bar reserves) and the panel is centred in it and pinned a small gap off the
// bottom, so it lands bottom-centre with no manual reserve arithmetic. Size is
// logical px, multiplied by the accessibility font scale and by this monitor's
// UI scale (shell.json displays.ui_scale, `us`).
PanelWindow {
    id: win

    required property var modelData
    required property string kind
    // Per-monitor UI scale (shell.json displays.ui_scale). Multiplies this
    // surface's own logical sizes so one monitor's OSD shrinks/grows without
    // touching the compositor scale. Default 1.0 is a byte-identical no-op.
    readonly property real us: Tokens.uiScaleFor(modelData ? modelData.name : "")
    readonly property real pad: 16 * win.us
    readonly property real osdScale: Config.barStyle === "nacre"
        ? Config.normalizedNacre.osdScale : 1
    // slide travel, and the headroom the surface keeps above the panel's rest
    // spot so the slide-up is never clipped by the surface edge.
    readonly property real slide: 18 * win.us

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

    // Eased reveal: prog 0 hidden, 1 shown. A dwell-then-hide flash retargets it
    // and the Behavior carries the panel in and out.
    property real prog: (osd.flashing && !win.monFullscreen) ? 1 : 0
    Behavior on prog { NumberAnimation { duration: Motion.effects; easing.type: Easing.OutCubic } }

    screen: modelData
    visible: win.prog > 0.01 || osd.flashing
    color: "transparent"
    // Exclusive zone 0: reserve nothing, but respect other layers' zones
    // (contract 12 sec 1). ExclusionMode.Ignore would request -1 instead.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-osd"

    // Span the desktop hole (compositor clamps to it), a small gap off the bottom.
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    margins.bottom: 24 * win.osdScale * win.us

    implicitHeight: box.height * win.osdScale + win.slide * win.osdScale

    // The panel: warm surface fill + hairline border, rounded like the sidebar
    // surfaces (radiusWindow). Opacity and a slide offset ride the eased `prog`.
    Rectangle {
        id: box
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: osd.implicitWidth + win.pad * 2
        height: osd.implicitHeight + win.pad * 2
        radius: Theme.radiusWindow * win.us
        color: Theme.surface
        opacity: Theme.windowOpacity * win.prog
        border.width: Theme.borderWidth
        border.color: Theme.outline
        antialiasing: true
        scale: win.osdScale
        transformOrigin: Item.Bottom
        transform: Translate { y: -win.prog * win.slide * win.osdScale }

        Osd {
            id: osd
            anchors.fill: parent
            anchors.margins: win.pad
            kind: win.kind
            us: win.us
            suppressed: win.monFullscreen
        }
    }

    // Click-through: the OSD is a passive readout, never eats a press.
    mask: Region {}
}
