pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../../shared" as Shared
import "../../nacre/popouts" as Popouts
import "../../nacre/Format.js" as Format

// Obi battery: freedesktop battery-level glyph (charging variant on AC) plus the
// percentage in mono. Self-hides without a battery; goes error-red when low.
// Hovering opens a card with the level, charge/time, health, and a power-profile picker.
Item {
    id: root

    implicitWidth: rowr.implicitWidth
    implicitHeight: 26
    visible: Battery.present

    readonly property bool charging: Battery.charging || Battery.full
    readonly property color tint: Battery.low ? Theme.error : Theme.onSurface

    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 6

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: Format.batteryGlyph(Battery.pct, root.charging)
            size: 18
            color: root.tint
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.pct + "%"
            color: root.tint
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
        }
    }

    Shared.Popout {
        target: root
        targetHovered: hh.hovered
        namespace: "ryoku-obi-popout"
        content: popContent
    }

    Component {
        id: popContent
        Popouts.BatteryPopout {}
    }
}
