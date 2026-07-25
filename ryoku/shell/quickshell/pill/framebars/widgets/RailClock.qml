import QtQuick
import Quickshell
import "../../Singletons"

Item {
    id: root

    required property string edge
    required property real scale
    signal menuRequested(string id, rect ownerRect)

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    implicitWidth: face.implicitWidth + 12 * scale
    implicitHeight: face.implicitHeight + 8 * scale

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Text {
        id: face
        anchors.centerIn: parent
        text: horizontal ? Qt.formatTime(clock.date, "HH:mm") : Qt.formatTime(clock.date, "HH\nmm")
        horizontalAlignment: Text.AlignHCenter
        color: Theme.cream
        font {
            family: Theme.font
            pixelSize: 12 * scale
            weight: Font.DemiBold
            features: ({ "tnum": 1 })
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.menuRequested("clock", Qt.rect(0, 0, root.width, root.height))
    }
}
