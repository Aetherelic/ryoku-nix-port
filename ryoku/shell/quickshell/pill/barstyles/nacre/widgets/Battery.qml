import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../../shared" as Shared
import "../../shared/popouts" as Popouts
import "../../shared/Format.js" as Format

Item {
    id: root

    property real barHeight: 40
    readonly property bool charging: Battery.charging || Battery.full

    implicitWidth: content.implicitWidth
    implicitHeight: 26
    visible: Battery.present

    HoverHandler { id: hover }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 4

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: Format.batteryGlyph(Battery.pct, root.charging)
            size: 17
            color: Battery.low ? Theme.error : Theme.onSurfaceVariant
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Battery.pct + "%"
            color: Battery.low ? Theme.error : Theme.onSurfaceVariant
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
        }
    }

    Shared.Popout {
        target: root
        targetHovered: hover.hovered
        barHeight: root.barHeight
        namespace: "ryoku-nacre-popout"
        content: popup
    }
    Component {
        id: popup
        Popouts.BatteryPopout {}
    }
}
