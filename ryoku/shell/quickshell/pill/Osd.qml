pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import "Singletons"

// One OSD: an icon and a value bar, for volume-out, mic-in, or brightness. There
// is deliberately NO show or hide animation (contract 12 sec 5) -- the hosting
// window maps the instant `flashing` turns true and unmaps the instant the
// 1000 ms hold elapses; a re-trigger just restarts that hold. Volume and mic
// read PipeWire; brightness reads the daemon `osd` feed.
//
// Startup gate (contract 12 sec 4): the reference swallows the first two Show
// events per OSD (the device-enumeration watcher firings at login) and renders
// from the third onward, so a fresh shell never flashes for initial state syncs.
// `shownCount` reproduces that count gate exactly (it never resets, so every
// trigger after the first two shows the OSD).
Item {
    id: root

    property string kind: "volume"          // volume | mic | brightness
    property bool suppressed: false

    readonly property bool isVolume: kind === "volume"
    readonly property bool isMic: kind === "mic"
    readonly property bool isBrightness: kind === "brightness"

    // --- value and mute per kind -------------------------------------------
    readonly property var device: isVolume ? Pipewire.defaultAudioSink
        : isMic ? Pipewire.defaultAudioSource : null
    readonly property var audio: (device && device.audio) ? device.audio : null
    readonly property bool muted: audio ? audio.muted : false
    readonly property real value: isBrightness
        ? OsdFeed.brightness
        : (audio ? Math.max(0, Math.min(1, audio.volume)) : 0)

    // Bucket -> freedesktop symbolic glyph, muted winning, on the reference
    // thresholds (contract 12 sec 3): audio >66 high, >33 medium, >0 low, else
    // muted; mic identical on the microphone-sensitivity set; brightness >66
    // high, >33 medium, else low. Names are the shell's own glyph set
    // (framebars/icons), never a font.
    readonly property string iconName: {
        var pct = Math.round(value * 100);
        if (isBrightness)
            return pct > 66 ? "brightness-high" : pct > 33 ? "brightness-medium" : "brightness-low";
        if (isMic)
            return (muted || pct <= 0) ? "microphone-sensitivity-muted"
                : pct > 66 ? "microphone-sensitivity-high"
                : pct > 33 ? "microphone-sensitivity-medium"
                : "microphone-sensitivity-low";
        return (muted || pct <= 0) ? "audio-volume-muted"
            : pct > 66 ? "audio-volume-high"
            : pct > 33 ? "audio-volume-medium"
            : "audio-volume-low";
    }

    // --- flash state machine (no animation) --------------------------------
    property int shownCount: 0
    property bool flashing: false

    function flash() {
        if (suppressed)
            return;
        // Swallow the first two shows (startup device enumeration), render from
        // the third onward, mirroring the reference shown_count gate.
        if (shownCount > 1) {
            flashing = true;
            hideTimer.restart();
        } else {
            shownCount += 1;
        }
    }

    onSuppressedChanged: if (suppressed) {
        hideTimer.stop();
        flashing = false;
    }

    // The 1000 ms auto-hide hold, restarted on every value change.
    Timer {
        id: hideTimer
        interval: Motion.osdHide
        onTriggered: root.flashing = false
    }

    // Audio triggers: any volume or mute change on the tracked default device.
    PwObjectTracker { objects: root.device ? [root.device] : [] }
    Connections {
        target: root.audio
        function onVolumesChanged() { root.flash(); }
        function onMutedChanged() { root.flash(); }
    }
    // Brightness trigger: the daemon feed bumps its sequence on each change.
    Connections {
        target: root.isBrightness ? OsdFeed : null
        function onBrightnessSeqChanged() { root.flash(); }
    }

    // --- content: icon + value bar (contract 12 sec 2) ---------------------
    // Fixed logical px, matching the reference exactly: inner box width 300,
    // spacing 20, icon 48, bar min-height 8. No monitor or font scaling -- the
    // reference OSD is a fixed-size readout.
    implicitWidth: 300
    implicitHeight: 48

    SymbolIcon {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        name: root.iconName
        size: 48
        color: Theme.onSurface
    }

    // Value bar: trough (surfaceContainerLow) + fill (secondary), min-height 8,
    // radius 8, thumb hidden. The live-reference palette resolves these tokens to
    // trough #1a1d1f and fill #a8adb0 under the Solitude defaults.
    Rectangle {
        id: trough
        anchors.left: glyph.right
        anchors.leftMargin: 20
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 8
        radius: Theme.radiusWidget
        color: Theme.surfaceContainerLow

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.value
            radius: parent.radius
            color: Theme.secondary
            visible: width > 0
        }
    }
}
