pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire

// The Atoll-only host. Launcher, Settings, workspaces, tray and power remain
// interactive; all other bar modules are display-only.
Item {
    id: bar

    required property real s
    // Base island strip height before monitor scaling.
    property real band: 0
    required property var trayWindow

    signal powerRequested(real center)


    // a wheel over the bar strip nudges the sink volume (narrated by the OSD).
    readonly property var sink: Pipewire.defaultAudioSink
    function nudgeVolume(steps) {
        if (!sink || !sink.audio)
            return;
        sink.audio.muted = false;
        sink.audio.volume = Math.max(0, Math.min(1, sink.audio.volume + steps * 0.03));
    }
    WheelHandler {
        onWheel: (w) => bar.nudgeVolume(w.angleDelta.y > 0 ? 1 : -1)
    }

    AtollBar {
        anchors.fill: parent
        s: bar.s
        band: bar.band
        trayWindow: bar.trayWindow
        onPowerRequested: (center) => bar.powerRequested(center)
    }
}
