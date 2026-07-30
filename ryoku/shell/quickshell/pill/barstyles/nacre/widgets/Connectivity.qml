import QtQuick
import Quickshell.Bluetooth
import "../../../Singletons"
import "../../.." as Pill

Item {
    id: root

    property real barHeight: 40
    signal popupRequested(string name, real center, bool active, bool pinned)
    readonly property bool wired: Network.kind === "ethernet"
    readonly property bool wifiConnected: Network.wifiConnectivity === "Connected"
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool bluetoothOn: !!(root.adapter && root.adapter.enabled)
    readonly property bool bluetoothConnected: {
        const devices = root.bluetoothOn && Bluetooth.devices ? Bluetooth.devices.values : [];
        for (const device of devices)
            if (device && device.connected)
                return true;
        return false;
    }

    implicitWidth: content.implicitWidth
    implicitHeight: 26

    function wifiGlyph() {
        if (root.wired) return "lan";
        if (!Network.wifiRadio) return "wifi_off";
        if (!root.wifiConnected) return "wifi_find";
        if (Network.level >= 0.75) return "wifi";
        if (Network.level >= 0.4) return "wifi_2_bar";
        if (Network.level >= 0.15) return "wifi_1_bar";
        return "signal_wifi_0_bar";
    }

    TapHandler {
        onTapped: root.popupRequested("connectivity",
            root.mapToItem(null, root.width / 2, root.height / 2).x, true, true)
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7

        Pill.MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.wifiGlyph()
            font.pixelSize: Theme.iconSm
            color: root.wired || root.wifiConnected ? Theme.onSurface : Theme.onSurfaceVariant
        }
        Pill.MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.bluetoothConnected ? "bluetooth_connected"
                : root.bluetoothOn ? "bluetooth" : "bluetooth_disabled"
            font.pixelSize: Theme.iconSm
            color: root.bluetoothConnected ? Theme.onSurface : Theme.onSurfaceVariant
        }
    }

}
