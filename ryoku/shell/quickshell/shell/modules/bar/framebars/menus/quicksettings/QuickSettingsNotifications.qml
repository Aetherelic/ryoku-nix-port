pragma ComponentBehavior: Bound

import QtQuick
import ".." as Menus

Item {
    id: root

    property real s: 1
    property bool open: false
    property var navigate: null
    property var closePanel: null

    Menus.MenuNotifications {
        anchors.fill: parent
        anchors.margins: 12
        s: root.s
        open: root.open
        onRequestClose: if (root.closePanel) root.closePanel()
    }
}
