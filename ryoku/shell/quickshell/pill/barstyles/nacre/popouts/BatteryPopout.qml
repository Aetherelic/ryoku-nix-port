pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../Format.js" as Format

Item {
    implicitWidth: 300
    implicitHeight: content.implicitHeight + 36

    Column {
        id: content
        anchors.centerIn: parent
        width: 260
        spacing: 12

        Column {
            width: parent.width
            spacing: 2

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 8

                Pill.SymbolIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Format.batteryGlyph(Battery.pct, Battery.charging || Battery.full)
                    size: 26
                    color: Battery.low ? Theme.error : Theme.onSurface
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Battery.pct + "%"
                    color: Battery.low ? Theme.error : Theme.onSurface
                    font.family: Theme.mono
                    font.pixelSize: Theme.fontXxl
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Battery.stateLabel + (Battery.hasTime
                    ? " · " + Battery.timeStr + (Battery.charging ? " to full" : " left")
                    : "")
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
            }
        }

        Text {
            visible: Battery.healthSupported
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Health " + Battery.health + "%"
            color: Theme.onSurfaceVariant
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
        }

        Column {
            width: parent.width
            spacing: 6
            visible: PowerProfiles.available

            Text {
                text: "POWER MODE"
                color: Theme.onSurfaceVariant
                font.family: Theme.mono
                font.pixelSize: Theme.fontSm
                font.letterSpacing: 1.5
            }
            Row {
                width: parent.width
                spacing: 6

                Repeater {
                    model: PowerProfiles.profiles
                    delegate: Rectangle {
                        id: chip
                        required property var modelData
                        readonly property bool selected: PowerProfiles.profile === chip.modelData
                        width: (parent.width - parent.spacing * 2) / 3
                        height: label.implicitHeight + 12
                        radius: Theme.radiusWidget
                        color: chip.selected ? Theme.primary : "transparent"
                        border.width: Theme.borderWidth
                        border.color: chip.selected ? Theme.primary : Theme.outline

                        Text {
                            id: label
                            anchors.centerIn: parent
                            width: parent.width - 8
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: Format.profileLabel(chip.modelData)
                            color: chip.selected ? Theme.onPrimary : Theme.onSurface
                            font.family: Theme.fontPrimary
                            font.pixelSize: Theme.fontSm
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: PowerProfiles.setProfile(chip.modelData)
                        }
                    }
                }
            }
        }
    }
}
