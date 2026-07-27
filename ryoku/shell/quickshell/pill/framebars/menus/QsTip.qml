import QtQuick
import "../../Singletons"

// Hover bubble: names an icon-only control. Shows above (default), below, or
// to the RIGHT (side: true) after a short hover dwell. `side: true` is used
// on the left tab rail so the bubble never clips against the panel left edge.
// Never takes input.
Item {
    id: root

    property string text: ""
    property bool hovered: false
    property bool below: false
    // side: true  => bubble appears to the RIGHT, vertically centred.
    // Takes precedence over `below`.
    property bool side: false

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

        // z:1000 guarantees the bubble paints above every sibling subtree
        // inside the panel. QsTabRail is hoisted to z:10 in mainBand so its
        // entire rendering subtree (including this bubble) is above contentPane.
        z: 1000

        // Explicit positioning. No anchors on x-axis so side-mode x doesn't
        // conflict. For non-side mode we compute center manually; the binding
        // re-evaluates whenever `width` changes so it stays centred.
        readonly property real gap: root.showing ? 8 : 4

        x: root.side
            ? parent.width + gap          // to the RIGHT of the icon button
            : (parent.width - width) / 2  // horizontally centred above/below

        y: root.side
            ? (parent.height - height) / 2  // vertically centred alongside icon
            : root.below
                ? parent.height + gap
                : -height - gap

        width: cap.implicitWidth + 16
        height: cap.implicitHeight + 10
        radius: height / 2
        color: Theme.surfaceContainerHigh ? Theme.surfaceContainerHigh : Theme.surface
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
        opacity: root.showing ? 1 : 0
        scale: root.showing ? 1 : 0.92
        visible: opacity > 0.004

        Behavior on x { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on y { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

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
