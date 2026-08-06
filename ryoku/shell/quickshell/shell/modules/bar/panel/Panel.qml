pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../../components"

// Feature sidebar behind Super+T: a left activity rail over pluggable pages.
// The shell Popout blob is the surface, so this stays transparent.
Item {
    id: root

    property real s: 1
    property bool open: false
    property string monitorName: ""
    property string surfaceId: ""

    implicitWidth: 476 * root.s

    // Adding a feature is one row here plus one branch in the Loader below.
    readonly property var tabs: [
        { id: "widgets", icon: "widgets", label: qsTr("Widgets") },
        { id: "tools", icon: "download", label: qsTr("Tools") }
    ]
    property string activeTab: "widgets"

    Item {
        id: rail
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 66 * root.s

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.20)
        }

        Column {
            anchors.top: parent.top
            anchors.topMargin: 18 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 6 * root.s

            Repeater {
                model: root.tabs
                delegate: Item {
                    id: tab
                    required property var modelData
                    readonly property bool on: root.activeTab === modelData.id
                    width: 58 * root.s
                    height: 56 * root.s

                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 42 * root.s
                        height: 42 * root.s
                        radius: width / 2
                        color: tab.on ? Theme.primary
                            : tapArea.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.09)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            font.pixelSize: 22 * root.s
                            text: tab.modelData.icon
                            fill: tab.on ? 1 : 0
                            color: tab.on ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                                : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            Behavior on color { ColorAnimation { duration: Motion.fast } }
                        }
                    }

                    Text {
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: tab.modelData.label
                        color: tab.on ? Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                            : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        font.family: Theme.fontPrimary
                        font.pixelSize: 9 * root.s
                        font.weight: tab.on ? Font.DemiBold : Font.Normal
                    }

                    scale: tapArea.pressed ? 0.9 : 1
                    Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2 } }

                    MouseArea {
                        id: tapArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = tab.modelData.id
                    }
                }
            }
        }
    }

    Item {
        anchors.left: rail.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true

        Component { id: widgetsPage; PanelWidgets { s: root.s; open: root.open } }
        Component {
            id: toolsPage
            PanelTools { s: root.s; open: root.open; monitorName: root.monitorName; surfaceId: root.surfaceId }
        }

        Loader {
            anchors.fill: parent
            sourceComponent: root.activeTab === "widgets" ? widgetsPage
                : root.activeTab === "tools" ? toolsPage : null
        }
    }
}
