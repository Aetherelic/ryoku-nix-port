pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "../.." as Pill
import "../../Singletons"
import "../../lib/events.js" as EventsModel

Item {
    id: root

    required property real s
    required property bool open

    readonly property var loc: Qt.locale("en_US")
    readonly property string todayKey: EventsModel.dateKey(clock.date.getFullYear(), clock.date.getMonth(), clock.date.getDate())
    readonly property var todayEvents: root.open ? Events.forDate(root.todayKey) : []

    implicitWidth: 270 * s
    implicitHeight: col.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.open
    }

    Column {
        id: col
        width: root.width
        spacing: 12 * root.s

        Item {
            width: parent.width
            height: stamp.implicitHeight

            Column {
                id: stamp
                anchors.left: parent.left
                spacing: 2 * root.s
                Text {
                    text: Qt.formatTime(clock.date, "HH:mm")
                    color: Theme.bright
                    font.family: Theme.display
                    font.pixelSize: 34 * root.s
                    font.weight: Font.Medium
                    font.features: ({ "tnum": 1 })
                }
                Text {
                    text: root.loc.toString(clock.date, "dddd, d MMMM")
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 11.5 * root.s
                    font.weight: Font.Medium
                }
            }

            Column {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 2 * root.s
                spacing: 3 * root.s
                visible: Weather.available
                Pill.GlyphIcon {
                    anchors.right: parent.right
                    width: 24 * root.s
                    height: 24 * root.s
                    name: Weather.glyph
                    color: Theme.cream
                    stroke: 1.6
                }
                Text {
                    anchors.right: parent.right
                    text: Weather.temp
                    color: Theme.cream
                    font.family: Theme.mono
                    font.pixelSize: 13 * root.s
                    font.weight: Font.DemiBold
                }
            }
        }

        MenuDivider { width: parent.width; scale: root.s }

        Pill.MicroLabel { label: qsTr("Today"); s: root.s }

        Text {
            width: parent.width
            visible: root.todayEvents.length === 0
            text: qsTr("No events today")
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12 * root.s
            font.weight: Font.Medium
        }

        Repeater {
            model: root.todayEvents
            delegate: Item {
                id: erow
                required property var modelData
                width: col.width
                implicitHeight: eline.implicitHeight
                Row {
                    id: eline
                    width: parent.width
                    spacing: 10 * root.s
                    Text {
                        width: 46 * root.s
                        text: (erow.modelData.time && erow.modelData.time.length) ? erow.modelData.time : qsTr("all-day")
                        color: Theme.faint
                        font.family: Theme.mono
                        font.pixelSize: 10 * root.s
                    }
                    Text {
                        width: parent.width - 56 * root.s
                        text: erow.modelData.text
                        elide: Text.ElideRight
                        color: Theme.cream
                        font.family: Theme.font
                        font.pixelSize: 12 * root.s
                    }
                }
            }
        }
    }
}
