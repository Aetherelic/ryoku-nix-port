pragma ComponentBehavior: Bound
import QtQuick

// One row of wallpaper tiles on an endless belt. It idle-drifts (dir +1
// rightwards, -1 leftwards), eases to a stop while the pointer is over the belt
// so a pick sits still, and a scroll adds a boost that decays back. Tiles stay
// alive and just slide (no per-tile create/destroy), so a fast scroll never
// churns; off-screen ones drop their thumbnail. A short set is repeated so the
// belt always fills.
Item {
    id: row
    clip: true

    required property real s
    required property var cells
    required property int dir
    required property real cellW
    required property real cellH
    required property int gap
    required property color bg
    property string current: ""       // wallpaper on screen (on-air dot)
    property string highlightKey: ""  // hovered path
    property bool running: true
    property bool hovering: false
    property bool scrollHold: false   // menu just took a wheel tick; hold video off

    signal entered(var entry)
    signal chosen(var entry)

    readonly property real step: cellW + gap
    readonly property var belt: {
        if (!cells || cells.length === 0 || width <= 0)
            return cells || [];
        var one = cells.length * step;
        var reps = Math.max(1, Math.ceil((width + 2 * cellW) / one));
        if (reps <= 1)
            return cells;
        var out = [];
        for (var r = 0; r < reps; r++)
            for (var i = 0; i < cells.length; i++)
                out.push(cells[i]);
        return out;
    }
    readonly property real setW: belt.length * step

    property real pos: 0
    property real boost: 0
    readonly property real base: 26 * s
    property real speed: 26 * s     // eased toward 0 while hovering, else base
    readonly property bool moving: Math.abs(row.dir * row.speed + row.boost) > 18

    function boostBy(delta) {
        row.boost = Math.max(-2400, Math.min(2400, row.boost + delta));
    }

    readonly property int centerIndex: {
        if (belt.length === 0 || setW === 0)
            return -1;
        var idx = Math.round((width / 2 - cellW / 2 - pos) / step);
        return ((idx % belt.length) + belt.length) % belt.length;
    }
    readonly property var centerEntry: (centerIndex >= 0 && centerIndex < belt.length) ? belt[centerIndex] : null

    FrameAnimation {
        running: row.running && row.setW > 0
        onTriggered: {
            var dt = Math.min(0.05, frameTime);
            var target = row.hovering ? 0 : row.base;
            row.speed += (target - row.speed) * Math.min(1, 8 * dt);
            row.boost -= row.boost * Math.min(1, 3.5 * dt);
            if (Math.abs(row.boost) < 0.5)
                row.boost = 0;
            var v = row.dir * row.speed + row.boost;
            row.pos = (((row.pos + v * dt) % row.setW) + row.setW) % row.setW;
        }
    }

    Repeater {
        model: row.belt
        delegate: Item {
            id: slot
            required property int index
            required property var modelData
            width: row.cellW
            height: row.cellH
            y: (row.height - height) / 2

            readonly property real raw: (((index * row.step + row.pos) % row.setW) + row.setW) % row.setW
            x: raw < row.width ? raw : (raw > row.setW - 2 * row.cellW ? raw - row.setW : raw)
            visible: x + width > -1 && x < row.width + 1

            WallTile {
                anchors.fill: parent
                item: slot.modelData
                current: row.current
                live: slot.visible
                beltMoving: row.moving || row.scrollHold
                selected: !!slot.modelData && slot.modelData.path === row.highlightKey
                onEntered: row.entered(slot.modelData)
                onChosen: row.chosen(slot.modelData)
            }
        }
    }

    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 40
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: row.bg }
            GradientStop { position: 1.0; color: Qt.alpha(row.bg, 0) }
        }
    }
    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 40
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(row.bg, 0) }
            GradientStop { position: 1.0; color: row.bg }
        }
    }
}
