import { test } from "node:test";
import assert from "node:assert/strict";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { square, snap45, constrain } = require("./constrain.js");

test("rect drag (0,0)->(30,20) squares to (30,30)", () => {
    assert.deepEqual(square({ x: 0, y: 0 }, { x: 30, y: 20 }), { x: 30, y: 30 });
});

test("drag up and left keeps both negative signs", () => {
    const r = square({ x: 100, y: 100 }, { x: 70, y: 80 });
    assert.equal(r.x, 70);
    assert.equal(r.y, 70);
});

test("zero delta returns the start point", () => {
    assert.deepEqual(square({ x: 50, y: 40 }, { x: 50, y: 40 }), { x: 50, y: 40 });
});

function lineAt(deg, len) {
    const rad = deg * Math.PI / 180;
    return { x: Math.cos(rad) * len, y: Math.sin(rad) * len };
}

test("30 degree line snaps to 45 degrees with length preserved", () => {
    const r = snap45({ x: 0, y: 0 }, lineAt(30, 100));
    assert.ok(Math.abs(Math.hypot(r.x, r.y) - 100) < 1e-9);
    assert.ok(Math.abs(Math.atan2(r.y, r.x) - Math.PI / 4) < 1e-9);
});

test("22 degree line snaps to 0 degrees (below the 22.5 threshold)", () => {
    const r = snap45({ x: 0, y: 0 }, lineAt(22, 100));
    assert.ok(Math.abs(Math.atan2(r.y, r.x)) < 1e-9);
    assert.ok(Math.abs(Math.hypot(r.x, r.y) - 100) < 1e-9);
});

test("23 degree line snaps to 45 degrees (above the 22.5 threshold)", () => {
    const r = snap45({ x: 0, y: 0 }, lineAt(23, 100));
    assert.ok(Math.abs(Math.atan2(r.y, r.x) - Math.PI / 4) < 1e-9);
    assert.ok(Math.abs(Math.hypot(r.x, r.y) - 100) < 1e-9);
});

test("5 degree line snaps to 0 degrees", () => {
    const r = snap45({ x: 0, y: 0 }, lineAt(5, 50));
    assert.ok(Math.abs(Math.atan2(r.y, r.x)) < 1e-9);
    assert.ok(Math.abs(Math.hypot(r.x, r.y) - 50) < 1e-9);
});

test("100 degree line snaps to 90", () => {
    const start = { x: 0, y: 0 };
    const rad = 100 * Math.PI / 180;
    const end = { x: Math.cos(rad) * 70, y: Math.sin(rad) * 70 };
    const r = snap45(start, end);
    assert.ok(Math.abs(Math.atan2(r.y, r.x) - Math.PI / 2) < 1e-9);
    assert.ok(Math.abs(Math.hypot(r.x, r.y) - 70) < 1e-9);
});

test("constrain('pen', ...) returns the identical end object", () => {
    const end = { x: 12, y: 34 };
    assert.equal(constrain("pen", { x: 0, y: 0 }, end), end);
});

test("constrain('spotlight', ...) squares", () => {
    assert.deepEqual(constrain("spotlight", { x: 0, y: 0 }, { x: 30, y: 20 }), { x: 30, y: 30 });
});
