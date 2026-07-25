import QtQuick
import "../framebars/menus" as Menus

Item {
    id: root

    required property real s
    required property bool open

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: notifications.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Menus.MenuNotifications {
            id: notifications
            width: parent.width
            s: root.s
            open: root.open
        }
    }
}
