import QtQuick
import Quickshell
import "../../../Singletons"

Item {
    id: root

    property real barHeight: 40
    signal popupRequested(string name, real center, bool active, bool pinned)

    implicitWidth: content.implicitWidth
    implicitHeight: 26

    SystemClock { id: clock; precision: SystemClock.Minutes }
    TapHandler {
        onTapped: root.popupRequested("calendar",
            root.mapToItem(null, root.width / 2, root.height / 2).x, true, true)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatTime(clock.date, "HH:mm")
            color: Theme.onSurface
            font.family: Theme.mono
            font.pixelSize: Theme.fontMd
            font.weight: Font.DemiBold
            font.features: ({ "tnum": 1 })
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.locale("en_US").toString(clock.date, "ddd d MMM")
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm
            font.weight: Font.Medium
        }
    }
}
