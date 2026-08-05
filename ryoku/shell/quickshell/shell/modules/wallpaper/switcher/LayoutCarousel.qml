pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Carousel (cover-flow) layout: the focused entry stands big and square-on at
// centre; its neighbours are smaller slices that lean away with a shear, fading
// with distance, so the row reads with depth. Selection slides on an OutCubic
// glide. Reuses WallCell / ThemeCell for the tile content.
Item {
    id: car

    required property real s
    required property var model
    required property string kind
    required property color bg
    property int selIndex: 0
    property bool active: true
    property string activeKey: ""
    property bool interactive: true
    property int columns: 1
    signal focusIndex(int i)
    signal chosen(int i)

    readonly property int count: model ? model.length : 0
    readonly property real focusedH: Math.min(height - Math.round(20 * s),
        Math.round((kind === "theme" ? 300 : 284) * s))
    readonly property real focusedW: kind === "theme" ? Math.round(focusedH * 0.82) : Math.round(focusedH * 16 / 9)
    readonly property real sliceW: kind === "theme" ? Math.round(focusedW * 0.52) : Math.round(focusedW * 0.32)
    readonly property real sliceH: Math.round(focusedH * 0.8)
    readonly property int gap: Math.round(16 * s)
    readonly property int maxVisible: 6
    readonly property real leanShear: 0.32

    property bool moving: false
    onSelIndexChanged: { car.moving = true; movingCool.restart(); }
    Timer { id: movingCool; interval: 320; onTriggered: car.moving = false }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            var step = e.angleDelta.y < 0 ? 1 : -1;
            var ni = Math.max(0, Math.min(car.count - 1, car.selIndex + step));
            if (ni !== car.selIndex) car.focusIndex(ni);
        }
    }

    // left edge for relative offset; sides start just outside the focused slab.
    function leftEdge(rel) {
        var cx = car.width / 2;
        if (rel === 0) return cx - car.focusedW / 2;
        if (rel > 0)
            return cx + car.focusedW / 2 + car.gap + (rel - 1) * (car.sliceW + car.gap);
        var d = -rel;
        return cx - car.focusedW / 2 - car.gap - car.sliceW - (d - 1) * (car.sliceW + car.gap);
    }

    Repeater {
        model: car.model
        delegate: Item {
            id: slot
            required property int index
            required property var modelData
            readonly property int rel: index - car.selIndex
            readonly property bool foc: rel === 0
            readonly property bool near: Math.abs(rel) <= car.maxVisible

            visible: near
            width: foc ? car.focusedW : car.sliceW
            height: foc ? car.focusedH : car.sliceH
            x: car.leftEdge(rel)
            y: (car.height - height) / 2
            z: foc ? 100 : 60 - Math.abs(rel)
            opacity: near ? (foc ? 1 : Math.max(0.32, 0.82 - (Math.abs(rel) - 1) * 0.16)) : 0

            // horizontal shear: leans the side slices toward the centre.
            transform: Matrix4x4 {
                matrix: slot.foc
                    ? Qt.matrix4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                    : (slot.rel < 0
                        ? Qt.matrix4x4(1, car.leanShear, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        : Qt.matrix4x4(1, -car.leanShear, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1))
            }

            Behavior on x { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Loader {
                anchors.fill: parent
                sourceComponent: car.kind === "theme" ? themeC : wallC
            }
            Component {
                id: wallC
                WallCell {
                    s: car.s; item: slot.modelData; bg: car.bg
                    selected: slot.foc
                    live: slot.visible
                    beltMoving: car.moving
                    onEntered: car.focusIndex(slot.index)
                    onChosen: car.chosen(slot.index)
                }
            }
            Component {
                id: themeC
                ThemeCell {
                    s: car.s; item: slot.modelData; bg: car.bg
                    selected: slot.foc
                    active: !!slot.modelData && slot.modelData.id === car.activeKey
                    interactive: car.interactive
                    onEntered: car.focusIndex(slot.index)
                    onChosen: car.chosen(slot.index)
                }
            }
        }
    }
}
