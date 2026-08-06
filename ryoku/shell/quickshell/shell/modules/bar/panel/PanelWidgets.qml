pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services
import "../../../components"
import "../framebars/menus" as Menus

// Widgets dashboard: a glance hero over the shared kit -- quick controls, now
// playing, system rings and the month calendar -- drawn from the same
// components as the quick-settings home so it reads in one language.
Item {
    id: root

    property real s: 1
    property bool open: false

    SystemClock { id: clock; precision: SystemClock.Minutes; enabled: root.open }

    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
        anchors.topMargin: 20 * root.s
        anchors.bottomMargin: 8 * root.s
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Column {
            id: col
            width: flick.width
            spacing: 16 * root.s

            Item {
                width: parent.width
                height: heroCol.implicitHeight

                Column {
                    id: heroCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 3 * root.s

                    Text {
                        text: Qt.formatTime(clock.date, "HH:mm")
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        font.family: Theme.display
                        font.pixelSize: 54 * root.s
                        font.weight: Font.Light
                    }
                    Row {
                        width: parent.width
                        spacing: 8 * root.s

                        Text {
                            text: Qt.locale().toString(clock.date, "dddd, MMMM d")
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            font.family: Theme.fontPrimary
                            font.pixelSize: Theme.fontMd * root.s
                        }
                        Text {
                            visible: Weather.available
                            text: "· " + Weather.temp + "  " + Weather.condition
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            font.family: Theme.fontPrimary
                            font.pixelSize: Theme.fontMd * root.s
                        }
                    }
                }

                Rectangle {
                    visible: Battery.present
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 6 * root.s
                    width: battRow.implicitWidth + 16 * root.s
                    height: 24 * root.s
                    radius: height / 2
                    color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.07)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)

                    Row {
                        id: battRow
                        anchors.centerIn: parent
                        spacing: 4 * root.s

                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            font.pixelSize: 14 * root.s
                            text: Battery.charging ? "bolt" : "battery_full"
                            color: Theme.inkOn(Theme.effectiveSurface, Battery.charging ? Theme.primary : Theme.onSurfaceVariant, 3.0)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Battery.pct + "%"
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                            font.family: Theme.fontPrimary
                            font.pixelSize: (Theme.fontSm - 1) * root.s
                            font.weight: Font.DemiBold
                        }
                    }
                }
            }

            Menus.QsSection { width: parent.width; label: qsTr("Controls") }
            Grid {
                id: tileGrid
                width: parent.width
                columns: 2
                columnSpacing: 8 * root.s
                rowSpacing: 8 * root.s
                readonly property real tileW: (width - columnSpacing) / 2

                Menus.QsTile {
                    width: tileGrid.tileW
                    icon: Network.kind === "ethernet" ? "lan" : "wifi"
                    label: qsTr("Wi-Fi")
                    sub: !Toggles.wifiOn ? qsTr("Off") : Network.activeSsid !== "" ? Network.activeSsid : qsTr("On")
                    on: Toggles.wifiOn
                    onToggled: Toggles.toggleWifi()
                }
                Menus.QsTile {
                    width: tileGrid.tileW
                    icon: "bluetooth"
                    label: qsTr("Bluetooth")
                    sub: Toggles.btOn ? qsTr("On") : qsTr("Off")
                    on: Toggles.btOn
                    onToggled: Toggles.toggleBt()
                }
                Menus.QsTile {
                    width: tileGrid.tileW
                    icon: "do_not_disturb_on"
                    label: qsTr("Do not disturb")
                    sub: Toggles.dnd ? qsTr("On") : qsTr("Off")
                    on: Toggles.dnd
                    onToggled: Toggles.toggleDnd()
                }
                Menus.QsTile {
                    width: tileGrid.tileW
                    icon: "coffee"
                    label: qsTr("Keep awake")
                    sub: Toggles.keepAwake ? qsTr("On") : qsTr("Off")
                    on: Toggles.keepAwake
                    onToggled: Toggles.toggleCaffeine()
                }
            }

            Menus.MediaHero {
                width: parent.width
                active: root.open
            }

            Menus.QsSection { width: parent.width; label: qsTr("System") }
            Rectangle {
                width: parent.width
                radius: Theme.radiusWidget
                color: Theme.surface
                border.width: Theme.borderWidth
                border.color: Theme.outline
                implicitHeight: sysMon.implicitHeight + 2 * (14 * root.s)
                SumiEdge {}

                SysMonitor {
                    id: sysMon
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 14 * root.s
                    s: root.s
                    active: root.open
                }
            }

            Menus.QsSection { width: parent.width; label: qsTr("Calendar") }
            Menus.QsCalendarEmbed {
                width: parent.width
                s: root.s
                open: root.open
            }

            Item { width: 1; height: 6 * root.s }
        }
    }
}
