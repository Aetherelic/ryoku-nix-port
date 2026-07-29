import QtQuick
import Quickshell
import "../../../Singletons"

Item {
    implicitWidth: content.implicitWidth + 40
    implicitHeight: content.implicitHeight + 36

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Column {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.onSurface
            font.family: Theme.mono
            font.pixelSize: Theme.fontXxl
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "dddd")
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontLg
            font.weight: Font.Bold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.formatDateTime(clock.date, "d MMMM yyyy")
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm
        }
    }
}
