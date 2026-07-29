pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../../../Singletons"
import "../components" as C

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

    C.Popout {
        target: root
        targetHovered: hh.hovered
        content: popContent
    }

    Component {
        id: popContent
        Item {
            implicitWidth: col.implicitWidth + 40
            implicitHeight: col.implicitHeight + 36

            Column {
                id: col
                anchors.centerIn: parent
                spacing: 4

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.onSurface
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXxl
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd")
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.Bold
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "d MMMM yyyy")
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm
                }
            }
        }
    }
}
