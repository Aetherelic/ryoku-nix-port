pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Singletons"
import "components" as Components

PanelWindow {
    id: root

    property var modelData
    readonly property var settings: Config.normalizedNacre
    readonly property real frameInset: root.settings.frame ? Config.frameThickness : 0

    screen: root.modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.settings.height + root.frameInset
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-nacre"
    anchors { top: true; left: true; right: true }
    implicitHeight: root.settings.height + root.frameInset

    mask: Region {
        Region { item: leftIsland }
        Region { item: centerIsland }
        Region { item: rightIsland }
    }

    Components.Island {
        id: centerIsland
        anchors.top: parent.top
        anchors.topMargin: root.frameInset
        anchors.horizontalCenter: parent.horizontalCenter
        edge: "center"
        widgetIds: root.settings.islands.center
        barHeight: root.settings.height
        surfaceOpacity: root.settings.opacity
        horizontalPadding: root.settings.padding
        widgetSpacing: root.settings.spacing
        maxWidth: Math.max(root.settings.height,
            root.width - (root.settings.height + root.settings.islandGap) * 2)
    }

    Components.Island {
        id: leftIsland
        anchors.top: parent.top
        anchors.topMargin: root.frameInset
        anchors.left: parent.left
        edge: "left"
        widgetIds: root.settings.islands.left
        barHeight: root.settings.height
        surfaceOpacity: root.settings.opacity
        horizontalPadding: root.settings.padding
        widgetSpacing: root.settings.spacing
        maxWidth: Math.max(root.settings.height,
            centerIsland.x - root.settings.islandGap)
    }

    Components.Island {
        id: rightIsland
        anchors.top: parent.top
        anchors.topMargin: root.frameInset
        anchors.right: parent.right
        edge: "right"
        widgetIds: root.settings.islands.right
        barHeight: root.settings.height
        surfaceOpacity: root.settings.opacity
        horizontalPadding: root.settings.padding
        widgetSpacing: root.settings.spacing
        maxWidth: Math.max(root.settings.height,
            root.width - centerIsland.x - centerIsland.width - root.settings.islandGap)
    }
}
