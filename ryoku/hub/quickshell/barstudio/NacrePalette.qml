pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui.Singletons

Rectangle {
    id: root

    required property var items
    required property var labelFor
    signal removed(string widgetId)

    objectName: "nacre-palette"
    height: Math.max(54, content.implicitHeight + Tokens.s4)
    radius: Tokens.radius
    color: drop.containsDrag ? Tokens.tint10 : "transparent"
    border.width: Tokens.border
    border.color: drop.containsDrag ? Tokens.lineStrong : Tokens.line

    Flow {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: Tokens.s2 }
        spacing: Tokens.s1

        Text {
            text: qsTr("UNUSED")
            color: Tokens.inkFaint
            font.family: Tokens.mono
            font.pixelSize: Tokens.fTiny
            font.letterSpacing: Tokens.trackLabel
            height: 32
            verticalAlignment: Text.AlignVCenter
        }
        Repeater {
            model: root.items
            delegate: NacreWidgetChip {
                required property string modelData
                required property int index
                widgetId: modelData
                label: root.labelFor(modelData)
                sourceIsland: ""
                sourceIndex: index
            }
        }
    }

    DropArea {
        id: drop
        anchors.fill: parent
        keys: ["nacre-widget"]
        onDropped: event => root.removed(event.source.widgetId)
    }
}
