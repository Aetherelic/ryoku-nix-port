pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property real s
    required property bool open

    implicitWidth: 280 * s
    implicitHeight: col.implicitHeight

    onOpenChanged: Network.setVpnPolling(root, root.open)
    Component.onCompleted: Network.setVpnPolling(root, root.open)
    Component.onDestruction: Network.setVpnPolling(root, false)

    readonly property bool online: Network.kind.length > 0
    readonly property string statusLabel: Network.kind === "ethernet" ? qsTr("Ethernet")
        : Network.kind === "wifi" ? qsTr("Wi-Fi") : qsTr("Offline")
    readonly property string statusIcon: Network.kind === "ethernet" ? "ethernet" : "wifi"

    Column {
        id: col
        width: root.width
        spacing: 12 * root.s

        Pill.MicroLabel { label: qsTr("Network"); s: root.s }

        Row {
            width: parent.width
            spacing: 11 * root.s
            Pill.GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 20 * root.s
                height: 20 * root.s
                name: root.statusIcon
                color: root.online ? Theme.brand : Theme.iconDim
                stroke: 1.7
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1 * root.s
                Text {
                    text: root.statusLabel
                    color: Theme.cream
                    font.family: Theme.font
                    font.pixelSize: 13 * root.s
                    font.weight: Font.DemiBold
                }
                Text {
                    visible: Network.kind === "wifi"
                    text: qsTr("Signal %1%").arg(Math.round(Network.level * 100))
                    color: Theme.dim
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                }
            }
        }

        Rectangle {
            id: wifiRow
            width: parent.width
            height: 40 * root.s
            radius: Theme.radius
            color: Network.wifiRadio ? Qt.alpha(Theme.brand, 0.16) : (wifiHov.hovered ? Theme.frameBg : Theme.tileBg)
            border.width: 1
            border.color: Network.wifiRadio ? Theme.brand : (wifiHov.hovered ? Theme.frameBorder : Theme.border)
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Behavior on border.color { ColorAnimation { duration: Motion.fast } }

            Pill.GlyphIcon {
                id: wifiIcon
                anchors.left: parent.left
                anchors.leftMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * root.s
                height: 16 * root.s
                name: "wifi"
                color: Network.wifiRadio ? Theme.brand : Theme.iconDim
                stroke: 1.6
            }
            Text {
                anchors.left: wifiIcon.right
                anchors.leftMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("Wi-Fi")
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 12.5 * root.s
                font.weight: Font.DemiBold
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: 12 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: Network.wifiRadio ? qsTr("On") : qsTr("Off")
                color: Network.wifiRadio ? Theme.brand : Theme.faint
                font.family: Theme.mono
                font.pixelSize: 10 * root.s
                font.weight: Font.DemiBold
                font.capitalization: Font.AllUppercase
            }
            HoverHandler { id: wifiHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { Toggles.toggleWifi(); Network.refresh(); } }
        }

        Row {
            width: parent.width
            spacing: 8 * root.s
            visible: Network.vpnActive
            Pill.GlyphIcon {
                anchors.verticalCenter: parent.verticalCenter
                width: 15 * root.s
                height: 15 * root.s
                name: "lock"
                color: Theme.brand
                stroke: 1.6
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: qsTr("VPN: %1").arg(Network.vpnName)
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 11.5 * root.s
            }
        }
    }
}
