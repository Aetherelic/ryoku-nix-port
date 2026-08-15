function seedFor(rect) {
    var s = (Math.imul(rect.x, 73856093) ^
             Math.imul(rect.y, 19349663) ^
             Math.imul(rect.w, 83492791) ^
             Math.imul(rect.h, 2654435761 | 0)) >>> 0;
    return s === 0 ? 1 : s;
}

function nextRandom(state) {
    var s = state >>> 0;
    s ^= s << 13; s >>>= 0;
    s ^= s >>> 17;
    s ^= s << 5; s >>>= 0;
    return s;
}

function quantize(r, g, b) {
    return ((r >> 6) << 4) | ((g >> 6) << 2) | (b >> 6);
}

function palette(samples, max) {
    if (max === undefined) max = 6;
    var buckets = {};
    for (var i = 0; i < samples.length; i++) {
        var c = samples[i];
        var key = quantize(c.r, c.g, c.b);
        var b = buckets[key];
        if (!b) { b = buckets[key] = { r: 0, g: 0, b: 0, count: 0, key: key }; }
        b.r += c.r; b.g += c.g; b.b += c.b; b.count++;
    }
    var list = [];
    for (var k in buckets) list.push(buckets[k]);
    if (list.length === 0) return [{ r: 128, g: 128, b: 128 }];
    list.sort(function (a, b) {
        return b.count - a.count || a.key - b.key;
    });
    var out = [];
    for (var j = 0; j < list.length && out.length < max; j++) {
        var e = list[j];
        out.push({
            r: Math.round(e.r / e.count),
            g: Math.round(e.g / e.count),
            b: Math.round(e.b / e.count)
        });
    }
    return out;
}

/**
 * Tile a region into block cells, each assigned a palette index drawn from a
 * seeded xorshift sequence rather than from the block's own pixels. A per-block
 * downscale would preserve the source's spatial structure and could be read
 * back to recover the redacted content; a seeded palette fill discards position
 * entirely, so the mosaic carries no recoverable signal while staying
 * deterministic for a given seed.
 */
function blockPlan(w, h, block, seed, paletteLen) {
    if (block < 1) block = 1;
    if (paletteLen < 1) paletteLen = 1;
    if (w <= 0 || h <= 0) return [];
    var cells = [];
    var state = seed >>> 0;
    for (var y = 0; y < h; y += block) {
        var ch = Math.min(block, h - y);
        for (var x = 0; x < w; x += block) {
            var cw = Math.min(block, w - x);
            state = nextRandom(state);
            cells.push({ x: x, y: y, w: cw, h: ch, index: state % paletteLen });
        }
    }
    return cells;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { seedFor, nextRandom, quantize, palette, blockPlan };
}
