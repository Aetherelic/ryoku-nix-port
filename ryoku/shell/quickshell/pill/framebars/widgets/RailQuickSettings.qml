pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"

// Quick-settings launch button: opens the main quick-settings menu on left
// click. Shows the distro mark, as the reference does by default.
// Contract 04 sec 3.2 (quick_settings).
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
        icon: "arch"
        onClicked: root.menuRequested("quick-settings", Qt.rect(0, 0, root.width, root.height))
    }
}
