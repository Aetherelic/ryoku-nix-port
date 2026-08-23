pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// Recording / instant-replay indicator: self-hides unless a recording is live or
// a replay buffer is armed. A recording draws in the error colour (red record
// glyph); a click stops it. An armed replay draws the accent (a film glyph); a
// click saves the last seconds. The replay buffer never raises the record HUD --
// this small rail cue is its only persistent presence. Contract 04 sec 3.2.
Item {
    id: root

    required property string edge
    required property real scale

    readonly property bool recording: Recorder.active
    readonly property bool replay: Recorder.replayArmed && !Recorder.active
    readonly property bool selfShown: root.recording || root.replay
    visible: selfShown
    implicitWidth: selfShown ? btn.implicitWidth : 0
    implicitHeight: selfShown ? btn.implicitHeight : 0

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        icon: root.recording ? "record" : "film"
        iconColor: root.recording ? Theme.error : Theme.vermLit
        onClicked: root.recording ? Recorder.stop() : Recorder.saveReplay()
    }
}
