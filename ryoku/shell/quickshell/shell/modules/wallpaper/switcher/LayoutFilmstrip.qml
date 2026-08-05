pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Filmstrip (tanzaku) layout: the focused entry sits full-size at centre, its
// immediate neighbours peek, and the rest thin to paper strips — sumi-e negative
// space with one red seal brushed under the pick. A wheel or arrow steps the
// focus; every tile slides to its new place on an OutCubic glide, so the strip
// re-lays smoothly instead of jumping. Tiles reuse WallCell/ThemeCell, so live
// previews, the on-air dot and hover all come for free.
Item {
    id: strip

    required property real s
    required property var model              // filtered + sorted entries
    required property string kind            // "wall" | "theme"
    required property color bg               // stage colour (edge fades / dim)
    property int selIndex: 0                 // body-owned focus
    property bool active: true
    property string activeKey: ""            // applied identity (theme on-air)
    property bool interactive: true          // themes frozen while following
    signal focusIndex(int i)                 // hover/wheel asks the body to focus i
    signal chosen(int i)                     // click/enter applies model[i]

    readonly property int count: model ? model.length : 0

    // ── geometry (all scaled) ──
    readonly property int gap: Math.round(10 * s)
    readonly property real focusedH: Math.min(height - Math.round(24 * s),
        Math.round((kind === "theme" ? 288 : 268) * s))
    readonly property real focusedW: kind === "theme"
        ? Math.round(focusedH * 0.82)
        : Math.round(focusedH * 16 / 9)
    readonly property real peekW: Math.round(96 * s)
    readonly property real stripW: Math.round(22 * s)
    readonly property int maxVisible: 7
    function wFor(d) { d = Math.abs(d); return d === 0 ? focusedW : d === 1 ? peekW : stripW }

    // left edge for an item at relative offset rel = index - selIndex.
    function leftEdge(rel) {
        var cx = strip.width / 2;
        if (rel === 0)
            return cx - strip.focusedW / 2;
        if (rel > 0) {
            var x = cx + strip.focusedW / 2 + strip.gap;
            for (var d = 1; d < rel; d++)
                x += strip.wFor(d) + strip.gap;
            return x;
        }
        var right = cx - strip.focusedW / 2 - strip.gap;
        for (var e = 1; e <= -rel; e++) {
            var w = strip.wFor(e);
            if (e === -rel)
                return right - w;
            right -= (w + strip.gap);
        }
        return right;
    }

    // gate live video off while the focus is travelling.
    property bool moving: false
    onSelIndexChanged: { strip.moving = true; movingCool.restart(); }
    Timer { id: movingCool; interval: 320; onTriggered: strip.moving = false }

    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            var step = e.angleDelta.y < 0 ? 1 : -1;
            var ni = Math.max(0, Math.min(strip.count - 1, strip.selIndex + step));
            if (ni !== strip.selIndex)
                strip.focusIndex(ni);
        }
    }

    Repeater {
        model: strip.model
        delegate: Item {
            id: slot
            required property int index
            required property var modelData
            readonly property int rel: index - strip.selIndex
            readonly property bool near: Math.abs(rel) <= strip.maxVisible

            visible: near
            width: strip.wFor(rel)
            height: rel === 0 ? strip.focusedH
                : Math.round(strip.focusedH * (Math.abs(rel) === 1 ? 0.9 : 0.8))
            x: strip.leftEdge(rel)
            y: (strip.height - height) / 2
            z: rel === 0 ? 100 : 60 - Math.abs(rel)
            opacity: near ? 1 : 0

            Behavior on x { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: Motion.beltEase; easing.type: Easing.OutCubic } }
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Loader {
                anchors.fill: parent
                sourceComponent: strip.kind === "theme" ? themeC : wallC
            }
            Component {
                id: wallC
                WallCell {
                    s: strip.s; item: slot.modelData; bg: strip.bg
                    selected: slot.rel === 0
                    live: slot.visible
                    beltMoving: strip.moving
                    onEntered: strip.focusIndex(slot.index)
                    onChosen: strip.chosen(slot.index)
                }
            }
            Component {
                id: themeC
                ThemeCell {
                    s: strip.s; item: slot.modelData; bg: strip.bg
                    selected: slot.rel === 0
                    active: !!slot.modelData && slot.modelData.id === strip.activeKey
                    interactive: strip.interactive
                    onEntered: strip.focusIndex(slot.index)
                    onChosen: strip.chosen(slot.index)
                }
            }

            // distance wash: neighbours recede into the paper.
            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusWidget
                color: strip.bg
                opacity: slot.rel === 0 ? 0 : Math.min(0.62, 0.22 + Math.abs(slot.rel) * 0.12)
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }

    // red seal brushed under the pick.
    Rectangle {
        visible: strip.count > 0
        width: strip.focusedW * 0.62
        height: Math.max(2, Math.round(3 * strip.s))
        x: (strip.width - width) / 2
        y: (strip.height + strip.focusedH) / 2 + Math.round(9 * strip.s)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(Theme.seal, 0) }
            GradientStop { position: 0.5; color: Theme.seal }
            GradientStop { position: 1.0; color: Qt.alpha(Theme.seal, 0) }
        }
    }

    // edge fades, so strips dissolve into the card rather than clipping hard.
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: Math.round(56 * strip.s)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: strip.bg }
            GradientStop { position: 1.0; color: Qt.alpha(strip.bg, 0) }
        }
    }
    Rectangle {
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: Math.round(56 * strip.s)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.alpha(strip.bg, 0) }
            GradientStop { position: 1.0; color: strip.bg }
        }
    }
}
