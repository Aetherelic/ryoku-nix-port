import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { srcIndex, ease, spanBounds, resample, scopeMap } = require("./spectrum.js");

// float compare: the span/resample maths lands on non-exact doubles.
function near(actual, expected, msg) {
    assert.ok(Math.abs(actual - expected) < 1e-9, msg + " (got " + actual + ", want " + expected + ")");
}

test("mirror off returns the band index unchanged", () => {
    for (let i = 0; i < 8; i++)
        assert.equal(srcIndex(i, 8, false), i);
});

test("mirror folds around the centre: symmetric and in range", () => {
    const bands = 8;
    const c = Math.floor(bands / 2);
    for (let i = 0; i < bands; i++) {
        const s = srcIndex(i, bands, true);
        assert.ok(s >= 0 && s < bands, "folded index stays in range");
    }
    // a fold is symmetric about the centre: c-k and c+k read the same source.
    for (let k = 1; k <= c; k++)
        assert.equal(srcIndex(c - k, bands, true), srcIndex(c + k, bands, true));
    assert.equal(srcIndex(c, bands, true), 0, "the centre folds to the lowest band");
});

test("ease moves toward the target without overshooting", () => {
    const rising = ease(0, 1, 0.016, 0.03, 0.3);
    assert.ok(rising > 0 && rising < 1, "a rising step lands between cur and target");
    const falling = ease(1, 0, 0.016, 0.03, 0.3);
    assert.ok(falling < 1 && falling > 0, "a falling step lands between cur and target");
});

test("ease decays slower than it attacks", () => {
    const dt = 0.016, attack = 0.03, decay = 0.3;
    const attackMove = ease(0, 1, dt, attack, decay) - 0;      // distance covered rising
    const decayMove = 1 - ease(1, 0, dt, attack, decay);        // distance covered falling
    assert.ok(attackMove > decayMove, "a rising step covers more ground than a falling one");
});

test("ease converges to the target over many steps", () => {
    let up = 0;
    for (let i = 0; i < 200; i++) up = ease(up, 1, 0.016, 0.03, 0.3);
    assert.ok(up > 0.99, "rising converges toward 1");
    let down = 1;
    for (let i = 0; i < 400; i++) down = ease(down, 0, 0.016, 0.03, 0.3);
    assert.ok(down < 0.01, "falling converges toward 0");
});

test("ease with a larger dt moves further", () => {
    assert.ok(ease(0, 1, 0.1, 0.03, 0.3) > ease(0, 1, 0.016, 0.03, 0.3));
});

test("spanBounds: a full span covers the whole edge for every align", () => {
    for (const align of ["start", "center", "end"]) {
        const b = spanBounds(align, 1);
        near(b.lo, 0, align + " full span lo");
        near(b.hi, 1, align + " full span hi");
    }
});

test("spanBounds: a 0.3 span sits where align says", () => {
    const start = spanBounds("start", 0.3);
    near(start.lo, 0, "start lo"); near(start.hi, 0.3, "start hi");
    const center = spanBounds("center", 0.3);
    near(center.lo, 0.35, "center lo"); near(center.hi, 0.65, "center hi");
    const end = spanBounds("end", 0.3);
    near(end.lo, 0.7, "end lo"); near(end.hi, 1, "end hi");
});

test("spanBounds: an unknown align falls back to center, bounds stay clamped", () => {
    const b = spanBounds("sideways", 0.3);
    near(b.lo, 0.35, "unknown align centres"); near(b.hi, 0.65, "unknown align hi");
    const over = spanBounds("center", 5);
    near(over.lo, 0, "oversized span clamps lo"); near(over.hi, 1, "oversized span clamps hi");
});

test("resample averages a known 8 -> 4 fold", () => {
    assert.deepEqual(resample([0, 1, 2, 3, 4, 5, 6, 7], 4), [0.5, 2.5, 4.5, 6.5]);
});

test("resample averages rather than decimates", () => {
    // decimation would pick 0 or 4 per bucket; averaging must yield 2.
    assert.deepEqual(resample([0, 4, 0, 4], 2), [2, 2]);
});

test("resample returns exactly n buckets", () => {
    assert.equal(resample([1, 2, 3], 10).length, 10);
    assert.equal(resample([1, 2, 3, 4, 5, 6], 5).length, 5);
    assert.equal(resample([9, 9], 1).length, 1);
});

test("resample interpolates when upsampling a short source", () => {
    // nearest-neighbour would give [0,10,10] or [0,0,10]; the midpoint proves lerp.
    assert.deepEqual(resample([0, 10], 3), [0, 5, 10]);
});

test("scopeMap centres silence and clamps the rails", () => {
    assert.equal(scopeMap(-1), 0);
    assert.equal(scopeMap(0), 0.5);
    assert.equal(scopeMap(1), 1);
    assert.equal(scopeMap(-2), 0);
    assert.equal(scopeMap(2), 1);
});
