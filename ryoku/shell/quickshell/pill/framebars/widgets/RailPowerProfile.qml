pragma ComponentBehavior: Bound

import QtQuick
import "../../Singletons"

// Power-profile button: the glyph tracks the active profile, and left click opens
// the power-profile menu (power-saver / balanced / performance). `active` (host
// visibility) gates the singleton's polling. Contract 04 sec 3.2 (power_profile):
// unknown profile falls back to the balanced glyph.
Item {
    id: root

    required property string edge
    required property real scale
    required property bool active
    signal menuRequested(string id, rect ownerRect)

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    onActiveChanged: PowerProfiles.setActive(root, root.active)
    Component.onCompleted: PowerProfiles.setActive(root, root.active)
    Component.onDestruction: PowerProfiles.setActive(root, false)

    readonly property string glyph: {
        const p = PowerProfiles.profile;
        return "power-profile-" + (p === "power-saver" || p === "performance" ? p : "balanced");
    }

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        icon: root.glyph
        opacity: PowerProfiles.available ? 1 : 0.45
        onClicked: root.menuRequested("power-profile", Qt.rect(0, 0, root.width, root.height))
    }
}
