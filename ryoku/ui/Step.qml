import QtQuick
import "Singletons"

// bounded integer. the value itself lives in the cell's numeral; this is only
// the pair of buttons. holding repeats, and an exhausted bound disables.
Row {
    id: step
    property int value: 0
    property int from: 0
    property int to: 100
    property int stepBy: (to - from) > 60 ? 4 : 1
    signal modified(int v)
    function activate(up) {
        if ((up && value < to) || (!up && value > from)) bump(up);
    }


    spacing: 0

    Repeater {
        model: ["−", "+"]
        Rectangle {
            required property string modelData
            required property int index
            readonly property bool up: index === 1
            readonly property bool spent: up ? step.value >= step.to : step.value <= step.from
            activeFocusOnTab: !spent

            width: 29
            height: 24
            radius: Tokens.radius
            opacity: spent ? 0.3 : 1
            color: (bh.hovered || activeFocus) && !spent ? Tokens.tint10 : "transparent"
            border.width: Tokens.border
            border.color: (bh.hovered || activeFocus) && !spent ? Tokens.lineStrong : Tokens.line
            Behavior on color { ColorAnimation { duration: Tokens.snap } }

            Text {
                anchors.centerIn: parent
                text: parent.modelData
                color: Tokens.inkDim
                font.family: Tokens.ui
                font.pixelSize: 13
            }
            HoverHandler { id: bh; enabled: !parent.spent; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                enabled: !parent.spent
                longPressThreshold: 0.4
                onTapped: step.activate(parent.up)
                onLongPressed: repeat.start()
                onPressedChanged: if (!pressed) repeat.stop()
                onCanceled: repeat.stop()
            }
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    step.activate(up)
                    event.accepted = true
                }
            }
            Timer {
                id: repeat
                interval: 125
                repeat: true
                onTriggered: parent.spent ? stop() : step.bump(parent.up)
            }
        }
    }
    function bump(up) {
        var v = value + (up ? stepBy : -stepBy);
        modified(Math.max(from, Math.min(to, v)));
    }
}
