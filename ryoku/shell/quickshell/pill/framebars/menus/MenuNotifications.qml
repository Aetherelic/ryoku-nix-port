pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import "../../Singletons"
import "../lib/notifs.js" as NotifModel

Item {
    id: root

    required property real s
    required property bool open

    readonly property var rows: root.open ? NotifModel.rows(Notifs.groups) : []

    implicitWidth: 300 * s
    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: root.width
        spacing: 11 * root.s

        Item {
            width: parent.width
            height: 14 * root.s
            Pill.MicroLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                label: qsTr("Recent")
                s: root.s
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: root.rows.length > 0
                text: qsTr("Clear")
                color: clearHov.hovered ? Theme.primary : Theme.onSurfaceVariant
                font.family: Theme.mono
                font.pixelSize: 8.5 * root.s
                font.weight: Font.DemiBold
                font.letterSpacing: 1.6 * root.s
                font.capitalization: Font.AllUppercase
                HoverHandler { id: clearHov; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: Notifs.clearAll() }
            }
        }

        Text {
            width: parent.width
            visible: root.rows.length === 0
            text: qsTr("No notifications")
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: 12 * root.s
            font.weight: Font.Medium
        }

        Repeater {
            model: root.rows
            delegate: Item {
                id: nrow
                required property var modelData
                width: col.width
                implicitHeight: nbody.implicitHeight

                Item {
                    id: ndismiss
                    width: 22 * root.s
                    height: 22 * root.s
                    anchors.right: parent.right
                    anchors.top: parent.top
                    Pill.GlyphIcon {
                        anchors.centerIn: parent
                        width: 12 * root.s
                        height: 12 * root.s
                        name: "close"
                        color: ndHov.hovered ? Theme.primary : Theme.onSurfaceVariant
                        stroke: 1.8
                    }
                    HoverHandler { id: ndHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Notifs.dismissApp(nrow.modelData.app) }
                }

                Column {
                    id: nbody
                    anchors.left: parent.left
                    anchors.right: ndismiss.left
                    anchors.rightMargin: 8 * root.s
                    spacing: 3 * root.s

                    Row {
                        width: parent.width
                        spacing: 6 * root.s
                        Text {
                            text: nrow.modelData.app
                            color: Theme.onSurfaceVariant
                            font.family: Theme.mono
                            font.pixelSize: 8 * root.s
                            font.weight: Font.DemiBold
                            font.letterSpacing: 1.2 * root.s
                            font.capitalization: Font.AllUppercase
                        }
                        Text {
                            visible: nrow.modelData.count > 1
                            text: "\u00d7" + nrow.modelData.count
                            color: Theme.primary
                            font.family: Theme.mono
                            font.pixelSize: 8 * root.s
                            font.weight: Font.DemiBold
                        }
                    }
                    Text {
                        width: parent.width
                        text: nrow.modelData.summary
                        elide: Text.ElideRight
                        color: Theme.onSurface
                        font.family: Theme.fontPrimary
                        font.pixelSize: 12 * root.s
                        font.weight: Font.Medium
                    }
                    Text {
                        width: parent.width
                        visible: nrow.modelData.body.length > 0
                        text: nrow.modelData.body
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                        color: Theme.onSurfaceVariant
                        font.family: Theme.fontPrimary
                        font.pixelSize: 10.5 * root.s
                    }
                }
            }
        }
    }
}
