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
    property real islandScale: 1
    property bool unifiedFrame: false

    signal popupRequested(string name, real center, bool active, bool pinned)

    readonly property bool hasWidgets: root.widgetIds.length > 0
    readonly property real naturalWidth: root.hasWidgets
        ? content.implicitWidth + root.horizontalPadding * root.islandScale * 2 : 0
    readonly property real minimumWidth: root.hasWidgets
        ? Math.min(root.naturalWidth, root.barHeight * root.islandScale) : 0

    width: Math.max(root.minimumWidth, Math.min(root.naturalWidth, root.maxWidth))
    height: root.hasWidgets ? root.barHeight * root.islandScale : 0
    visible: root.hasWidgets
    clip: true
    color: root.unifiedFrame ? "transparent"
        : Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, root.surfaceOpacity)
    border.width: root.unifiedFrame ? 0 : Theme.borderWidth
    border.color: Theme.outline
    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: root.edge === "left" ? 0 : height / 3
    bottomRightRadius: root.edge === "right" ? 0 : height / 3

    Row {
        id: content
        anchors.centerIn: parent
        spacing: root.widgetSpacing * root.islandScale

        Repeater {
            model: root.widgetIds
            delegate: Item {
                required property string modelData

                width: host.width * root.islandScale
                height: host.height * root.islandScale

                Components.WidgetHost {
                    id: host
                    widgetId: parent.modelData
                    barHeight: root.barHeight
                    scale: root.islandScale
                    transformOrigin: Item.TopLeft
                    onPopupRequested: (name, center, active, pinned) =>
                        root.popupRequested(name, center, active, pinned)
                }
            }
        }
    }

    Behavior on width {
        NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
    }
}
