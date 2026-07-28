import QtQuick
import "../.." as Pill
import "../../Singletons"

// Hold-to-activate icon button for destructive session actions: a stray click
// never fires. Press and hold and a bone liquid fills the tile, the glyph
// inverting to black; it fires at the top and releasing early drains it back.
Rectangle {
    id: root

    property string icon: "circle"
    property string tip: ""
    // Top-edge controls open their bubble downward so it never leaves the panel.
    property bool tipBelow: false
    // Bubble edge to pin to: "center" (default), "left" or "right".
    property string tipAlign: "center"
    // Continuous hold (ms) before firing.
    property int holdMs: 800
    signal activated()

    implicitWidth: 38
    implicitHeight: 38
    radius: Theme.radiusWidget
    color: tap.containsMouse
        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.12)
        : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
    border.width: 1
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b,
        (tap.containsMouse || root.heat > 0.01) ? 0.4 : 0.22)
    Behavior on color { ColorAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }
    clip: true

    scale: tap.pressed ? 0.94 : 1
    Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

    // Hold heat 0..1: rises over holdMs while held, drains on release, fires at 1.
    // Literal durations so reduce-motion can never collapse the hold to a tap.
    property bool holding: false
    property real heat: 0
    readonly property bool active: root.holding || root.heat > 0.001
    onHoldingChanged: heat = holding ? 1 : 0
    Behavior on heat { NumberAnimation { duration: root.holding ? root.holdMs : 220; easing.type: Easing.OutCubic } }
    onHeatChanged: if (root.heat >= 0.999 && root.holding) root.fire()

    function fire() {
        root.holding = false;
        root.heat = 0;
        root.activated();
    }

    // Bone liquid rising from the base with a wavy top; repaints only while active.
    Canvas {
        id: liquid
        anchors.fill: parent
        property real phase: 0

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (root.heat <= 0.001)
                return;
            const w = width;
            const h = height;
            const level = h * (1 - root.heat);
            const amp = root.active ? 2.4 : 0;
            const k = 6.28318 / (w / 1.4);
            ctx.beginPath();
            ctx.moveTo(0, h);
            for (let x = 0; x <= w; x += 1.5)
                ctx.lineTo(x, level + amp * Math.sin(k * x + liquid.phase));
            ctx.lineTo(w, h);
            ctx.closePath();
            ctx.fillStyle = Theme.inverseSurface;
            ctx.fill();
        }

        NumberAnimation on phase {
            running: root.active
            from: 0; to: 6.28318
            duration: 1100
            loops: Animation.Infinite
        }
        onPhaseChanged: requestPaint()
        Connections {
            target: root
            function onHeatChanged() { liquid.requestPaint(); }
        }
    }

    Pill.MaterialIcon {
        anchors.centerIn: parent
        font.pixelSize: 18
        text: root.icon
        fill: root.heat > 0.5 ? 1 : 0
        // Flips to black once the bone plate has risen under it.
        color: root.heat > 0.5
            ? Theme.inverseOnSurface
            : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface, 3.0)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: root.holding = true
        onReleased: root.holding = false
        onCanceled: root.holding = false
        onExited: root.holding = false
    }

    QsTip {
        text: root.tip
        below: root.tipBelow
        align: root.tipAlign
        hovered: tap.containsMouse && !tap.pressed
    }
}
