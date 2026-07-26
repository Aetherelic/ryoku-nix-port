import QtQuick
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property string edge
    required property real scale
    required property bool active
    readonly property var layouts: layoutControl.layouts
    readonly property string current: layoutControl.current
    signal menuRequested(string id, rect ownerRect)

    implicitWidth: 30 * scale
    implicitHeight: 30 * scale

    LayoutControl {
        id: layoutControl
        active: root.active
    }

    Pill.MaterialIcon {
        anchors.centerIn: parent
        text: "dashboard_customize"
        color: Theme.onSurface
        font.pixelSize: 18 * root.scale
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.menuRequested("layout-switcher", Qt.rect(0, 0, root.width, root.height))
    }
}
