pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"
import Ryoku.FrameBars
import "../lib/menupoll.js" as Poll

Item {
    id: root

    required property real s
    required property bool open

    signal actionRequested(string id)

    readonly property var actionIds: MenuCatalog.quickActionIds()

    implicitWidth: 320 * s
    implicitHeight: grid.implicitHeight

    property bool watching: false
    function syncWatch() {
        const r = Poll.watchDelta(root.watching, root.open);
        if (r.delta !== 0)
            Toggles.watchers += r.delta;
        root.watching = r.watching;
    }
    onOpenChanged: root.syncWatch()
    Component.onCompleted: root.syncWatch()
    Component.onDestruction: if (root.watching) Toggles.watchers -= 1

    readonly property var meta: ({
        "lock": "lock", "logout": "logout", "reboot": "reboot", "shutdown": "shutdown",
        "lens": "lens", "color": "eyedropper", "ocr": "ocr", "qr": "qr", "mirror": "webcam",
        "clipboard": "clipboard", "wifi": "wifi", "bluetooth": "bluetooth", "microphone": "mic",
        "do-not-disturb": "dnd", "night-light": "moon", "keep-awake": "coffee", "game-mode": "cpu"
    })

    function isToggle(id) {
        return id === "wifi" || id === "bluetooth" || id === "microphone" || id === "do-not-disturb"
            || id === "night-light" || id === "keep-awake" || id === "game-mode";
    }

    function isOn(id) {
        switch (id) {
        case "wifi": return Toggles.wifiOn;
        case "bluetooth": return Toggles.btOn;
        case "microphone": return !Toggles.micMuted;
        case "do-not-disturb": return Flags.dnd;
        case "night-light": return Toggles.nightOn;
        case "keep-awake": return Flags.keepAwake;
        case "game-mode": return Flags.gameMode;
        }
        return false;
    }

    function act(id) {
        switch (id) {
        case "wifi": Toggles.toggleWifi(); return;
        case "bluetooth": Toggles.toggleBt(); return;
        case "microphone": Toggles.toggleMic(); return;
        case "do-not-disturb": Flags.dnd = !Flags.dnd; return;
        case "night-light": Toggles.toggleNight(); return;
        case "keep-awake": Flags.keepAwake = !Flags.keepAwake; return;
        case "game-mode": Flags.gameMode = !Flags.gameMode; return;
        }
        root.actionRequested(id);
    }

    function label(id) {
        switch (id) {
        case "lock": return qsTr("Lock");
        case "logout": return qsTr("Log Out");
        case "reboot": return qsTr("Reboot");
        case "shutdown": return qsTr("Shut Down");
        case "lens": return qsTr("Lens");
        case "color": return qsTr("Color");
        case "ocr": return qsTr("OCR");
        case "qr": return qsTr("QR");
        case "mirror": return qsTr("Mirror");
        case "clipboard": return qsTr("Clipboard");
        case "wifi": return qsTr("Wi-Fi");
        case "bluetooth": return qsTr("Bluetooth");
        case "microphone": return qsTr("Microphone");
        case "do-not-disturb": return qsTr("Do Not Disturb");
        case "night-light": return qsTr("Night Light");
        case "keep-awake": return qsTr("Keep Awake");
        case "game-mode": return qsTr("Game Mode");
        }
        return id;
    }

    Grid {
        id: grid
        width: root.width
        columns: 5
        readonly property real cellW: (width - spacing * (columns - 1)) / columns
        spacing: 8 * root.s

        Repeater {
            model: root.actionIds
            delegate: Item {
                id: cell
                required property var modelData
                readonly property bool on: root.isToggle(cell.modelData) && root.isOn(cell.modelData)
                width: grid.cellW
                height: 58 * root.s

                Rectangle {
                    id: tile
                    anchors.top: parent.top
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 40 * root.s
                    height: 40 * root.s
                    radius: Theme.radius
                    color: cell.on ? Theme.brand : (cHov.hovered ? Theme.frameBg : Theme.tileBg)
                    border.width: 1
                    border.color: cell.on ? Theme.brand : (cHov.hovered ? Theme.frameBorder : Theme.border)
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }

                    Pill.GlyphIcon {
                        anchors.centerIn: parent
                        width: 16 * root.s
                        height: 16 * root.s
                        name: root.meta[cell.modelData]
                        color: cell.on ? Theme.onAccent : (cHov.hovered ? Theme.cream : Theme.iconDim)
                        stroke: 1.6
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: root.label(cell.modelData)
                }

                Text {
                    anchors.top: tile.bottom
                    anchors.topMargin: 5 * root.s
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.label(cell.modelData)
                    elide: Text.ElideRight
                    color: cell.on ? Theme.brand : Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 8 * root.s
                }

                HoverHandler { id: cHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.act(cell.modelData) }
            }
        }
    }
}
