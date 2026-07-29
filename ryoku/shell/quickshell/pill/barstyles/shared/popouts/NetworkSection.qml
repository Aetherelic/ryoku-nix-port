pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "components" as Components

Column {
    id: root

    property bool open: true
    property var networks: []
    readonly property bool wired: Network.kind === "ethernet"
    readonly property bool connected: Network.wifiConnectivity === "Connected"

    width: parent ? parent.width : 0
    spacing: 6

    function availableNetworks() {
        const seen = {};
        const output = [];
        for (const accessPoint of Network.accessPoints) {
            if (!accessPoint || !accessPoint.ssid || accessPoint.ssid === Network.activeSsid || seen[accessPoint.ssid])
                continue;
            seen[accessPoint.ssid] = true;
            output.push(accessPoint);
        }
        return output;
    }

    function refresh() {
        root.networks = root.availableNetworks();
    }

    Component.onCompleted: {
        root.refresh();
        if (Network.wifiRadio) {
            Network.refresh();
            refreshDelay.restart();
        }
    }

    Timer {
        id: refreshDelay
        interval: 1200
        onTriggered: root.refresh()
    }

    Item {
        width: parent.width
        height: 24

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "WI-FI"
            color: Theme.onSurfaceVariant
            font.family: Theme.mono
            font.pixelSize: 9
            font.letterSpacing: 1.6
            font.weight: Font.Medium
        }
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Components.IconButton {
                visible: Network.wifiRadio
                glyph: "refresh"
                onClicked: {
                    Network.refresh();
                    refreshDelay.restart();
                }
            }
            Components.IconButton {
                glyph: "wifi"
                on: Network.wifiRadio
                onClicked: Network.setWifiEnabled(!Network.wifiRadio)
            }
        }
    }

    Row {
        width: parent.width
        spacing: 8
        visible: root.connected || root.wired

        Pill.MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.wired ? "lan" : "wifi"
            font.pixelSize: 16
            color: Theme.onSurface
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 16 - disconnect.width - parent.spacing * 2

            Text {
                width: parent.width
                text: root.wired ? "Ethernet" : Network.activeSsid
                elide: Text.ElideRight
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: 11
            }
            Text {
                text: "Connected"
                color: Theme.onSurfaceVariant
                font.family: Theme.mono
                font.pixelSize: 9
            }
        }
        Pill.MaterialIcon {
            id: disconnect
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.wired
            text: "close"
            font.pixelSize: 16
            color: Theme.onSurfaceVariant
            TapHandler { onTapped: Network.disconnectWifi() }
        }
    }

    Column {
        width: parent.width
        spacing: 3
        visible: Network.wifiRadio

        Repeater {
            model: root.open ? root.networks.slice(0, 6) : []
            delegate: Components.AccessPointRow {
                required property var modelData
                width: parent.width
                accessPoint: modelData
            }
        }
        Text {
            visible: root.networks.length === 0
            width: parent.width
            text: "No networks found"
            horizontalAlignment: Text.AlignHCenter
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: 10
        }
    }
}
