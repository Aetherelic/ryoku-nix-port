import QtQuick
import "../../../framebars/menus" as Menus

Item {
    id: root

    property bool open: false
    signal closeRequested()

    implicitWidth: 430
    implicitHeight: 520

    Flickable {
        anchors.fill: parent
        anchors.margins: 12
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Menus.MenuNotifications {
            id: content
            width: parent.width
            s: 1
            open: root.open
            onRequestClose: root.closeRequested()
        }
    }
}
