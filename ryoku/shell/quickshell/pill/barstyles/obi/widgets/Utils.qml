import QtQuick
import "../../../Singletons"

// Obi recording indicator: a pulsing dot and REC label, shown only while a
// screen or audio capture is running. Display only.
Row {
    id: root
    spacing: 4
    visible: Recorder.anyActive

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 8
        height: 8
        radius: 4
        color: Theme.error

        SequentialAnimation on opacity {
            running: root.visible && !Motion.reduce
            loops: Animation.Infinite
            NumberAnimation { to: 0.35; duration: 620; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "REC"
        color: Theme.error
        font.family: Theme.mono
        font.pixelSize: Theme.fontSm
    }
}
