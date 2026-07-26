pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// The dictation surface grown from the pill centre. Super+` starts Voxtype and
// opens this; tapping again stops. VoiceBars runs cava on the mic, so the wave
// lies flat in silence and swells as you speak. When dictation is off it shows
// a plain "off" note instead. It never grabs focus, so Voxtype's keystrokes
// land in the app you're dictating into, not here.
PillSurface {
    id: root

    mTop: 13
    mLeft: 18
    mRight: 18
    mBottom: 13

    // dictation isn't running: show a plain "off" note in place of the wave.
    property bool off: false
    ameForm: "off"

    implicitHeight: 30 * root.s

    // run cava only while we're actually listening, never leave it running.
    onOpenChanged: VoiceBars.active = root.open && !root.off
    onOffChanged: VoiceBars.active = root.open && !root.off
    Component.onDestruction: VoiceBars.active = false

    // mic energy 0..1. mic glyph + wave brighten as user speaks, rest dim.
    readonly property real energy: {
        const l = VoiceBars.levels;
        if (!l || l.length === 0)
            return 0;
        let s = 0;
        for (let i = 0; i < l.length; i++)
            s += l[i];
        return Math.min(1, (s / l.length) * 2.6);
    }

    Row {
        anchors.fill: parent
        visible: !root.off
        spacing: 12 * root.s

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 16 * root.s
            height: 16 * root.s
            name: "mic"
            color: Qt.tint(Theme.onSurfaceVariant, Qt.alpha(Theme.primary, root.energy))
            stroke: 1.7
        }

        Canvas {
            id: wave
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 16 * root.s - 12 * root.s
            height: root.height
            property real phase: 0

            readonly property real maxAmp: height * 0.42
            readonly property real wavelength: 22 * root.s

            function level(t) {
                const l = VoiceBars.levels;
                const n = l ? l.length : 0;
                if (n === 0)
                    return 0;
                const p = t * (n - 1);
                const i = Math.floor(p);
                const f = p - i;
                const a = l[i];
                const b = i + 1 < n ? l[i + 1] : l[i];
                return a + (b - a) * f;
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const w = width;
                const mid = height / 2;
                const k = 6.28318 / wavelength;

                ctx.lineWidth = 2 * root.s;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.strokeStyle = Qt.alpha(Theme.primary, 0.4 + 0.6 * root.energy);

                ctx.beginPath();
                for (let x = 0; x <= w; x += 1.5) {
                    const amp = level(w > 0 ? x / w : 0) * maxAmp;
                    const y = mid + amp * Math.sin(x * k + phase);
                    if (x === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.stroke();
            }

            Timer {
                interval: 33
                running: root.open && !root.off
                repeat: true
                onTriggered: {
                    wave.phase = (wave.phase + 0.22) % 6.28318;
                    wave.requestPaint();
                }
            }
        }
    }

    // dictation off: a quiet note where the wave would be, auto-dismissed.
    Row {
        anchors.centerIn: parent
        spacing: 8 * root.s
        visible: root.off
        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 15 * root.s
            height: 15 * root.s
            name: "mic-off"
            color: Theme.onSurfaceVariant
            stroke: 1.7
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Dictation off"
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: 12 * root.s
        }
    }

    Timer {
        running: root.off && root.open
        interval: 1800
        onTriggered: root.requestClose()
    }
}
