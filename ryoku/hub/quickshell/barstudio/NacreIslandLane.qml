pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui.Singletons

Rectangle {
    id: root

    required property string islandId
    required property var items
    required property var labelFor
    signal moved(string widgetId, string sourceIsland, string targetIsland, int targetIndex)

    objectName: "nacre-island-" + root.islandId
    height: 92
    radius: Tokens.radius
    color: drop.containsDrag ? Tokens.tint10 : "transparent"
    border.width: Tokens.border
    border.color: drop.containsDrag ? Tokens.lineStrong : Tokens.line

    function insertionIndex(position) {
        for (let index = 0; index < chips.count; index++) {
            const chip = chips.itemAt(index);
            if (chip && position < chip.x + chip.width / 2)
                return index;
        }
        return root.items.length;
    }

    Text {
        anchors { top: parent.top; left: parent.left; margins: Tokens.s2 }
        text: root.islandId.toUpperCase()
        color: Tokens.inkFaint
        font.family: Tokens.mono
        font.pixelSize: Tokens.fTiny
        font.letterSpacing: Tokens.trackLabel
    }

    Flow {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tokens.s2; topMargin: 34 }
        spacing: Tokens.s1

        Repeater {
            id: chips
            model: root.items
            delegate: NacreWidgetChip {
                required property string modelData
                required property int index
                widgetId: modelData
                label: root.labelFor(modelData)
                sourceIsland: root.islandId
                sourceIndex: index
            }
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["nacre-widget"]
        onDropped: event => root.moved(
            event.source.widgetId,
            event.source.sourceIsland,
            root.islandId,
            root.insertionIndex(event.x)
        )
    }
}
