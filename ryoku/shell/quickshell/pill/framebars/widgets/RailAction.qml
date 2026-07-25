import QtQuick
import Quickshell
import "../../Singletons"

Item {
    id: root

    required property string actionId
    required property string edge
    required property real scale
    signal actionRequested(string id)

    readonly property var action: ({
        "lock": { glyph: "lock", command: ["ryoku-shell", "lock"] },
        "logout": { glyph: "logout", command: ["hyprctl", "dispatch", "exit"] },
        "reboot": { glyph: "restart_alt", command: ["systemctl", "reboot"] },
        "shutdown": { glyph: "power_settings_new", command: ["systemctl", "poweroff"] },
        "screenshot": { glyph: "screenshot", command: ["sh", "-c", "flock -n -o /tmp/ryoshot.lock qs -c ryoshot"] },
        "wallpaper": { glyph: "image", command: ["ryoku-shell", "wallpaper-switcher"] },
        "color-picker": { glyph: "eyedropper", command: ["ryoku-cmd-color-picker"] }
    })[actionId]
    implicitWidth: 30 * scale
    implicitHeight: 30 * scale

    Text {
        anchors.centerIn: parent
        text: root.action ? root.action.glyph : "error"
        color: Theme.cream
        font.family: "Material Symbols Rounded"
        font.pixelSize: 19 * root.scale
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.action) Quickshell.execDetached(root.action.command);
            root.actionRequested(root.actionId);
        }
    }
}
