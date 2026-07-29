pragma ComponentBehavior: Bound

import QtQuick
import "../../../Singletons"
import "." as Components

Rectangle {
    id: root

    property string edge: "center"
    property var widgetIds: []
    property real barHeight: 40
    property real maxWidth: Number.POSITIVE_INFINITY
    property real surfaceOpacity: 0.82
    property real horizontalPadding: 12
    property real widgetSpacing: 8

    readonly property real naturalWidth: content.implicitWidth + root.horizontalPadding * 2

    width: Math.min(root.naturalWidth, root.maxWidth)
    height: root.barHeight
    clip: true
    color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, root.surfaceOpacity)
    border.width: Theme.borderWidth
    border.color: Theme.outline
    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: root.edge === "left" ? 0 : height / 3
    bottomRightRadius: root.edge === "right" ? 0 : height / 3

    Row {
        id: content
        anchors.centerIn: parent
        spacing: root.widgetSpacing

        Repeater {
            model: root.widgetIds
            delegate: Components.WidgetHost {
                required property string modelData
                widgetId: modelData
                barHeight: root.barHeight
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Behavior on width {
        NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
    }
}
