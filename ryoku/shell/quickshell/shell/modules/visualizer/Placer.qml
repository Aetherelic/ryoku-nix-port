pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"

// Placement: the look lives in a box, so drag it anywhere and drag the corner
// grip to size it, exactly like a desktop widget. Right click or Escape when done.
//
// Its own surface, because the spectrum window is click-through for life and a
// surface masked that way does not start taking a pointer again. Same geometry as
// that window (exclusions ignored), so a pointer position means the same in both.
PanelWindow {
    id: win

    required property var screen
    required property rect box     // the look's box in screen px
    required property color guide

    signal done

    screen: win.screen
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "ryoku-visualizer-place"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    anchors { top: true; bottom: true; left: true; right: true }

    readonly property real handle: Math.max(12, 14 * Math.min(2, Math.min(win.width, win.height) / 900))

    Rectangle {
        x: win.box.x
        y: win.box.y
        width: win.box.width
        height: win.box.height
        color: Qt.alpha(win.guide, 0.05)
        border.width: 1
        border.color: Qt.alpha(win.guide, 0.55)
        radius: 2
    }
    Text {
        x: Math.max(8, Math.min(win.width - width - 8, win.box.x))
        y: Math.max(8, Math.min(win.height - height - 8, win.box.y + win.box.height + 10))
        text: "DRAG TO MOVE   CORNER TO SIZE   RIGHT CLICK WHEN DONE"
        color: win.guide
        font.family: "monospace"
        font.pixelSize: Math.max(10, 11 * Math.min(2, Math.min(win.width, win.height) / 900))
        font.letterSpacing: 1.5
    }

    // the grip sits on the box's own corner, so it is always beside what it sizes
    Rectangle {
        id: grip
        width: win.handle
        height: win.handle
        radius: 2
        color: (grab.sizing || grab.onGrip) ? win.guide : Qt.alpha(win.guide, 0.45)
        border.width: 1
        border.color: win.guide
        x: win.box.x + win.box.width - width / 2
        y: win.box.y + win.box.height - height / 2
    }

    MouseArea {
        id: grab
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        focus: true
        cursorShape: grab.onGrip ? Qt.SizeFDiagCursor : Qt.SizeAllCursor

        property bool sizing: false
        property real pressX: 0
        property real pressY: 0
        property real baseX: 0
        property real baseY: 0
        property real baseW: 0
        property real baseH: 0
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
            grab.baseX = Config.x;
            grab.baseY = Config.y;
            grab.baseW = Config.w;
            grab.baseH = Config.h;
        }
        onReleased: grab.sizing = false
        // Both gestures apply the pointer's delta from where it was pressed, never
        // its absolute position, so nothing jumps out from under the cursor.
        onPositionChanged: (m) => {
            if (!grab.pressed)
                return;
            var dx = (m.x - grab.pressX) / Math.max(1, win.width);
            var dy = (m.y - grab.pressY) / Math.max(1, win.height);
            if (grab.sizing)
                Config.sizeBox(grab.baseW + dx, grab.baseH + dy);
            else
                Config.moveBox(grab.baseX + dx, grab.baseY + dy);
        }
        onWheel: (w) => {
            var k = w.angleDelta.y > 0 ? 1.06 : 0.94;
            Config.sizeBox(Config.w * k, Config.h * k);
        }
        Keys.onEscapePressed: win.done()
        Keys.onReturnPressed: win.done()
    }
}
