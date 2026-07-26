pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"

// Network entry (contract 06 sec 2.6): a RevealerRow whose inert action button
// carries the connection-status icon and whose label reports the current link;
// the reveal exposes the Wi-Fi radio toggle and the active VPN.
//
// Divergence recorded: the reference reveal also lists available access points,
// saved networks and WireGuard tunnels with connect/import flows. That needs a
// typed network topic on the Go daemon (NetworkManager state), which Ryoku does
// not yet serve; the Network singleton here is display-only and QML must not poll
// NetworkManager directly. Once a network topic exists (StateServices slice),
// the available/WG sections attach here without touching the framework.
Item {
    id: root

    property real s: 1
    property bool open: false

    implicitHeight: row.implicitHeight

    onOpenChanged: Network.setVpnPolling(root, root.open)
    Component.onCompleted: Network.setVpnPolling(root, root.open)
    Component.onDestruction: Network.setVpnPolling(root, false)

    readonly property string statusIcon: Network.kind === "ethernet" ? "lan"
        : Network.kind === "wifi" ? "wifi"
        : "wifi_off"
    readonly property string statusLabel: {
        var base = Network.kind === "ethernet" ? qsTr("Wired")
            : Network.kind === "wifi" ? qsTr("Wi-Fi")
            : qsTr("Not Connected");
        return Network.vpnActive ? base + qsTr(" (+VPN)") : base;
    }

    RevealerRow {
        id: row
        width: root.width
        actionIconName: root.statusIcon
        actionSensitive: false

        middle: RevealerRowLabel {
            anchors.fill: parent
            label: root.statusLabel
        }

        Column {
            width: parent.width
            spacing: 8

            MenuButton {
                id: wifiToggle
                width: parent.width
                minH: wifiLabel.implicitHeight + wifiToggle.pad * 2
                selected: Network.wifiRadio
                onClicked: { Toggles.toggleWifi(); Network.refresh(); }
                RevealerIconLabel {
                    id: wifiLabel
                    anchors.fill: parent
                    iconName: "wifi"
                    iconColor: wifiToggle.contentColor
                    label: Network.wifiRadio ? qsTr("Wi-Fi On") : qsTr("Wi-Fi Off")
                }
            }

            Row {
                width: parent.width
                spacing: 10
                visible: Network.vpnActive
                Pill.MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Theme.iconSm
                    height: Theme.iconSm
                    font.pixelSize: Theme.iconSm
                    text: "vpn_lock"
                    color: Theme.primary
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("VPN: %1").arg(Network.vpnName)
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm
                }
            }
        }
    }
}
