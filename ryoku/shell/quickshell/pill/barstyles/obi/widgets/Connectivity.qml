pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import "../../../Singletons"
import "../../shared" as Shared
import "../../shared/popouts" as Popouts
import "../../.." as Pill

// Obi connectivity: a Wi-Fi (or ethernet) glyph and a Bluetooth glyph in the bar,
// with a card on hover for joining Wi-Fi networks and connecting Bluetooth
// devices. Reads the shared Network + Bluetooth graphs; the UI is Obi's own.
Item {
    id: root

    implicitWidth: rowr.implicitWidth
    implicitHeight: 26
    property bool open: hostPop.shown

    readonly property bool wired: Network.kind === "ethernet"
    readonly property bool wifiConnected: Network.wifiConnectivity === "Connected"
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: !!(root.adapter && root.adapter.enabled)
    readonly property var btDevices: (root.btOn && Bluetooth.devices) ? Bluetooth.devices.values : []
    readonly property bool btConnected: {
        for (let i = 0; i < root.btDevices.length; i++)
            if (root.btDevices[i] && root.btDevices[i].connected)
                return true;
        return false;
    }

    function wifiGlyph() {
        if (root.wired)
            return "lan";
        if (!Network.wifiRadio)
            return "wifi_off";
        if (!root.wifiConnected)
            return "wifi_find";
        const l = Network.level;
        if (l >= 0.75) return "wifi";
        if (l >= 0.4) return "wifi_2_bar";
        if (l >= 0.15) return "wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 9

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3
            Pill.MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: root.wifiGlyph()
                font.pixelSize: Theme.iconSm
                color: (root.wired || root.wifiConnected) ? Theme.onSurface : Theme.onSurfaceVariant
            }
            Pill.MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                visible: Network.vpnActive
                text: "vpn_key"
                font.pixelSize: Theme.iconSm - 4
                color: Theme.onSurface
            }
        }

        Pill.MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.btConnected ? "bluetooth_connected" : (root.btOn ? "bluetooth" : "bluetooth_disabled")
            font.pixelSize: Theme.iconSm
            color: root.btConnected ? Theme.onSurface : Theme.onSurfaceVariant
        }
    }

    Shared.Popout {
        id: hostPop
        target: root
        targetHovered: hh.hovered
        namespace: "ryoku-obi-popout"
        content: popContent
    }

    Component {
        id: popContent
        Popouts.ConnectivityPopout { open: root.open }
    }
}
