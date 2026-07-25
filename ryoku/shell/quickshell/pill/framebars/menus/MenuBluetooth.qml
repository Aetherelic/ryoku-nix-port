pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import "../.." as Pill
import "../../Singletons"
import "../lib/devices.js" as DeviceModel

Item {
    id: root

    required property real s
    required property bool open

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool adapterEnabled: root.adapter ? root.adapter.enabled : false
    readonly property var rows: (root.open && root.adapterEnabled && Bluetooth.devices)
        ? DeviceModel.btRows(Bluetooth.devices.values) : []

    implicitWidth: 290 * s
    implicitHeight: col.implicitHeight

    onOpenChanged: root.syncScan()
    onAdapterEnabledChanged: root.syncScan()
    Component.onCompleted: root.syncScan()
    Component.onDestruction: BluetoothDiscovery.setDiscovering(root, root.adapter, false)

    function syncScan() {
        BluetoothDiscovery.setDiscovering(root, root.adapter, root.open && root.adapterEnabled);
    }

    function deviceByAddress(addr) {
        const list = Bluetooth.devices ? Bluetooth.devices.values : [];
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].address === addr)
                return list[i];
        return null;
    }

    Column {
        id: col
        width: root.width
        spacing: 11 * root.s

        Row {
            width: parent.width
            Pill.MicroLabel {
                anchors.verticalCenter: parent.verticalCenter
                label: qsTr("Bluetooth")
                s: root.s
            }
        }

        Rectangle {
            width: parent.width
            height: 40 * root.s
            radius: Theme.radius
            color: root.adapterEnabled ? Qt.alpha(Theme.brand, 0.16) : (adHov.hovered ? Theme.frameBg : Theme.tileBg)
            border.width: 1
            border.color: root.adapterEnabled ? Theme.brand : (adHov.hovered ? Theme.frameBorder : Theme.border)
            visible: root.adapter !== null
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            Pill.GlyphIcon {
                id: adIcon
                anchors.left: parent.left
                anchors.leftMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.s
                height: 16 * root.s
                name: "bluetooth"
                color: root.adapterEnabled ? Theme.brand : Theme.iconDim
                stroke: 1.6
            }
            Text {
                anchors.left: adIcon.right
                anchors.leftMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Bluetooth")
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * root.s
                font.weight: Font.DemiBold
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.adapterEnabled ? qsTr("On") : qsTr("Off")
                color: root.adapterEnabled ? Theme.brand : Theme.faint
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
            }
            HoverHandler { id: adHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: if (root.adapter) root.adapter.enabled = !root.adapter.enabled }
        }

        Text {
            width: parent.width
            visible: root.adapter === null
            text: qsTr("No Bluetooth adapter")
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.Medium
        }

        Text {
            width: parent.width
            visible: root.adapterEnabled && root.rows.length === 0
            text: qsTr("Searching…")
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.Medium
        }

        Repeater {
            model: root.rows
            delegate: Rectangle {
                id: drow
                required property var modelData
                width: col.width
                height: 38 * root.s
                radius: Theme.radius
                color: dHov.hovered ? Theme.frameBg : "transparent"
                border.width: 1
                border.color: drow.modelData.connected ? Theme.brand : (dHov.hovered ? Theme.frameBorder : Theme.border)
                Behavior on color { ColorAnimation { duration: Motion.fast } }

                Pill.GlyphIcon {
                    id: dIcon
                    anchors.left: parent.left
                    anchors.leftMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15 * root.s
                    height: 15 * root.s
                    name: "bluetooth"
                    color: drow.modelData.connected ? Theme.brand : Theme.iconDim
                    stroke: 1.6
                }
                Text {
                    anchors.left: dIcon.right
                    anchors.leftMargin: 10 * root.s
                    anchors.right: dState.left
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: drow.modelData.name
                    elide: Text.ElideRight
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 12 * root.s
                }
                Text {
                    id: dState
                    anchors.right: parent.right
                    anchors.rightMargin: 12 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: drow.modelData.battery >= 0 ? (drow.modelData.battery + "%")
                        : drow.modelData.connected ? qsTr("Connected")
                        : drow.modelData.paired ? qsTr("Paired") : qsTr("Pair")
                    color: drow.modelData.connected ? Theme.brand : Theme.faint
                    font.family: Theme.mono
                    font.pixelSize: 9.5 * root.s
                    font.weight: Font.DemiBold
                }

                HoverHandler { id: dHov; cursorShape: Qt.PointingHandCursor }
                TapHandler {
                    onTapped: {
                        const d = root.deviceByAddress(drow.modelData.address);
                        if (!d) return;
                        if (d.connected) d.disconnect();
                        else d.connect();
                    }
                }
            }
        }
    }
}
