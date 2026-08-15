import { test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { bboxOf, hitOne, hitTest, handleAt, resizeRect } = require("./hittest.js");

const rect = { type: "rect", width: 4, points: [{ x: 100, y: 100 }, { x: 300, y: 200 }] };

test("point inside a rect hits", () => {
    assert.equal(hitOne(rect, 200, 150), true);
});

test("point tol+1 outside misses", () => {
    // tol is max(width, 8) = 8; a point 9px right of the right edge must miss.
    assert.equal(hitOne(rect, 309, 150), false);
});

test("topmost of two stacked items wins", () => {
    const lower = { type: "rect", width: 4, points: [{ x: 0, y: 0 }, { x: 400, y: 400 }] };
    const upper = { type: "rect", width: 4, points: [{ x: 100, y: 100 }, { x: 200, y: 200 }] };
    assert.equal(hitTest([lower, upper], 150, 150), 1);
});

test("a point within tolerance of a line hits and beyond misses", () => {
    const line = { type: "line", width: 4, points: [{ x: 0, y: 0 }, { x: 100, y: 0 }] };
    assert.equal(hitOne(line, 50, 5), true);
    assert.equal(hitOne(line, 50, 20), false);
});

test("a pen polyline hits near any segment", () => {
    const pen = { type: "pen", width: 4, points: [{ x: 0, y: 0 }, { x: 100, y: 0 }, { x: 100, y: 100 }] };
    assert.equal(hitOne(pen, 50, 3), true);
    assert.equal(hitOne(pen, 103, 50), true);
    assert.equal(hitOne(pen, 50, 50), false);
});

test("an ellipse hits inside and misses at the corner of its bbox", () => {
    const ell = { type: "ellipse", width: 4, points: [{ x: 0, y: 0 }, { x: 200, y: 100 }] };
    assert.equal(hitOne(ell, 100, 50), true);
    assert.equal(hitOne(ell, 0, 0), false);
});

test("the text bbox width rule", () => {
    const txt = { type: "text", size: 20, text: "hello", points: [{ x: 10, y: 10 }] };
    const b = bboxOf(txt);
    assert.equal(b.w, Math.max(5 * 20 * 0.6, 20));
    assert.equal(b.h, 20 * 1.4);
});

test("handleAt returns tl at corner, t at top edge midpoint, null in middle", () => {
    const r = { x: 100, y: 100, w: 200, h: 100 };
    assert.equal(handleAt(r, 100, 100, 8), "tl");
    assert.equal(handleAt(r, 200, 100, 8), "t");
    assert.equal(handleAt(r, 200, 150, 8), null);
});

test("resizeRect role l moves x0 and preserves x0+w", () => {
    const r = { x: 100, y: 100, w: 200, h: 100 };
    const out = resizeRect(r, "l", 140, 999, 8);
    assert.equal(out.x, 140);
    assert.equal(out.x + out.w, 300);
    assert.equal(out.y, 100);
    assert.equal(out.h, 100);
});

test("resizeRect clamps at min instead of inverting", () => {
    const r = { x: 100, y: 100, w: 200, h: 100 };
    const out = resizeRect(r, "l", 500, 0, 8);
    assert.equal(out.x, 300 - 8);
    assert.equal(out.w, 8);
});

test("resizeRect role br moves both x1 and y1", () => {
    const r = { x: 100, y: 100, w: 200, h: 100 };
    const out = resizeRect(r, "br", 400, 300, 8);
    assert.equal(out.x, 100);
    assert.equal(out.y, 100);
    assert.equal(out.w, 300);
    assert.equal(out.h, 200);
});
