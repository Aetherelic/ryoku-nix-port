import QtQuick
import Quickshell
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property real s
    required property bool open
    signal requestClose()

    implicitWidth: 320 * s
    implicitHeight: row.height

    Row {
        id: row
        width: parent.width
        spacing: 8 * root.s

        Repeater {
            model: [
                { label: "Screenshot", icon: "camera", action: "shot" },
                { label: Recorder.active ? "Stop" : "Record", icon: Recorder.active ? "stop" : "record", action: "record" }
            ]
            delegate: Rectangle {
                required property var modelData
                width: (row.width - row.spacing) / 2
                height: 54 * root.s
                radius: Theme.radius
                color: captureHover.hovered ? Theme.frameBg : Theme.tileBg
                border.width: 1
                border.color: Theme.border
                Column {
                    anchors.centerIn: parent
                    spacing: 4 * root.s
                    Pill.GlyphIcon {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 18 * root.s
                        height: 18 * root.s
                        name: modelData.icon
                        color: Theme.brand
                        stroke: 1.6
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.label
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 10 * root.s
                    }
                }
                HoverHandler { id: captureHover; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        if (modelData.action === "record") {
                            if (Recorder.active) Recorder.stop();
                            else Recorder.chooserOpen = true;
                        } else {
                            Quickshell.execDetached(["sh", "-c", "flock -n -o /tmp/ryoshot.lock qs -c ryoshot"]);
                        }
                        root.requestClose();
                    }
                }
            }
        }
    }
}
