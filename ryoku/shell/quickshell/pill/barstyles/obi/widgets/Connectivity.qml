pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import "../../../Singletons"
import "../components" as C
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

    C.Popout {
        id: hostPop
        target: root
        targetHovered: hh.hovered
        content: popContent
    }

    Component {
        id: popContent
        Item {
            id: pop
            implicitWidth: 330
            implicitHeight: col.implicitHeight + 24

            // Snapshot the scan so the list holds still while you read and click
            // it. The daemon keeps streaming strength updates, but the card only
            // re-reads them on open or a manual refresh, never mid-click.
            property var shownNets: []
            function computeNets() {
                const seen = ({});
                const out = [];
                const aps = Network.accessPoints;
                for (let i = 0; i < aps.length; i++) {
                    const ap = aps[i];
                    if (!ap || !ap.ssid || ap.ssid === Network.activeSsid)
                        continue;
                    if (seen[ap.ssid])
                        continue;
                    seen[ap.ssid] = true;
                    out.push(ap);
                }
                return out;
            }
            function snapshot() { pop.shownNets = pop.computeNets(); }
            Timer { id: rescanSnap; interval: 1200; onTriggered: pop.snapshot() }
            Component.onCompleted: {
                pop.snapshot();
                if (Network.wifiRadio) { Network.refresh(); rescanSnap.restart(); }
            }
            readonly property var btList: {
                const ds = root.btDevices;
                const known = ds.filter(d => d && (d.paired || d.bonded));
                const found = (root.adapter && root.adapter.discovering)
                    ? ds.filter(d => d && !(d.paired || d.bonded) && d.name && d.name.length > 0) : [];
                known.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0));
                return known.concat(found);
            }

            component Head: Text {
                color: Theme.onSurfaceVariant
                font.family: Theme.mono
                font.pixelSize: 9
                font.letterSpacing: 1.6
                font.weight: Font.Medium
            }
            component IconBtn: Item {
                id: ib
                property string glyph: ""
                property bool on: false
                signal clicked()
                width: 24
                height: 24
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: ibh.hovered ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.1) : "transparent"
                }
                Pill.MaterialIcon {
                    anchors.centerIn: parent
                    text: ib.glyph
                    font.pixelSize: 16
                    color: ib.on ? Theme.primary : Theme.onSurfaceVariant
                }
                HoverHandler { id: ibh; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: ib.clicked() }
            }

            component ApRow: Column {
                id: apr
                required property var ap
                property bool expanded: false
                property bool connecting: false
                property int pendingId: -1
                readonly property bool sec: !!(apr.ap && apr.ap.security && apr.ap.security !== "None")
                readonly property bool needsPw: apr.sec && !apr.ap.saved
                width: parent ? parent.width : 0
                spacing: 3

                function doConnect() {
                    apr.connecting = true;
                    apr.pendingId = Network.connectWifi(apr.ap.ssid, apr.needsPw ? pwField.text : "");
                }
                Connections {
                    target: Network
                    function onReplied(id, ok, error) {
                        if (id !== apr.pendingId)
                            return;
                        apr.connecting = false;
                        apr.pendingId = -1;
                        if (ok) {
                            apr.expanded = false;
                            pwField.text = "";
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 28
                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        color: aph.hovered ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08) : "transparent"
                    }
                    Pill.MaterialIcon {
                        id: aicon
                        anchors.left: parent.left
                        anchors.leftMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: "wifi"
                        font.pixelSize: 15
                        color: Theme.onSurface
                        opacity: 0.45 + 0.55 * Math.max(0, Math.min(1, (apr.ap.strength || 0) / 100))
                    }
                    Text {
                        anchors.left: aicon.right
                        anchors.leftMargin: 8
                        anchors.right: ameta.left
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: apr.ap.ssid
                        elide: Text.ElideRight
                        color: Theme.onSurface
                        font.family: Theme.fontPrimary
                        font.pixelSize: 11
                    }
                    Row {
                        id: ameta
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Pill.MaterialIcon {
                            visible: apr.sec
                            anchors.verticalCenter: parent.verticalCenter
                            text: "lock"
                            font.pixelSize: 11
                            color: Theme.onSurfaceVariant
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: apr.connecting ? "..." : Math.round(apr.ap.strength || 0) + "%"
                            color: Theme.onSurfaceVariant
                            font.family: Theme.mono
                            font.pixelSize: 9
                        }
                    }
                    HoverHandler { id: aph; cursorShape: Qt.PointingHandCursor }
                    TapHandler {
                        onTapped: {
                            if (apr.needsPw) {
                                apr.expanded = !apr.expanded;
                                if (apr.expanded)
                                    pwField.forceActiveFocus();
                            } else {
                                apr.doConnect();
                            }
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 5
                    visible: apr.needsPw && apr.expanded
                    Rectangle {
                        width: parent.width - conbtn.width - parent.spacing
                        height: 26
                        radius: 4
                        color: "transparent"
                        border.width: Theme.borderWidth
                        border.color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.2)
                        TextInput {
                            id: pwField
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            verticalAlignment: Text.AlignVCenter
                            color: Theme.onSurface
                            font.family: Theme.fontPrimary
                            font.pixelSize: 11
                            echoMode: TextInput.Password
                            clip: true
                            onAccepted: apr.doConnect()
                            Text {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: "Password"
                                color: Theme.onSurfaceVariant
                                font: pwField.font
                                visible: pwField.text.length === 0 && !pwField.activeFocus
                            }
                        }
                    }
                    Rectangle {
                        id: conbtn
                        width: 64
                        height: 26
                        radius: 4
                        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16)
                        Text {
                            anchors.centerIn: parent
                            text: apr.connecting ? "..." : "Connect"
                            color: Theme.primary
                            font.family: Theme.mono
                            font.pixelSize: 10
                        }
                        TapHandler { onTapped: apr.doConnect() }
                    }
                }
            }

            component BtRow: Item {
                id: btr
                required property var dev
                property bool busy: false
                readonly property bool conn: !!(btr.dev && btr.dev.connected)
                width: parent ? parent.width : 0
                height: 30

                Process { id: pp; onExited: btr.busy = false }
                function act() {
                    const d = btr.dev;
                    if (!d)
                        return;
                    if (d.connected) {
                        d.disconnect();
                        return;
                    }
                    if (d.paired || d.bonded) {
                        d.connect();
                        return;
                    }
                    btr.busy = true;
                    pp.command = ["sh", "-c",
                        'timeout 30 bluetoothctl pair "$1" && bluetoothctl trust "$1" && timeout 30 bluetoothctl connect "$1"',
                        "sh", d.address];
                    pp.running = false;
                    pp.running = true;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: 4
                    color: bth.hovered ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08) : "transparent"
                }
                Pill.GlyphIcon {
                    id: bicon
                    anchors.left: parent.left
                    anchors.leftMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 15
                    height: 15
                    name: BtLink.glyphFor(btr.dev)
                    stroke: 1.6
                    color: btr.conn ? Theme.onSurface : Theme.onSurfaceVariant
                }
                Text {
                    anchors.left: bicon.right
                    anchors.leftMargin: 8
                    anchors.right: bmeta.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: BtLink.label(btr.dev)
                    elide: Text.ElideRight
                    color: btr.conn ? Theme.onSurface : Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: 11
                    font.weight: btr.conn ? Font.DemiBold : Font.Normal
                }
                Row {
                    id: bmeta
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: BtLink.batteryLevel(btr.dev) >= 0
                        text: BtLink.batteryLevel(btr.dev) + "%"
                        color: Theme.onSurfaceVariant
                        font.family: Theme.mono
                        font.pixelSize: 9
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: btr.busy ? "..." : (btr.conn ? "Disconnect" : ((btr.dev && (btr.dev.paired || btr.dev.bonded)) ? "Connect" : "Pair"))
                        color: btr.conn ? Theme.onSurfaceVariant : Theme.primary
                        font.family: Theme.mono
                        font.pixelSize: 9
                    }
                }
                HoverHandler { id: bth; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: btr.act() }
            }

            Column {
                id: col
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 12
                spacing: 12

                Column {
                    id: wifiSect
                    width: parent.width
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 24
                        Head {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "WI-FI"
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            IconBtn {
                                visible: Network.wifiRadio
                                glyph: "refresh"
                                onClicked: { Network.refresh(); rescanSnap.restart(); }
                            }
                            IconBtn {
                                glyph: "wifi"
                                on: Network.wifiRadio
                                onClicked: Network.setWifiEnabled(!Network.wifiRadio)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8
                        visible: root.wifiConnected || root.wired
                        Pill.MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.wired ? "lan" : "wifi"
                            font.pixelSize: 16
                            color: Theme.onSurface
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 16 - discon.width - parent.spacing * 2
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
                            id: discon
                            anchors.verticalCenter: parent.verticalCenter
                            visible: !root.wired
                            text: "close"
                            font.pixelSize: 16
                            color: Theme.onSurfaceVariant
                            TapHandler { onTapped: Network.disconnectWifi() }
                        }
                    }

                    Column {
                        id: netList
                        width: parent.width
                        spacing: 3
                        visible: Network.wifiRadio
                        Repeater {
                            model: root.open ? pop.shownNets.slice(0, 6) : []
                            delegate: ApRow {
                                required property var modelData
                                width: netList.width
                                ap: modelData
                            }
                        }
                        Text {
                            visible: pop.shownNets.length === 0
                            width: parent.width
                            text: "No networks found"
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.onSurfaceVariant
                            font.family: Theme.fontPrimary
                            font.pixelSize: 10
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Theme.borderWidth
                    color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.12)
                }

                Column {
                    id: btSect
                    width: parent.width
                    spacing: 6

                    Item {
                        width: parent.width
                        height: 24
                        Head {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "BLUETOOTH"
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            IconBtn {
                                visible: root.btOn
                                glyph: "refresh"
                                on: !!(root.adapter && root.adapter.discovering)
                                onClicked: BluetoothDiscovery.setDiscovering(pop, root.adapter, !(root.adapter && root.adapter.discovering))
                            }
                            IconBtn {
                                glyph: "bluetooth"
                                on: root.btOn
                                onClicked: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                            }
                        }
                    }

                    Text {
                        visible: !root.btOn
                        width: parent.width
                        text: "Bluetooth is off"
                        horizontalAlignment: Text.AlignHCenter
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontPrimary
                        font.pixelSize: 10
                    }

                    Column {
                        id: devList
                        width: parent.width
                        spacing: 2
                        visible: root.btOn
                        Repeater {
                            model: root.open ? pop.btList : []
                            delegate: BtRow {
                                required property var modelData
                                width: devList.width
                                dev: modelData
                            }
                        }
                        Text {
                            visible: pop.btList.length === 0
                            width: parent.width
                            text: "No devices"
                            horizontalAlignment: Text.AlignHCenter
                            color: Theme.onSurfaceVariant
                            font.family: Theme.fontPrimary
                            font.pixelSize: 10
                        }
                    }
                }
            }
        }
    }
}
