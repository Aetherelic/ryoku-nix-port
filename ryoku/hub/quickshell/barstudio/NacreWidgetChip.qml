import QtQuick
import Ryoku.Ui.Singletons

Rectangle {
    id: root

    required property string widgetId
    required property string label
    required property string sourceIsland
    required property int sourceIndex
    property bool dragging: false

    width: text.implicitWidth + 20
    height: 32
    radius: Tokens.radius
    color: drag.active ? Tokens.bone : hover.hovered ? Tokens.tint10 : "transparent"
    border.width: Tokens.border
    border.color: drag.active ? Tokens.bone : Tokens.line
    z: drag.active ? 10 : 0

    Drag.active: root.dragging
    Drag.source: root
    Drag.keys: ["nacre-widget"]
    Drag.hotSpot.x: width / 2
    Drag.hotSpot.y: height / 2

    Text {
        id: text
        anchors.centerIn: parent
        text: root.label.toUpperCase()
        color: root.Drag.active ? Tokens.inkOnBone : Tokens.inkDim
        font.family: Tokens.ui
        font.pixelSize: 10
        font.weight: Font.Medium
        font.letterSpacing: Tokens.trackLabel
    }

    HoverHandler { id: hover; cursorShape: Qt.OpenHandCursor }
    DragHandler {
        id: drag
        onActiveChanged: {
            if (active) {
                root.dragging = true;
            } else {
                root.Drag.drop();
                root.dragging = false;
                root.x = 0;
                root.y = 0;
            }
        }
    }
}
