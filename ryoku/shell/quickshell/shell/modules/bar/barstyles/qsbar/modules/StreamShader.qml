pragma ComponentBehavior: Bound
import QtQuick
import shell.services

// GPU renderer for the qsbar gap animation (barAnim drift modes 1-6). The same
// procedural motion ParticleStream draws with a threaded Canvas, evaluated per
// pixel by stream.frag instead of rasterised on the CPU: one ShaderEffect per
// bar gap, a single clock float drives every mode, and `mode` selects the effect
// branch. That costs ~0 CPU (the Canvas cost ~25% of a core), so it needs no
// power-profile gate -- it animates smoothly on Balanced and Performance alike,
// and reduce-motion / Power Saver still unload it at the LazyLoader. cava is
// claimed only while audio plays, so a silent desktop pays nothing for it. The
// stateful modes (7 reactor, 8 quotes) keep the Canvas-based ParticleStream.
Item {
    id: root

    required property var  theme
    required property Item layout    // ReactorLayer: pillRuns, runRightEdge/Left()
    property string monitor: ""
    property int mode: (theme && theme.barAnim !== undefined) ? theme.barAnim : 1

    readonly property bool audioLive:  Media.playing
    readonly property real audioLevel: AudioBars.active ? Math.min(1, AudioBars.energy) : 0
    onAudioLiveChanged:      AudioBars.setActive(root, root.audioLive)
    Component.onCompleted:   AudioBars.setActive(root, root.audioLive)
    Component.onDestruction: AudioBars.setActive(root, false)

    // One float per frame drives every gap's shader -- negligible beside a Canvas
    // repaint. elapsedTime is in seconds, matching stream.frag's time units.
    FrameAnimation { id: clock; running: true }

    // One shader instance per gap between widget clusters. gapX puts every pixel
    // on the shared global dot grid, so the stream stays continuous across gaps.
    Repeater {
        model: root.layout && root.layout.pillRuns
               ? Math.max(0, root.layout.pillRuns.length - 1) : 0

        delegate: ShaderEffect {
            id: gapFx
            required property int index
            readonly property var runs: root.layout.pillRuns
            // Reactive: ReactorLayer.runs re-derives when a cluster moves (a widget
            // appears, the clock ticks), so these edges follow the live layout.
            readonly property real x1: root.layout.runRightEdge(runs[index].e)
            readonly property real x2: root.layout.runLeftEdge(runs[index + 1].s)

            x: x1
            y: 0
            width: Math.max(0, x2 - x1)
            height: root.height
            visible: width > 10 && height > 0

            property real time: clock.elapsedTime
            property real aud:  root.audioLevel
            property real gapX: x1
            property real gapW: width
            property real gapH: height
            property real gapIndex: index
            property real mode: root.mode
            property vector4d seal: (root.theme && root.theme.seal)
                ? Qt.vector4d(root.theme.seal.r, root.theme.seal.g, root.theme.seal.b, 1.0)
                : Qt.vector4d(1.0, 1.0, 1.0, 1.0)

            fragmentShader: "../shaders/stream.frag.qsb"
        }
    }
}
