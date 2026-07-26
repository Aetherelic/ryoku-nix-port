import QtQuick
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property string edge
    required property real scale
    signal menuRequested(string id, rect ownerRect)

    implicitWidth: 30 * scale
    implicitHeight: 30 * scale

    Pill.MaterialIcon {
        anchors.centerIn: parent
        text: "tune"
        color: Theme.onSurface
        font.pixelSize: 19 * root.scale
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.menuRequested("quick-settings", Qt.rect(0, 0, root.width, root.height))
    }
}
