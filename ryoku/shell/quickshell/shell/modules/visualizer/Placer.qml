pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"

// Placement: the look lives in a box, so drag it anywhere, drag the corner grip to
// size it, drag the dot on its top edge to turn it through a full circle, and flip
// it with the button or F. Right click or Escape when done.
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

    readonly property real ui: Math.min(2, Math.min(win.width, win.height) / 900)
    readonly property real handle: Math.max(12, 14 * win.ui)
    // Rotation is about the box centre, which is the one point a turn never moves.
    readonly property real cx: win.box.x + win.box.width / 2
    readonly property real cy: win.box.y + win.box.height / 2

    // The frame carries the look's own turn, so every guide on it lands where the
    // thing being placed actually is rather than where its box would be unturned.
    Item {
        id: frame
        x: win.box.x
        y: win.box.y
        width: win.box.width
        height: win.box.height
        rotation: Config.angle
        transformOrigin: Item.Center

        Rectangle {
            anchors.fill: parent
            color: Qt.alpha(win.guide, 0.05)
            border.width: 1
            border.color: Qt.alpha(win.guide, 0.55)
            radius: 2
        }

        // the grip sits on the box's own corner, so it is always beside what it sizes
        Rectangle {
            id: grip
            width: win.handle
            height: win.handle
            radius: 2
            color: (grab.mode === "size" || grab.over === "size") ? win.guide : Qt.alpha(win.guide, 0.45)
            border.width: 1
            border.color: win.guide
            x: parent.width - width / 2
            y: parent.height - height / 2
        }

        // the turn handle stands off the top edge on a stem, so it reads as a lever
        // rather than another corner
        Rectangle {
            width: 1
            height: win.handle * 1.6
            color: Qt.alpha(win.guide, 0.55)
            x: parent.width / 2
            y: -height
        }
        Rectangle {
            id: spinner
            width: win.handle
            height: win.handle
            radius: width / 2
            color: (grab.mode === "turn" || grab.over === "turn") ? win.guide : Qt.alpha(win.guide, 0.45)
            border.width: 1
            border.color: win.guide
            x: parent.width / 2 - width / 2
            y: -win.handle * 1.6 - height / 2
        }
    }

    // The readout stays level with the screen, so it is legible at every angle.
    Row {
        id: bar
        spacing: Math.round(10 * win.ui)
        x: Math.max(8, Math.min(win.width - width - 8, win.cx - width / 2))
        y: Math.max(8, Math.min(win.height - height - 8, win.box.y + win.box.height + 14 * win.ui))

        Rectangle {
            width: flipText.width + Math.round(18 * win.ui)
            height: flipText.height + Math.round(10 * win.ui)
            radius: height / 2
            color: flipArea.containsPress ? win.guide : Qt.alpha(win.guide, flipArea.containsMouse ? 0.3 : 0.12)
            border.width: 1
            border.color: Qt.alpha(win.guide, 0.7)

            Text {
                id: flipText
                anchors.centerIn: parent
                text: "FLIP"
                color: flipArea.containsPress ? "black" : win.guide
                font.family: "monospace"
                font.pixelSize: Math.max(10, 11 * win.ui)
                font.letterSpacing: 1.5
            }
            MouseArea {
                id: flipArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Config.flip()
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "DRAG TO MOVE   CORNER TO SIZE   TOP DOT TO TURN ("
                + Math.round(Config.angle) + "\u00b0)   RIGHT CLICK WHEN DONE"
            color: win.guide
            font.family: "monospace"
            font.pixelSize: Math.max(10, 11 * win.ui)
            font.letterSpacing: 1.5
        }
    }

    MouseArea {
        id: grab
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        focus: true
        cursorShape: grab.over === "size" ? Qt.SizeFDiagCursor
            : (grab.over === "turn" ? Qt.CrossCursor : Qt.SizeAllCursor)

        // Which gesture a press starts is decided by where it lands. The handles
        // ride a turned frame, so their screen positions are mapped rather than
        // computed: a mapped centre is right at every angle.
        function near(it, mx, my) {
            var p = it.mapToItem(null, it.width / 2, it.height / 2);
            return Math.abs(mx - p.x) < win.handle && Math.abs(my - p.y) < win.handle;
        }
        readonly property string over: grab.near(spinner, grab.mouseX, grab.mouseY) ? "turn"
            : (grab.near(grip, grab.mouseX, grab.mouseY) ? "size" : "move")

        property string mode: ""
        property real pressX: 0
        property real pressY: 0
        property real baseX: 0
        property real baseY: 0
        property real baseW: 0
        property real baseH: 0
        property real baseAngle: 0
        property real pressAngle: 0

        onPressed: (m) => {
            if (m.button === Qt.RightButton) {
                win.done();
                return;
            }
            grab.mode = grab.over;
            grab.pressX = m.x;
            grab.pressY = m.y;
            grab.baseX = Config.x;
            grab.baseY = Config.y;
            grab.baseW = Config.w;
            grab.baseH = Config.h;
            grab.baseAngle = Config.angle;
            grab.pressAngle = Math.atan2(m.y - win.cy, m.x - win.cx) * 180 / Math.PI;
        }
        onReleased: grab.mode = ""
        // Every gesture applies the pointer's delta from where it was pressed, never
        // its absolute position, so nothing jumps out from under the cursor.
        onPositionChanged: (m) => {
            if (!grab.pressed || grab.mode === "")
                return;
            if (grab.mode === "turn") {
                var ang = Math.atan2(m.y - win.cy, m.x - win.cx) * 180 / Math.PI;
                Config.rotate(grab.baseAngle + ang - grab.pressAngle);
                return;
            }
            var dx = m.x - grab.pressX;
            var dy = m.y - grab.pressY;
            if (grab.mode === "move") {
                Config.moveBox(grab.baseX + dx / Math.max(1, win.width),
                               grab.baseY + dy / Math.max(1, win.height));
                return;
            }
            // Sizing a turned box: the pointer moves in screen space, the box grows
            // along its own axes, so the delta is rotated into the box before use.
            // Without this a turned box grows sideways to the drag.
            var a = -Config.angle * Math.PI / 180;
            var lx = dx * Math.cos(a) - dy * Math.sin(a);
            var ly = dx * Math.sin(a) + dy * Math.cos(a);
            Config.sizeBox(grab.baseW + lx / Math.max(1, win.width),
                           grab.baseH + ly / Math.max(1, win.height));
        }
        onWheel: (w) => {
            var k = w.angleDelta.y > 0 ? 1.06 : 0.94;
            Config.sizeBox(Config.w * k, Config.h * k);
        }
        Keys.onEscapePressed: win.done()
        Keys.onReturnPressed: win.done()
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_F) {
                Config.flip();
                e.accepted = true;
            } else if (e.key === Qt.Key_R) {
                Config.rotate(0);
                e.accepted = true;
            }
        }
    }
}
