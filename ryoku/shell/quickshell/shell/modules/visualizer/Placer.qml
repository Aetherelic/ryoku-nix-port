pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"

// Placement for the polar looks: drag the shape where you want it, drag the grip
// on its edge to size it, right click or Escape when done.
//
// Its own surface, because the spectrum window is click-through for life and a
// surface masked that way does not start taking a pointer again. Same geometry as
// that window (exclusions ignored), so a pointer position means the same thing in
// both.
PanelWindow {
    id: win

    required property var screen
    required property real shapeRadius
    required property color guide

    signal done

    screen: win.screen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "ryoku-visualizer-place"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property real short: Math.max(1, Math.min(win.width, win.height))
    readonly property real cx: Config.originX * win.width
    readonly property real cy: Config.originY * win.height
    readonly property real handle: Math.max(11, 13 * Math.min(2, win.short / 900))

    // the shape's own outline, so what is being placed is unmistakable
    Rectangle {
        x: win.cx - win.shapeRadius
        y: win.cy - win.shapeRadius
        width: win.shapeRadius * 2
        height: win.shapeRadius * 2
        radius: width / 2
        color: Qt.alpha(win.guide, 0.04)
        border.width: 1
        border.color: Qt.alpha(win.guide, 0.5)
    }
    Rectangle {
        x: win.cx - width / 2; y: win.cy - height / 2
        width: 17; height: 1; color: win.guide
    }
    Rectangle {
        x: win.cx - width / 2; y: win.cy - height / 2
        width: 1; height: 17; color: win.guide
    }
    Text {
        x: Math.max(8, Math.min(win.width - width - 8, win.cx - width / 2))
        y: Math.min(win.height - height - 8, win.cy + win.shapeRadius + 14)
        text: "DRAG TO MOVE   EDGE GRIP TO SIZE   RIGHT CLICK WHEN DONE"
        color: win.guide
        font.family: "monospace"
        font.pixelSize: Math.max(10, 11 * Math.min(2, win.short / 900))
        font.letterSpacing: 1.5
    }

    // The grip rides the shape's edge, level with its centre, so sizing is one
    // axis: the radius is the pointer's distance out from the centre and the grip
    // stays exactly under the cursor. Off the corner of a padded box it could not:
    // a corner sits radius * sqrt(2) out, so treating that distance as the radius
    // grew the shape and slid the grip out from under the hand.
    Rectangle {
        id: grip
        width: win.handle
        height: win.handle
        radius: 2
        color: (grab.sizing || grab.onGrip) ? win.guide : Qt.alpha(win.guide, 0.4)
        border.width: 1
        border.color: win.guide
        x: win.cx + win.shapeRadius - width / 2
        y: win.cy - height / 2
    }

    MouseArea {
        id: grab
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        focus: true
        cursorShape: grab.onGrip ? Qt.SizeHorCursor : Qt.SizeAllCursor

        property bool sizing: false
        property real pressX: 0
        property real pressY: 0
        property real baseX: 0
        property real baseY: 0
        property real baseSize: 0
        readonly property bool onGrip: Math.abs(grab.mouseX - (grip.x + grip.width / 2)) < win.handle
            && Math.abs(grab.mouseY - (grip.y + grip.height / 2)) < win.handle

        onPressed: (m) => {
            if (m.button === Qt.RightButton) {
                win.done();
                return;
            }
            grab.sizing = grab.onGrip;
            grab.pressX = m.x;
            grab.pressY = m.y;
            grab.baseX = win.cx;
            grab.baseY = win.cy;
            grab.baseSize = Config.size;
        }
        onReleased: grab.sizing = false
        // Both gestures move by the pointer's delta from where it was pressed,
        // never by its absolute position: that is what keeps the grip under the
        // cursor instead of snapping the edge to it on the first motion.
        onPositionChanged: (m) => {
            if (!grab.pressed)
                return;
            if (grab.sizing)
                Config.resize(grab.baseSize + (m.x - grab.pressX) / win.short);
            else
                Config.place((grab.baseX + m.x - grab.pressX) / Math.max(1, win.width),
                             (grab.baseY + m.y - grab.pressY) / Math.max(1, win.height));
        }
        onWheel: (w) => Config.resize(Config.size * (w.angleDelta.y > 0 ? 1.06 : 0.94))
        Keys.onEscapePressed: win.done()
        Keys.onReturnPressed: win.done()
    }
}
