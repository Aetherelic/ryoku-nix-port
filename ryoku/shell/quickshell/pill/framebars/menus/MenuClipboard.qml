import QtQuick
import Quickshell
import Quickshell.Io
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property real s
    required property bool open
    signal requestClose()

    implicitWidth: 320 * s
    implicitHeight: title.implicitHeight + 36 * s

    Text {
        id: title
        anchors.left: parent.left
        anchors.right: parent.right
        text: "Clipboard history"
        color: Theme.bright
        font.family: Theme.display
        font.pixelSize: 18 * root.s
    }
    Text {
        anchors.left: parent.left
        anchors.top: title.bottom
        anchors.topMargin: 10 * root.s
        text: root.open ? "Choose an entry from cliphist" : ""
        color: Theme.dim
        font.family: Theme.font
        font.pixelSize: 11 * root.s
    }
    Process {
        id: cliphist
        command: ["cliphist", "list"]
        running: root.open
    }
}
