pragma ComponentBehavior: Bound

import QtQuick
import "../../Singletons"

// Power-profile indicator: a box-shape indicator (no click) whose glyph tracks
// the active profile. `active` (host visibility) gates the singleton's polling.
// Contract 04 sec 3.2 (power_profile): power-saver / balanced / performance,
// unknown falls back to the balanced glyph.
Item {
    id: root

    required property string edge
    required property real scale
    required property bool active

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    onActiveChanged: PowerProfiles.setActive(root, root.active)
    Component.onCompleted: PowerProfiles.setActive(root, root.active)
    Component.onDestruction: PowerProfiles.setActive(root, false)

    readonly property string glyph: {
        const p = PowerProfiles.profile;
        return p === "power-saver" ? "eco" : (p === "performance" ? "bolt" : "balance");
    }

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        icon: root.glyph
        interactive: false
        opacity: PowerProfiles.available ? 1 : 0.45
    }
}
