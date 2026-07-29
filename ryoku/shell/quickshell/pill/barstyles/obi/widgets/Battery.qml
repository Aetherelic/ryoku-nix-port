pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "../../.." as Pill
import "../components" as C

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

    function batteryGlyph(pct, charging) {
        const b = pct > 99 ? 100 : pct > 90 ? 90 : pct > 80 ? 80 : pct > 70 ? 70
            : pct > 60 ? 60 : pct > 50 ? 50 : pct > 40 ? 40 : pct > 30 ? 30
            : pct > 20 ? 20 : pct > 10 ? 10 : 0;
        return "battery-level-" + b + (charging ? "-charging" : "");
    }

    function profileLabel(name) {
        return name === "power-saver" ? "Power Saver"
            : name === "balanced" ? "Balanced"
            : name === "performance" ? "Performance"
            : name;
    }

    HoverHandler { id: hh }

    Row {
        id: rowr
        anchors.centerIn: parent
        spacing: 6

        Pill.SymbolIcon {
            anchors.verticalCenter: parent.verticalCenter
            name: root.batteryGlyph(Battery.pct, root.charging)
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

    C.Popout {
        target: root
        targetHovered: hh.hovered
        content: popContent
    }

    Component {
        id: popContent
        Item {
            implicitWidth: 300
            implicitHeight: col.implicitHeight + 36

            Column {
                id: col
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
                            name: root.batteryGlyph(Battery.pct, root.charging)
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
                                readonly property bool sel: PowerProfiles.profile === chip.modelData
                                width: (parent.width - parent.spacing * 2) / 3
                                height: chipLabel.implicitHeight + 12
                                radius: Theme.radiusWidget
                                color: chip.sel ? Theme.primary : "transparent"
                                border.width: Theme.borderWidth
                                border.color: chip.sel ? Theme.primary : Theme.outline

                                Text {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    width: parent.width - 8
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    text: root.profileLabel(chip.modelData)
                                    color: chip.sel ? Theme.onPrimary : Theme.onSurface
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
    }
}
