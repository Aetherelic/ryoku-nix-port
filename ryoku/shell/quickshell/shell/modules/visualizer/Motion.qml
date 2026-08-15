pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui
import "Singletons"

// The spectrum's motion, kept apart from its drawing: cava's bands (or the
// monitor waveform, for the scope) become eased levels, falling peaks, an "is
// music playing" signal and a rotation. Nothing here knows what a look looks
// like.
//
// One Timer drives it at the configured rate rather than vsync, halved while
// idle and stopped on silence, since redrawing 165 times a second over a still
// picture costs a laptop real battery. The adaptive tier lowers that rate under
// sustained overrun; it sheds no effects, every look being one pass now.
Item {
    id: motion

    // the look being drawn: only the scope reads a waveform instead of bands.
    property string style: "bars"
    property bool active: true

    readonly property bool scope: motion.style === "line"
    readonly property int bands: motion.scope
        ? Math.max(16, Math.min(128, Config.bars * 2))
        : Math.max(4, Math.min(128, Config.bars))

    // --- outputs -----------------------------------------------------------
    property var levels: []
    property var peaks: []
    readonly property real energy: motion.maxLevel
    // Master fade. With the idle wave off, the picture releases with the
    // activity signal so a fixed-baseline look (the ring, the orb) clears on
    // silence instead of freezing when the Timer stops.
    readonly property real fade: motion.wantIdleWave ? 1
        : Math.max(0, Math.min(1, (motion.activity - 0.02) / 0.25))
    property real spinDeg: 0

    property real activity: 0
    property real idlePhase: 0
    property real maxLevel: 0

    // --- budget ------------------------------------------------------------
    property real govOverrun: 1
    property int govTier: 0
    property real govSince: 0
    readonly property bool govOn: Config.adaptive
    readonly property int fps: {
        if (!motion.govOn || motion.govTier === 0)
            return Config.fps;
        return motion.govTier === 1 ? Math.min(Config.fps, 30) : Math.min(Config.fps, 24);
    }

    readonly property bool sounding: Spectrum.energy > 0.04 || motion.activity > 0.02
    // The idle wave breathes only while sound is actually present and freezes on
    // real silence, keyed off measured energy rather than an uncorked stream: a
    // silent-but-open stream (a call, a browser holding an audio context) would
    // otherwise leave the desktop breathing at rest.
    readonly property bool idleFrozen: Performance.visualizerFrozen && !motion.sounding
    readonly property bool wantIdleWave: Config.idleWave && !motion.idleFrozen
    readonly property bool wantPeaks: Config.peaks
        && (motion.style === "bars" || motion.style === "segments")
    readonly property bool animating: motion.sounding || motion.wantIdleWave
        || motion.maxLevel > 0.004 || (motion.scope && Waveform.samples.length > 0)
        || Config.spin > 0

    function rawLevel(i) {
        var l = Spectrum.levels;
        var s = SpectrumMath.srcIndex(i, motion.bands, Config.mirror);
        var v = (l && s < l.length) ? l[s] : 0;
        return Math.min(1, Math.pow(v, 0.72) * Config.gain);
    }
    function idleLevel(i) {
        return 0.012 + 0.02 * (0.5 + 0.5 * Math.sin(
            SpectrumMath.srcIndex(i, motion.bands, Config.mirror) * 0.4 + motion.idlePhase));
    }

    Timer {
        id: ticker
        interval: Math.round(1000 / (motion.sounding ? motion.fps : Math.max(20, motion.fps / 2)))
        running: motion.active && Config.enabled && motion.animating
        repeat: true
        property real last: 0
        onTriggered: {
            var now = Date.now();
            var raw = ticker.last > 0 ? (now - ticker.last) / 1000 : ticker.interval / 1000;
            ticker.last = now;
            if (motion.govOn)
                motion.governor(raw, ticker.interval / 1000);
            motion.tick(Math.min(0.05, raw));
        }
    }

    // Climb and descend tiers on a slow average of the overrun, with a dwell, so
    // a single hitch never trips a change and the tier cannot oscillate.
    function governor(raw, asked) {
        var ratio = Math.min(3, asked > 0 ? raw / asked : 1);
        motion.govOverrun += (ratio - motion.govOverrun) * 0.1;
        var now = Date.now();
        if (now - motion.govSince < 2500)
            return;
        if (motion.govOverrun > 1.6 && motion.govTier < 2) {
            motion.govTier += 1;
            motion.govSince = now;
        } else if (motion.govOverrun < 1.15 && motion.govTier > 0) {
            motion.govTier -= 1;
            motion.govSince = now;
        }
    }

    function tick(dt) {
        // activity rises fast on the first beat and releases slowly, so a gap
        // between tracks does not flicker the spectrum off.
        var goal = Spectrum.energy > 0.04 ? 1 : 0;
        motion.activity += (goal - motion.activity)
            * (1 - Math.exp(-dt / (goal > motion.activity ? 0.05 : 1.1)));
        if (motion.wantIdleWave)
            motion.idlePhase += dt * (Math.PI * 2 / 6);
        if (Config.spin > 0)
            motion.spinDeg = (motion.spinDeg + dt * Config.spin) % 360;

        if (motion.scope) {
            motion.stepScope(dt);
            return;
        }

        var n = motion.bands;
        var prev = motion.levels;
        var idleAmt = motion.wantIdleWave ? (1 - motion.activity) : 0;
        // smoothing stretches the decay, and a touch of the attack.
        var decay = 0.06 + 0.20 * Config.smoothing;
        var attack = 0.035 + 0.02 * Config.smoothing;
        var out = new Array(n);
        var mx = 0;
        for (var i = 0; i < n; i++) {
            var target = motion.activity * motion.rawLevel(i) + idleAmt * motion.idleLevel(i);
            var cur = (prev && i < prev.length) ? prev[i] : 0;
            out[i] = SpectrumMath.ease(cur, target, dt, attack, decay);
            if (out[i] > mx)
                mx = out[i];
        }
        motion.levels = out;
        motion.maxLevel = mx;

        if (motion.wantPeaks) {
            var pk = motion.peaks;
            var np = new Array(n);
            for (var p = 0; p < n; p++) {
                var pc = (pk && p < pk.length) ? pk[p] - dt * 0.5 : 0;
                np[p] = out[p] > pc ? out[p] : Math.max(0, pc);
            }
            motion.peaks = np;
        } else if (motion.peaks.length) {
            motion.peaks = [];
        }
    }

    // The scope carries the real playback waveform, folded down to the band
    // count and centred on 0.5, the slot the shader reads for it.
    //
    // It normalises against a decaying peak the way cava does internally: a
    // waveform read straight off the monitor is a flat line at any ordinary
    // listening volume, since the samples are a few percent of full scale.
    property real scopePeak: 0.15

    function stepScope(dt) {
        var wav = Waveform.samples;
        var n = motion.bands;
        if (!wav || wav.length < 2) {
            var flat = new Array(n);
            for (var f = 0; f < n; f++)
                flat[f] = 0.5;
            motion.levels = flat;
            motion.maxLevel = 0;
            return;
        }
        var folded = SpectrumMath.resample(wav, n);
        var frame = 0;
        for (var j = 0; j < n; j++) {
            var m = Math.abs(folded[j]);
            if (m > frame)
                frame = m;
        }
        motion.scopePeak = Math.max(frame, motion.scopePeak - dt * 0.25);
        var norm = Config.gain / Math.max(0.02, motion.scopePeak);
        var out = new Array(n);
        var mx = 0;
        for (var i = 0; i < n; i++) {
            var v = Math.tanh(folded[i] * norm * 0.9);
            out[i] = SpectrumMath.scopeMap(v);
            var a = Math.abs(v);
            if (a > mx)
                mx = a;
        }
        motion.levels = out;
        motion.maxLevel = mx;
    }

    // A stopped Timer must leave a resting picture behind, not the last frame
    // of the music.
    onAnimatingChanged: if (!motion.animating) {
        motion.maxLevel = 0;
        if (motion.peaks.length)
            motion.peaks = [];
    }
    onBandsChanged: {
        motion.levels = [];
        motion.peaks = [];
    }
}
