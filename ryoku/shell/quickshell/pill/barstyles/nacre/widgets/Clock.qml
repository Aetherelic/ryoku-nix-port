import QtQuick
import Quickshell
import "../../../Singletons"
import "../../shared" as Shared
import "../../shared/popouts" as Popouts

Item {
    id: root

    property real barHeight: 40

    implicitWidth: label.implicitWidth
    implicitHeight: 26

    SystemClock { id: clock; precision: SystemClock.Minutes }
    HoverHandler { id: hover }

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.date, "HH:mm")
        color: Theme.onSurface
        font.family: Theme.mono
        font.pixelSize: Theme.fontMd
        font.weight: Font.DemiBold
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
        Popouts.CalendarPopout {}
    }
}
