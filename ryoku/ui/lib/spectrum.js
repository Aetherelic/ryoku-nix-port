// The pure band maths the desktop renderer (VisualizerView) and the Hub preview
// (VizPreview) both feed the shared SpectrumField. Kept here, framework-free, so
// the two surfaces derive identical geometry instead of each re-deriving it and
// drifting. No QML imports, no state: siblings in ryoku/ui/lib are node-tested,
// which is why this stays a plain module (no `.pragma library`) with the
// module.exports guard below.

// Mirror the band order by folding around the centre, so a mirrored look draws
// the same low frequencies out to both edges (the classic centre-out spectrum).
// Ported verbatim from VisualizerView.srcIndex.
function srcIndex(i, bands, mirror) {
    if (!mirror)
        return i;
    var c = Math.floor(bands / 2);
    return Math.max(0, Math.min(bands - 1, Math.abs(i - c)));
}

// One-pole ease toward `target` over `dt` seconds. A short attack tau lets a
// band snap up on a transient; a longer decay tau lets it fall away gently, so
// peaks read and gaps do not flicker. k = 1 - e^(-dt/tau) is the frame-rate
// independent step of that filter.
function ease(cur, target, dt, attack, decay) {
    var tau = target > cur ? attack : decay;
    var k = 1 - Math.exp(-dt / tau);
    return cur + (target - cur) * k;
}

// Normalised [lo, hi] bounds of a span sitting along an edge. `start` hugs the
// low edge, `end` the high edge, `center` splits the slack evenly; everything is
// clamped to 0..1 so a full span always resolves to the whole edge.
function spanBounds(align, span) {
    var s = Math.max(0, Math.min(1, span));
    var lo;
    if (align === "start")
        lo = 0;
    else if (align === "end")
        lo = 1 - s;
    else
        lo = (1 - s) / 2;
    lo = Math.max(0, Math.min(1, lo));
    return { lo: lo, hi: Math.max(0, Math.min(1, lo + s)) };
}

// Fold `src` into exactly `n` buckets. Downsampling averages each contiguous
// slice so no sample is dropped (decimating a waveform would alias); upsampling
// linearly interpolates between neighbours so a short source still fills n slots
// smoothly. Used to reduce a ~220-point waveform to the band count.
function resample(src, n) {
    var out = new Array(n);
    var m = src.length;
    if (m === 0) {
        for (var z = 0; z < n; z++)
            out[z] = 0;
        return out;
    }
    if (m >= n) {
        for (var i = 0; i < n; i++) {
            var a = Math.floor(i * m / n);
            var b = Math.floor((i + 1) * m / n);
            var sum = 0;
            for (var j = a; j < b; j++)
                sum += src[j];
            out[i] = sum / (b - a);
        }
    } else {
        for (var k = 0; k < n; k++) {
            var t = (n === 1) ? 0 : k * (m - 1) / (n - 1);
            var loI = Math.floor(t);
            var hiI = Math.min(m - 1, loI + 1);
            var f = t - loI;
            out[k] = src[loI] * (1 - f) + src[hiI] * f;
        }
    }
    return out;
}

// Map a -1..1 oscilloscope sample to the 0..1 slot the shader draws around, so
// silence (0) lands on the 0.5 midline and the trace deflects either way,
// clamped to stay on-screen.
function scopeMap(v) {
    return Math.max(0, Math.min(1, 0.5 + 0.5 * v));
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { srcIndex, ease, spanBounds, resample, scopeMap };
