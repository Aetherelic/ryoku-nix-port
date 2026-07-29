pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../Singletons"
import "components"

PanelWindow {
    id: root

    property var modelData
    readonly property var settings: Config.normalizedNacre

    screen: root.modelData
    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: root.settings.height + 1
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-nacre"
    anchors { top: true; left: true; right: true }
    implicitHeight: root.settings.height + 1

    mask: Region {
        Region { item: leftIsland }
        Region { item: centerIsland }
        Region { item: rightIsland }
    }

    Rectangle {
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: 1
        color: Theme.outline
    }

    Island {
        id: centerIsland
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        edge: "center"
        widgetIds: root.settings.islands.center
        barHeight: root.settings.height
        surfaceOpacity: root.settings.opacity
        horizontalPadding: root.settings.padding
        widgetSpacing: root.settings.spacing
        maxWidth: root.width - root.settings.islandGap * 2
    }

    Island {
        id: leftIsland
        anchors.top: parent.top
        anchors.left: parent.left
        edge: "left"
        widgetIds: root.settings.islands.left
        barHeight: root.settings.height
        surfaceOpacity: root.settings.opacity
        horizontalPadding: root.settings.padding
        widgetSpacing: root.settings.spacing
        maxWidth: Math.max(0, centerIsland.x - root.settings.islandGap)
    }

    Island {
        id: rightIsland
        anchors.top: parent.top
        anchors.right: parent.right
        edge: "right"
        widgetIds: root.settings.islands.right
        barHeight: root.settings.height
        surfaceOpacity: root.settings.opacity
        horizontalPadding: root.settings.padding
        widgetSpacing: root.settings.spacing
        maxWidth: Math.max(0, root.width - centerIsland.x - centerIsland.width - root.settings.islandGap)
    }
}
