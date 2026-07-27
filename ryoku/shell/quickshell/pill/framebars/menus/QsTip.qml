import QtQuick
import "../../Singletons"

// Hover bubble: names an icon-only control. Shows above the control after a
// short hover dwell, with a soft rise-and-fade; never takes input.
Item {
    id: root

    property string text: ""
    property bool hovered: false
    // Bubble rises above by default; set below for controls at the top edge.
    property bool below: false

    readonly property bool showing: root.hovered && root.text.length > 0 && dwell.done
    anchors.fill: parent

    Timer {
        id: dwell
        property bool done: false
        interval: 320
        running: root.hovered
        onTriggered: dwell.done = true
    }
    onHoveredChanged: if (!root.hovered) dwell.done = false

    Rectangle {
        id: bubble
        anchors.horizontalCenter: parent.horizontalCenter
        y: root.below
            ? parent.height + (root.showing ? 8 : 4)
            : -height - (root.showing ? 8 : 4)
        width: cap.implicitWidth + 16
        height: cap.implicitHeight + 10
        radius: height / 2
        color: Theme.surfaceContainerHigh ? Theme.surfaceContainerHigh : Theme.surface
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.92
        visible: opacity > 0.004
        z: 100

        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
        Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Text {
            id: cap
            anchors.centerIn: parent
            text: root.text
            color: Theme.inkOn(bubble.color, Theme.onSurface)
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm - 2
            font.weight: Font.DemiBold
        }
    }
}
