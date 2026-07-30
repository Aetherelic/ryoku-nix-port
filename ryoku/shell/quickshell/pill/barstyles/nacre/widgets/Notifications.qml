import QtQuick
import "../../../Singletons"
import "../../.." as Pill

Item {
    id: root

    property real barHeight: 40
    signal popupRequested(string name, real center, bool active, bool pinned)

    implicitWidth: 20
    implicitHeight: 26

    Pill.MaterialIcon {
        anchors.centerIn: parent
        text: Flags.dnd ? "notifications_off"
            : Notifs.history.length > 0 ? "notifications_unread" : "notifications"
        fill: Notifs.history.length > 0 && !Flags.dnd ? 1 : 0
        color: Flags.dnd ? Theme.error
            : Notifs.history.length > 0 ? Theme.onSurface : Theme.onSurfaceVariant
        font.pixelSize: Theme.iconSm
    }

    TapHandler {
        onTapped: root.popupRequested("notifications",
            root.mapToItem(null, root.width / 2, root.height / 2).x, true, true)
    }
}
