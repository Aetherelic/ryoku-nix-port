pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import "../../../Singletons"
import "../../.." as Pill
import "components" as Components

Column {
    id: root

    property bool open: true
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: !!(root.adapter && root.adapter.enabled)
    readonly property var devices: root.enabled && Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var visibleDevices: {
        const known = root.devices.filter(device => device && (device.paired || device.bonded));
        const found = root.adapter && root.adapter.discovering
            ? root.devices.filter(device => device && !(device.paired || device.bonded) && device.name && device.name.length > 0)
            : [];
        known.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0));
        return known.concat(found);
    }

    width: parent ? parent.width : 0
    spacing: 6

    component DeviceRow: Item {
        id: row

        required property var device
        property bool busy: false
        readonly property bool connected: !!(row.device && row.device.connected)

        width: parent ? parent.width : 0
        height: 30

        Process { id: pairProcess; onExited: row.busy = false }

        function activate() {
            if (!row.device)
                return;
            if (row.device.connected) {
                row.device.disconnect();
                return;
            }
            if (row.device.paired || row.device.bonded) {
                row.device.connect();
                return;
            }
            row.busy = true;
            pairProcess.command = [
                "sh", "-c",
                "timeout 30 bluetoothctl pair \"$1\" && bluetoothctl trust \"$1\" && timeout 30 bluetoothctl connect \"$1\"",
                "sh", row.device.address
            ];
            pairProcess.running = false;
            pairProcess.running = true;
        }

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: hover.hovered
                ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                : "transparent"
        }
        Pill.GlyphIcon {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 15
            height: 15
            name: BtLink.glyphFor(row.device)
            stroke: 1.6
            color: row.connected ? Theme.onSurface : Theme.onSurfaceVariant
        }
        Text {
            anchors.left: icon.right
            anchors.leftMargin: 8
            anchors.right: metadata.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: BtLink.label(row.device)
            elide: Text.ElideRight
            color: row.connected ? Theme.onSurface : Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: 11
            font.weight: row.connected ? Font.DemiBold : Font.Normal
        }
        Row {
            id: metadata
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: BtLink.batteryLevel(row.device) >= 0
                text: BtLink.batteryLevel(row.device) + "%"
                color: Theme.onSurfaceVariant
                font.family: Theme.mono
                font.pixelSize: 9
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: row.busy ? "..." : row.connected ? "Disconnect"
                    : row.device && (row.device.paired || row.device.bonded) ? "Connect" : "Pair"
                color: row.connected ? Theme.onSurfaceVariant : Theme.primary
                font.family: Theme.mono
                font.pixelSize: 9
            }
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: row.activate() }
    }

    Item {
        width: parent.width
        height: 24

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "BLUETOOTH"
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
                visible: root.enabled
                glyph: "refresh"
                on: !!(root.adapter && root.adapter.discovering)
                onClicked: BluetoothDiscovery.setDiscovering(root, root.adapter, !(root.adapter && root.adapter.discovering))
            }
            Components.IconButton {
                glyph: "bluetooth"
                on: root.enabled
                onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
            }
        }
    }

    Text {
        visible: !root.enabled
        width: parent.width
        text: "Bluetooth is off"
        horizontalAlignment: Text.AlignHCenter
        color: Theme.onSurfaceVariant
        font.family: Theme.fontPrimary
        font.pixelSize: 10
    }

    Column {
        width: parent.width
        spacing: 2
        visible: root.enabled

        Repeater {
            model: root.open ? root.visibleDevices : []
            delegate: DeviceRow {
                required property var modelData
                width: parent.width
                device: modelData
            }
        }
        Text {
            visible: root.visibleDevices.length === 0
            width: parent.width
            text: "No devices"
            horizontalAlignment: Text.AlignHCenter
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: 10
        }
    }
}
