import QtQuick
import "../.." as Pill
import "../../Singletons"

Item {
    id: root

    required property string edge
    required property real scale
    required property string statusId
    signal menuRequested(string id, rect ownerRect)

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property string glyph: {
        if (statusId === "battery") return Battery.charging ? "battery_charging_full" : "battery_full";
        if (statusId === "audio-input") return "mic";
        if (statusId === "audio-output") return Audio.sink && Audio.sink.audio && Audio.sink.audio.muted ? "volume_off" : "volume_up";
        if (statusId === "notifications") return Notifs.unread > 0 ? "notifications_unread" : "notifications";
        if (statusId === "bluetooth") return "bluetooth";
        return Network.kind === "ethernet" ? "lan" : (Network.kind === "wifi" ? "wifi" : "signal_wifi_off");
    }
    implicitWidth: horizontal ? 28 * scale : 28 * scale
    implicitHeight: 28 * scale

    Pill.MaterialIcon {
        anchors.centerIn: parent
        text: root.glyph
        fill: statusId === "notifications" && Notifs.unread > 0 ? 1 : 0
        color: Theme.cream
        font.pixelSize: 18 * root.scale
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.menuRequested(root.statusId, Qt.rect(0, 0, root.width, root.height))
    }
}
