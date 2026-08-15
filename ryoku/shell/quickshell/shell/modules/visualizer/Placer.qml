pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Ui
import Ryoku.Ui.Singletons as Ui
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

    // Handles are token-sized: the shell's control metrics are already tuned for
    // this screen, so a second scale of its own would fight them.
    readonly property real handle: Ui.Tokens.s4
    // Rotation is about the box centre, which is the one point a turn never moves.
    readonly property real cx: win.box.x + win.box.width / 2
    readonly property real cy: win.box.y + win.box.height / 2

    // --- gesture smoothing ----------------------------------------------------
    // A gesture aims at a target and the box eases toward it, so a hand that is not
    // perfectly steady still lands a clean size and angle. The target comes from the
    // pointer's delta, so easing only ever lags: it converges on exactly where the
    // pointer asked, never somewhere else. It keeps running after the release until
    // it has arrived, or letting go mid-drag would strand the box short of the
    // pointer.
    property string gesture: ""
    property real tx: 0
    property real ty: 0
    property real tw: 0
    property real th: 0
    property real tAngle: 0

    Timer {
        id: ease
        interval: 16
        repeat: true
        running: win.gesture !== ""
        onTriggered: {
            var k = 0.32;
            var eps = 0.0006;
            var done = false;
            if (win.gesture === "turn") {
                // Angles are eased the short way round, or a pass through 360 would
                // send the look the long way back.
                var d = PlaceMath.shortestTurn(Config.angle, win.tAngle);
                done = Math.abs(d) < 0.05;
                Config.rotate(done ? win.tAngle : Config.angle + d * k);
            } else if (win.gesture === "move") {
                done = Math.abs(win.tx - Config.x) < eps && Math.abs(win.ty - Config.y) < eps;
                if (done)
                    Config.moveBox(win.tx, win.ty);
                else
                    Config.moveBox(Config.x + (win.tx - Config.x) * k,
                                   Config.y + (win.ty - Config.y) * k);
            } else {
                done = Math.abs(win.tx - Config.x) < eps && Math.abs(win.ty - Config.y) < eps
                    && Math.abs(win.tw - Config.w) < eps && Math.abs(win.th - Config.h) < eps;
                if (done)
                    Config.setBox(win.tx, win.ty, win.tw, win.th);
                else
                    Config.setBox(Config.x + (win.tx - Config.x) * k,
                                  Config.y + (win.ty - Config.y) * k,
                                  Config.w + (win.tw - Config.w) * k,
                                  Config.h + (win.th - Config.h) * k);
            }
            // The gesture is only over once the hand is off and the box has caught up.
            if (done && grab.mode === "")
                win.gesture = "";
        }
    }

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
            win.gesture = grab.over;
            grab.pressX = m.x;
            grab.pressY = m.y;
            grab.baseX = Config.x;
            grab.baseY = Config.y;
            grab.baseW = Config.w;
            grab.baseH = Config.h;
            grab.baseAngle = Config.angle;
            grab.pressAngle = PlaceMath.angleAt(win.cx, win.cy, m.x, m.y);
            win.tx = Config.x;
            win.ty = Config.y;
            win.tw = Config.w;
            win.th = Config.h;
            win.tAngle = Config.angle;
        }
        onReleased: grab.mode = ""
        // Every gesture applies the pointer's delta from where it was pressed, never
        // its absolute position, so nothing jumps out from under the cursor.
        onPositionChanged: (m) => {
            if (!grab.pressed || grab.mode === "")
                return;
            if (grab.mode === "turn") {
                // Close to the centre a pixel of travel is a wild swing, so the turn
                // only takes the pointer once it is out where the lever is.
                if (Math.hypot(m.x - win.cx, m.y - win.cy) < win.handle * 1.5)
                    return;
                var want = grab.baseAngle
                    + PlaceMath.angleAt(win.cx, win.cy, m.x, m.y) - grab.pressAngle;
                win.tAngle = PlaceMath.magnet(want, 15, 2.5);
                return;
            }
            var dx = m.x - grab.pressX;
            var dy = m.y - grab.pressY;
            if (grab.mode === "move") {
                win.tx = grab.baseX + dx / Math.max(1, win.width);
                win.ty = grab.baseY + dy / Math.max(1, win.height);
                return;
            }
            var out = PlaceMath.resize({ x: grab.baseX, y: grab.baseY, w: grab.baseW, h: grab.baseH },
                                       grab.baseAngle, dx, dy,
                                       { w: win.width, h: win.height }, { w: 0.04, h: 0.03 });
            win.tx = out.x;
            win.ty = out.y;
            win.tw = out.w;
            win.th = out.h;
        }
        onWheel: (w) => {
            var k = w.angleDelta.y > 0 ? 1.06 : 0.94;
            Config.sizeBox(Config.w * k, Config.h * k);
        }
        Keys.onEscapePressed: {
            if (editBar.trayOpen)
                editBar.closeTray();
            else
                win.done();
        }
        Keys.onReturnPressed: win.done()
        Keys.onPressed: (e) => {
            if (e.key === Qt.Key_F) {
                Config.flip();
                e.accepted = true;
            } else if (e.key === Qt.Key_M) {
                if (Config.mirrorApplies)
                    Config.toggleMirror();
                e.accepted = true;
            } else if (e.key === Qt.Key_P) {
                if (Config.peaksApply)
                    Config.togglePeaks();
                e.accepted = true;
            } else if (e.key === Qt.Key_R) {
                Config.rotate(0);
                e.accepted = true;
            } else if (e.key === Qt.Key_BracketLeft) {
                Config.cycleStyle(-1);
                e.accepted = true;
            } else if (e.key === Qt.Key_BracketRight) {
                Config.cycleStyle(1);
                e.accepted = true;
            }
        }
    }

    // Everything you tune while looking at it: its own component, since the window's
    // job is the placement gestures and the bar's job is the controls.
    EditBar {
        id: editBar
        box: win.box
        onDone: win.done()
    }
}
