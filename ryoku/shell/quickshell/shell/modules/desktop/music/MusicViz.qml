pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import shell.services
import "../Singletons"

// The no-lyrics backdrop: a live cava spectrum in the sleeve's colour, so a
// track with no words still moves instead of showing a dead "no lyrics" panel.
// The analyser (AudioBars, the shared 40-band cava feed) is owner-refcounted and
// claimed only while this is visible and a track plays, so a paused sheet, a
// track that has lyrics, or a hidden widget all cost nothing.
//
// Two looks share that one feed: `bars` grows slivers from the mid-line both
// ways (the original look), and `wave` draws the feed as a smoothed, mirrored
// band. Both take their colour from `accent`, which the host hands down from the
// album art (not the theme), so the spectrum wears the record's own colour.
Item {
    id: viz

    property real s: 1
    property color accent: Theme.accent   // the sleeve's colour, resolved from the cover by the host
    property bool live: false
    property string look: "bars"          // bars | wave

    readonly property bool wanted: viz.live && viz.visible
    onWantedChanged: AudioBars.setActive(viz, viz.wanted)
    Component.onCompleted: {
        AudioBars.setActive(viz, viz.wanted);
        viz.buildWave();
        viz.updateWave();
    }
    Component.onDestruction: AudioBars.setActive(viz, false)

    readonly property int count: AudioBars.bars
    readonly property real pitch: viz.width / Math.max(1, viz.count)
    readonly property real barW: Math.max(2 * viz.s, viz.pitch * 0.55)
    readonly property real maxH: viz.height * 0.8

    // ── bars: the original look, unchanged ──────────────────────────────────
    Item {
        anchors.fill: parent
        visible: viz.look === "bars"

        Repeater {
            model: viz.count

            delegate: Item {
                id: slot
                required property int index
                x: slot.index * viz.pitch
                width: viz.pitch
                height: viz.height

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    width: viz.barW
                    radius: width / 2
                    color: viz.accent
                    opacity: 0.85
                    height: Math.max(viz.barW, (AudioBars.active
                        ? (AudioBars.levels[slot.index] || 0) : 0) * viz.maxH)
                    Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutSine } }
                }
            }
        }
    }

    // ── wave: a smoothed, mirrored, album-tinted band ───────────────────────
    // Fixed draw resolution, independent of the band count: the outline is
    // resampled onto this many points so it reads as a curve, not 40 hard steps.
    readonly property int drawN: 64
    readonly property int smoothWin: 2

    // Persistent buffers, built once at the current sizes and then moved in
    // place every frame -- never rebuilt inside updateWave(), so a 30fps redraw
    // allocates nothing. wavePts holds Qt.point wrappers (plain {x,y} objects do
    // not convert to list<point>); mutating their x/y and reassigning the same
    // array is what repaints the Shape.
    property var wavePts: []       // 2 * drawN points: top outline then its mirror
    property var smoothBuf: []     // `count` cells of scratch for the moving average

    function buildWave() {
        var pts = [];
        for (var i = 0; i < viz.drawN * 2; i++)
            pts.push(Qt.point(0, 0));
        viz.wavePts = pts;
        var sb = [];
        for (var b = 0; b < viz.count; b++)
            sb.push(0);
        viz.smoothBuf = sb;
    }

    // A 40-band feed drawn straight as a curve reads as noise: the step between
    // neighbouring bands shows as a run of jagged spikes. A small moving-average
    // window turns those steps into a line the eye can follow; the smoothed bands
    // are then resampled onto drawN points and mirrored about the mid-line, so
    // the filled body is symmetric the way the bars grow both ways from centre.
    function updateWave() {
        if (viz.look !== "wave")
            return;
        var pts = viz.wavePts;
        if (!pts || pts.length === 0)
            return;
        var n = viz.drawN;
        var bands = viz.count;
        var mid = viz.height / 2;
        var half = viz.maxH / 2;
        var lv = AudioBars.active ? AudioBars.levels : null;
        var sb = viz.smoothBuf;
        var w = viz.smoothWin;

        for (var i = 0; i < bands; i++) {
            var sum = 0, cnt = 0;
            for (var k = -w; k <= w; k++) {
                var idx = i + k;
                if (idx < 0) idx = 0;
                else if (idx >= bands) idx = bands - 1;
                sum += lv ? (lv[idx] || 0) : 0;
                cnt++;
            }
            sb[i] = sum / cnt;
        }

        var last = bands - 1;
        for (var j = 0; j < n; j++) {
            var t = n > 1 ? j / (n - 1) : 0;
            var bp = t * last;
            var i0 = Math.floor(bp);
            var f = bp - i0;
            var i1 = i0 < last ? i0 + 1 : last;
            var amp = (sb[i0] + (sb[i1] - sb[i0]) * f) * half;
            var x = t * viz.width;
            pts[j].x = x;              pts[j].y = mid - amp;   // top outline
            pts[2 * n - 1 - j].x = x;  pts[2 * n - 1 - j].y = mid + amp;   // mirror below
        }
        wavePoly.path = pts;
    }

    Connections {
        target: AudioBars
        function onLevelsChanged() { viz.updateWave(); }
    }
    onCountChanged: { viz.buildWave(); viz.updateWave(); }
    onLookChanged: viz.updateWave()
    onWidthChanged: viz.updateWave()
    onHeightChanged: viz.updateWave()

    // The glow is a blurred COPY behind the band, not a blur of the band itself:
    // blurring the shape in place softens the very edge the curve renderer draws
    // crisply, and the wave then reads as a smear rather than lit glass.
    MultiEffect {
        anchors.fill: waveShape
        source: waveShape
        visible: waveShape.visible && !Performance.shadowsDisabled
        blurEnabled: true
        blurMax: 10
        blur: 0.6
        saturation: 0.15
        autoPaddingEnabled: true
        z: -1
    }

    Shape {
        id: waveShape
        anchors.fill: parent
        visible: viz.look === "wave"
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.rgba(viz.accent.r, viz.accent.g, viz.accent.b, 0.5)
            PathPolyline { id: wavePoly }
        }
    }
}
