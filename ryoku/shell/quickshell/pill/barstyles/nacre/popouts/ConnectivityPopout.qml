import QtQuick
import "../../../Singletons"
import "." as Sections

Item {
    id: root

    property bool open: true

    implicitWidth: 330
    implicitHeight: content.implicitHeight + 24

    Column {
        id: content
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        Sections.NetworkSection {
            width: parent.width
            open: root.open
        }
        Rectangle {
            width: parent.width
            height: Theme.borderWidth
            color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.12)
        }
        Sections.BluetoothSection {
            width: parent.width
            open: root.open
        }
    }
}
