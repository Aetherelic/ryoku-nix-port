pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../../Singletons"
import "../../shared" as Shared
import "../../nacre/popouts" as Popouts

// Obi clock: time in mono, a middot, then the short date. Hovering opens a
// popout with the full date.
Item {
    id: root

    implicitWidth: rowr.implicitWidth
    implicitHeight: 26

    SystemClock { id: clock; precision: SystemClock.Minutes }
    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            color: Theme.onSurface
            font.family: Theme.mono
            font.pixelSize: Theme.fontMd
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "· " + Qt.formatDateTime(clock.date, "ddd, dd/MM")
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
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
        Popouts.CalendarPopout {}
    }
}
