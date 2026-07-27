pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"

// Quick-settings launch button: opens the main quick-settings menu on left
// click. Shows the Ryoku brand mark (user decision): the same slot carries the
// distro mark in the reference, and the mark is what tells the two shells
// apart at a glance. Geometry stays the reference 16px icon box.
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
        onClicked: root.menuRequested("quick-settings", Qt.rect(0, 0, root.width, root.height))

        Item {
            width: Theme.iconSm * root.scale
            height: Theme.iconSm * root.scale
            Pill.BrandMark {
                anchors.centerIn: parent
                size: 15 * root.scale
                color: Theme.onSurface
            }
        }
    }
}
