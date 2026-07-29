pragma ComponentBehavior: Bound

import QtQuick
import "../../../../Singletons"
import "../../../.." as Pill

Column {
    id: root

    required property var accessPoint
    property bool expanded: false
    property bool connecting: false
    property int pendingId: -1
    readonly property bool secured: !!(root.accessPoint && root.accessPoint.security && root.accessPoint.security !== "None")
    readonly property bool needsPassword: root.secured && !root.accessPoint.saved

    width: parent ? parent.width : 0
    spacing: 3

    function connect() {
        root.connecting = true;
        root.pendingId = Network.connectWifi(root.accessPoint.ssid, root.needsPassword ? password.text : "");
    }

    Connections {
        target: Network
        function onReplied(id, ok, error) {
            if (id !== root.pendingId)
                return;
            root.connecting = false;
            root.pendingId = -1;
            if (ok) {
                root.expanded = false;
                password.text = "";
            }
        }
    }

    Item {
        width: parent.width
        height: 28

        Rectangle {
            anchors.fill: parent
            radius: 4
            color: hover.hovered
                ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                : "transparent"
        }
        Pill.MaterialIcon {
            id: icon
            anchors.left: parent.left
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: "wifi"
            font.pixelSize: 15
            color: Theme.onSurface
            opacity: 0.45 + 0.55 * Math.max(0, Math.min(1, (root.accessPoint.strength || 0) / 100))
        }
        Text {
            anchors.left: icon.right
            anchors.leftMargin: 8
            anchors.right: metadata.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: root.accessPoint.ssid
            elide: Text.ElideRight
            color: Theme.onSurface
            font.family: Theme.fontPrimary
            font.pixelSize: 11
        }
        Row {
            id: metadata
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5

            Pill.MaterialIcon {
                visible: root.secured
                anchors.verticalCenter: parent.verticalCenter
                text: "lock"
                font.pixelSize: 11
                color: Theme.onSurfaceVariant
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.connecting ? "..." : Math.round(root.accessPoint.strength || 0) + "%"
                color: Theme.onSurfaceVariant
                font.family: Theme.mono
                font.pixelSize: 9
            }
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
            onTapped: {
                if (!root.needsPassword) {
                    root.connect();
                    return;
                }
                root.expanded = !root.expanded;
                if (root.expanded)
                    password.forceActiveFocus();
            }
        }
    }

    Row {
        width: parent.width
        spacing: 5
        visible: root.needsPassword && root.expanded

        Rectangle {
            width: parent.width - connectButton.width - parent.spacing
            height: 26
            radius: 4
            color: "transparent"
            border.width: Theme.borderWidth
            border.color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.2)

            TextInput {
                id: password
                anchors.fill: parent
                anchors.leftMargin: 8
                anchors.rightMargin: 8
                verticalAlignment: Text.AlignVCenter
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: 11
                echoMode: TextInput.Password
                clip: true
                onAccepted: root.connect()

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Password"
                    color: Theme.onSurfaceVariant
                    font: password.font
                    visible: password.text.length === 0 && !password.activeFocus
                }
            }
        }
        Rectangle {
            id: connectButton
            width: 64
            height: 26
            radius: 4
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)

            Text {
                anchors.centerIn: parent
                text: root.connecting ? "..." : "Connect"
                color: Theme.primary
                font.family: Theme.mono
                font.pixelSize: 10
            }
            TapHandler { onTapped: root.connect() }
        }
    }
}
