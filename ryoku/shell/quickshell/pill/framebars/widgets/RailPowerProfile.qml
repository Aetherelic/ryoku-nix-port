import QtQuick
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property string edge
    required property real scale
    required property bool active
    signal menuRequested(string id, rect ownerRect)

    implicitWidth: 30 * scale
    implicitHeight: 30 * scale

    function refresh() {
        PowerProfiles.setActive(active);
    }

    onActiveChanged: refresh()
    Component.onCompleted: refresh()
    Component.onDestruction: PowerProfiles.setActive(false)

    Timer {
        interval: 30000
        repeat: true
        running: root.active
        onTriggered: root.refresh()
    }

    Pill.MaterialIcon {
        anchors.centerIn: parent
        text: "speed"
        color: Theme.cream
        opacity: PowerProfiles.available ? 1 : 0.45
        font.pixelSize: 18 * root.scale
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.menuRequested("power-profile", Qt.rect(0, 0, root.width, root.height))
    }
}
