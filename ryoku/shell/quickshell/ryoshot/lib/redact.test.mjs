import { test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { seedFor, nextRandom, quantize, palette, blockPlan } = require("./redact.js");

test("nextRandom is deterministic", () => {
    assert.equal(nextRandom(12345), nextRandom(12345));
});

test("nextRandom never returns 0 from a nonzero seed and has no short cycle", () => {
    let state = 1;
    const seen = new Set();
    for (let i = 0; i < 1000; i++) {
        state = nextRandom(state);
        assert.notEqual(state, 0);
        assert.ok(!seen.has(state), "cycle at iteration " + i);
        seen.add(state);
    }
    assert.equal(seen.size, 1000);
});

test("seedFor is stable per rect and differs across rects", () => {
    const a = { x: 10, y: 20, w: 30, h: 40 };
    const b = { x: 11, y: 20, w: 30, h: 40 };
    assert.equal(seedFor(a), seedFor(a));
    assert.notEqual(seedFor(a), seedFor(b));
});

test("seedFor never returns 0", () => {
    for (let x = 0; x < 20; x++) {
        for (let y = 0; y < 20; y++) {
            assert.notEqual(seedFor({ x, y, w: 0, h: 0 }), 0);
        }
    }
    // the specific all-zero rect whose raw hash is 0 must be lifted to 1.
    assert.equal(seedFor({ x: 0, y: 0, w: 0, h: 0 }), 1);
});

test("quantize keys into 64 buckets", () => {
    assert.equal(quantize(0, 0, 0), 0);
    assert.equal(quantize(255, 255, 255), 63);
});

test("palette puts the most frequent colour first and caps at max", () => {
    const samples = [];
    for (let i = 0; i < 10; i++) samples.push({ r: 200, g: 10, b: 10 });
    for (let i = 0; i < 3; i++) samples.push({ r: 10, g: 200, b: 10 });
    samples.push({ r: 10, g: 10, b: 200 });
    const p = palette(samples, 2);
    assert.equal(p.length, 2);
    assert.deepEqual(p[0], { r: 200, g: 10, b: 10 });
    assert.deepEqual(p[1], { r: 10, g: 200, b: 10 });
});

test("palette returns grey for empty input", () => {
    assert.deepEqual(palette([]), [{ r: 128, g: 128, b: 128 }]);
});

test("blockPlan tiles a 40x25 region with block 12 into 12 gapless cells", () => {
    const cells = blockPlan(40, 25, 12, seedFor({ x: 0, y: 0, w: 40, h: 25 }), 6);
    assert.equal(cells.length, 12);
    let area = 0;
    for (const c of cells) {
        area += c.w * c.h;
        assert.ok(c.x >= 0 && c.y >= 0);
        assert.ok(c.x + c.w <= 40, "cell exceeds width");
        assert.ok(c.y + c.h <= 25, "cell exceeds height");
        assert.ok(c.index >= 0 && c.index < 6);
    }
    assert.equal(area, 40 * 25, "cells cover the region with no gap or overlap");
});

test("blockPlan is reproducible per seed and changes with a different seed", () => {
    const a = blockPlan(40, 25, 12, 111, 6);
    const b = blockPlan(40, 25, 12, 111, 6);
    assert.deepEqual(a, b);
    const c = blockPlan(40, 25, 12, 222, 6);
    assert.ok(a.some((cell, i) => cell.index !== c[i].index), "different seed changes an index");
});

test("blockPlan yields one cell for a 1x1 region", () => {
    const cells = blockPlan(1, 1, 12, 5, 6);
    assert.equal(cells.length, 1);
    assert.deepEqual({ x: cells[0].x, y: cells[0].y, w: cells[0].w, h: cells[0].h },
        { x: 0, y: 0, w: 1, h: 1 });
});

test("blockPlan yields no cells for a zero-area region", () => {
    assert.deepEqual(blockPlan(0, 10, 12, 5, 6), []);
    assert.deepEqual(blockPlan(10, 0, 12, 5, 6), []);
});
