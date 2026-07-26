pragma ComponentBehavior: Bound

import QtQuick

// App launcher button: opens the launcher menu on left click (the reference
// view-app-grid widget, a menu inside the frame). Contract 04 sec 3.2
// (app_launcher); catalog id app-launcher.
Item {
    id: root

    required property string edge
    required property real scale
    signal menuRequested(string id, rect ownerRect)

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        icon: "apps"
        onClicked: root.menuRequested("launcher", Qt.rect(0, 0, root.width, root.height))
    }
}
