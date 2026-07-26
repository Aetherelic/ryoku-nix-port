pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import "Singletons"

// One OSD: an icon and a value bar, for volume-out, mic-in, or brightness. There
// is deliberately NO show or hide animation (contract 12 sec 5) -- the hosting
// window maps the instant `flashing` turns true and unmaps the instant the
// 1000 ms hold elapses; a re-trigger just restarts that hold. Volume and mic
// read PipeWire; brightness reads the daemon `osd` feed. Triggers arriving in
// the startup-settle window are ignored so device enumeration never flashes the
// OSD (Ryoku's arm window stands in for the reference per-OSD shown_count: the
// PipeWire startup change-event count is not fixed the way the reference's
// watch-stream is, so a time window is the robust equivalent).
Item {
    id: root

    required property real s
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

    // Bucket -> Material Symbols icon, muted winning, on the reference
    // thresholds (contract 12 sec 3): audio >66 high, >33 medium, >0 low, else
    // muted; brightness >66 high, >33 medium, else low. Material Symbols carries
    // no microphone-sensitivity levels, so mic collapses to on/off (documented
    // divergence, matching the rail's audio-input glyph).
    readonly property string iconName: {
        var pct = Math.round(value * 100);
        if (isBrightness)
            return pct > 66 ? "brightness_high" : pct > 33 ? "brightness_medium" : "brightness_low";
        if (isMic)
            return (muted || pct <= 0) ? "mic_off" : "mic";
        if (muted)
            return "volume_off";
        return pct > 66 ? "volume_up" : pct > 33 ? "volume_down" : pct > 0 ? "volume_mute" : "volume_off";
    }

    // --- flash state machine (no animation) --------------------------------
    property bool armed: false
    property bool flashing: false

    function flash() {
        if (!armed || suppressed)
            return;
        flashing = true;
        hideTimer.restart();
    }

    onSuppressedChanged: if (suppressed) {
        hideTimer.stop();
        flashing = false;
    }

    // Startup-settle window: ignore triggers until the shell has enumerated
    // devices, so no OSD flashes at login.
    Timer {
        interval: Motion.startupReveal
        running: true
        onTriggered: root.armed = true
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
    // Inner box width 300, spacing 20, icon 48; the bar fills the remainder.
    implicitWidth: 300 * root.s
    implicitHeight: 48 * root.s

    MaterialIcon {
        id: glyph
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 48 * root.s
        height: 48 * root.s
        font.pixelSize: 48 * root.s
        text: root.iconName
        color: Theme.onSurface
    }

    // ok-progress-bar: trough (primary-container) + highlight (on-primary-
    // container), min-height 8, radius 8, thumb hidden.
    Rectangle {
        id: trough
        anchors.left: glyph.right
        anchors.leftMargin: 20 * root.s
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: 8 * root.s
        radius: Theme.radiusWidget
        color: Theme.primaryContainer

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * root.value
            radius: parent.radius
            color: Theme.onPrimaryContainer
            visible: width > 0
        }
    }
}
