import QtQuick
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property string actionId
    required property string edge
    required property real scale
    signal actionRequested(string id)

    readonly property var glyphs: ({
        "lock": "lock",
        "logout": "logout",
        "reboot": "restart_alt",
        "shutdown": "power_settings_new",
        "screenshot": "screenshot",
        "wallpaper": "image",
        "color-picker": "eyedropper"
    })
    implicitWidth: 30 * scale
    implicitHeight: 30 * scale

    Pill.MaterialIcon {
        anchors.centerIn: parent
        text: root.glyphs[root.actionId] || "error"
        color: Theme.onSurface
        font.pixelSize: 19 * root.scale
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.actionRequested(root.actionId)
    }
}
