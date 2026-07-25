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

    onActiveChanged: Network.setVpnPolling(root, root.active)
    Component.onCompleted: Network.setVpnPolling(root, root.active)
    Component.onDestruction: Network.setVpnPolling(root, false)

    Pill.MaterialIcon {
        anchors.centerIn: parent
        text: Network.vpnActive ? "vpn_key" : "vpn_key_off"
        color: Theme.cream
        font.pixelSize: 18 * root.scale
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.menuRequested("network", Qt.rect(0, 0, root.width, root.height))
    }
}
