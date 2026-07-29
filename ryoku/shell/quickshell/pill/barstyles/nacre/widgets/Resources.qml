import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../../shared" as Shared
import "../../shared/popouts" as Popouts

Item {
    id: root

    property real barHeight: 40

    implicitWidth: content.implicitWidth
    implicitHeight: 26

    Component.onCompleted: Sysinfo.setActive(root, true)
    Component.onDestruction: Sysinfo.setActive(root, false)
    HoverHandler { id: hover }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 8

        Text {
            text: "CPU " + Math.round(Sysinfo.cpu * 100) + "%"
            color: Sysinfo.cpu > 0.85 ? Theme.error : Theme.onSurfaceVariant
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
        }
        Text {
            text: "RAM " + Math.round(Sysinfo.mem * 100) + "%"
            color: Sysinfo.mem > 0.9 ? Theme.error : Theme.onSurfaceVariant
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
        }
        Text {
            visible: Sysinfo.hasTemp
            text: Math.round(Sysinfo.tempC) + "°"
            color: Sysinfo.tempC > 80 ? Theme.error : Theme.onSurfaceVariant
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
        Popouts.ResourcesPopout {}
    }
}
