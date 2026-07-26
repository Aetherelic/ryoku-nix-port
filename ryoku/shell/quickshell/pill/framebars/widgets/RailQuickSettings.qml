pragma ComponentBehavior: Bound

import QtQuick

// Quick-settings launch button: opens the main quick-settings menu on left click.
// The reference shows a configurable distro logo here; Ryoku has no distro-logo
// config or glyphs, so it uses the settings "tune" glyph for the same role.
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
        icon: "tune"
        onClicked: root.menuRequested("quick-settings", Qt.rect(0, 0, root.width, root.height))
    }
}
