pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../../components"

// Feature sidebar behind Super+T: a framed floating card with a left activity
// rail over pluggable pages (Usage, Tools; room for more). The card keeps its
// roomy scaled footprint; only the text and icons inside read compact. It hugs
// its content height so it never leaves a dead half-panel.
Item {
    id: root

    property real s: 1
    property bool open: false
    property string monitorName: ""
    property string surfaceId: ""

    implicitWidth: 428 * root.s
    readonly property real contentH: contentLoader.item ? contentLoader.item.implicitHeight : 420 * root.s
    implicitHeight: Math.max(320 * root.s, Math.min(792 * root.s, root.contentH))

    // Adding a feature is one row here plus one branch in the Loader below.
    readonly property var tabs: [
        { id: "usage", icon: "insights", label: qsTr("Usage") },
        { id: "tools", icon: "download", label: qsTr("Tools") }
    ]
    property string activeTab: "usage"

    // ── frame ──
    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: Theme.outline
        SumiEdge { radius: Theme.radiusWidget }
    }

    // ── activity rail ──
    Item {
        id: rail
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 1
        width: 50 * root.s

        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin: 12 * root.s
            anchors.bottomMargin: 12 * root.s
            width: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)
        }

        Column {
            anchors.top: parent.top
            anchors.topMargin: 14 * root.s
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4 * root.s

            Repeater {
                model: root.tabs
                delegate: Item {
                    id: tab
                    required property var modelData
                    readonly property bool on: root.activeTab === modelData.id
                    width: 44 * root.s
                    height: 48 * root.s

                    Rectangle {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 36 * root.s
                        height: 36 * root.s
                        radius: width / 2
                        color: tab.on ? Theme.primary
                            : tapArea.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.09)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: Motion.fast } }

                        MaterialIcon {
                            anchors.centerIn: parent
                            font.pixelSize: 15 * root.s
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
                        font.pixelSize: 7 * root.s
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

    // ── content ──
    Item {
        anchors.left: rail.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 1
        clip: true

        Component { id: usagePage; PanelOverview { s: root.s; open: root.open } }
        Component {
            id: toolsPage
            PanelTools { s: root.s; open: root.open; monitorName: root.monitorName; surfaceId: root.surfaceId }
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: root.activeTab === "usage" ? usagePage
                : root.activeTab === "tools" ? toolsPage : null
        }
    }
}
