pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill

Item {
    id: root

    signal openInbox()

    implicitWidth: 342
    implicitHeight: cardLoader.item ? cardLoader.item.implicitHeight + 24 : 100

    Loader {
        id: cardLoader
        active: Notifs.popups.length > 0
        anchors.fill: parent
        anchors.margins: 12

        sourceComponent: Pill.NotificationCard {
            width: cardLoader.width
            notif: Notifs.popups[Notifs.popups.length - 1]
            compact: true
            unifiedFrame: true
            lifespanMs: {
                const ttl = Notifs.popupTtl(Notifs.popups[Notifs.popups.length - 1]);
                return ttl < 0 ? 0 : ttl;
            }
            TapHandler { onTapped: root.openInbox() }
        }
    }
}
