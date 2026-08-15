import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { gripAt, anchorAt, resize, intoBox, magnet, wrap, shortestTurn } = require("./place.js");

const screen = { w: 2560, h: 1600 };
const min = { w: 0.04, h: 0.03 };
const box = { x: 0.34, y: 0.28, w: 0.32, h: 0.24 };
const angles = [0, 15, 30, 45, 90, 135, 180, 225, 270, 330, 359];
const drags = [[120, 0], [0, 120], [-90, 60], [200, 150], [-40, -30]];

function near(a, b, msg) {
    assert.ok(Math.abs(a - b) < 1e-6, `${msg} (got ${a}, want ${b})`);
}

// The whole point of the maths: whatever the angle, the grabbed corner ends up
// exactly under the pointer. A box that grows from a fixed top left while turning
// about its centre fails this at every angle but zero, which is the bug that made a
// turned box resize as though it were square on.
test("the grip lands exactly under the pointer at every angle", () => {
    for (const deg of angles)
        for (const [dx, dy] of drags) {
            const before = gripAt(box, deg, screen);
            const after = gripAt(resize(box, deg, dx, dy, screen, min), deg, screen);
            near(after.x - before.x, dx, `angle ${deg} drag ${dx},${dy}: x`);
            near(after.y - before.y, dy, `angle ${deg} drag ${dx},${dy}: y`);
        }
});

test("the corner opposite the grip never moves", () => {
    for (const deg of angles)
        for (const [dx, dy] of drags) {
            const before = anchorAt(box, deg, screen);
            const after = anchorAt(resize(box, deg, dx, dy, screen, min), deg, screen);
            near(after.x, before.x, `angle ${deg}: anchor x`);
            near(after.y, before.y, `angle ${deg}: anchor y`);
        }
});

test("square on, a drag right and down grows width and height by that much", () => {
    const out = resize(box, 0, 256, 160, screen, min);
    near(out.w, box.w + 0.1, "width");
    near(out.h, box.h + 0.1, "height");
    near(out.x, box.x, "x is held");
    near(out.y, box.y, "y is held");
});

test("at a quarter turn a drag down grows width, not height", () => {
    const out = resize(box, 90, 0, 256, screen, min);
    near(out.w, box.w + 0.1, "width follows the box's own axis");
    near(out.h, box.h, "height is untouched");
});

test("a screen delta read in box axes is a rotation: length is preserved", () => {
    for (const deg of angles) {
        const l = intoBox(120, -50, deg);
        near(Math.hypot(l.x, l.y), Math.hypot(120, -50), `angle ${deg}`);
    }
});

test("a box cannot be sized below the minimum", () => {
    const out = resize(box, 0, -99999, -99999, screen, min);
    near(out.w, min.w, "width floor");
    near(out.h, min.h, "height floor");
});

test("the minimum still holds the anchor still", () => {
    for (const deg of angles) {
        const before = anchorAt(box, deg, screen);
        const after = anchorAt(resize(box, deg, -99999, -99999, screen, min), deg, screen);
        near(after.x, before.x, `angle ${deg}: anchor x at floor`);
        near(after.y, before.y, `angle ${deg}: anchor y at floor`);
    }
});

test("the magnet takes the nearby angle and leaves the rest free", () => {
    assert.equal(magnet(91, 15, 2.5), 90);
    assert.equal(magnet(44, 15, 2.5), 45);
    assert.equal(magnet(37, 15, 2.5), 37);
    assert.equal(magnet(0.5, 15, 2.5), 0);
});

test("angles wrap into one turn", () => {
    assert.equal(wrap(370), 10);
    assert.equal(wrap(-10), 350);
    assert.equal(wrap(360), 0);
});

test("easing takes the short way round through zero", () => {
    assert.equal(shortestTurn(350, 10), 20);
    assert.equal(shortestTurn(10, 350), -20);
    assert.ok(Math.abs(shortestTurn(0, 180)) === 180);
});
