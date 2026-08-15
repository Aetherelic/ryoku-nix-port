import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { gripAt, anchorAt, resize, intoBox, magnet, wrap, shortestTurn,
        tiltMatrix, flat, project } = require("./place.js");

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

// --- leaning into depth ---------------------------------------------------
const W = 800, H = 400;
const leans = [-35, -20, -8, 8, 20, 35];

test("no lean is the identity, so an untilted look is untouched", () => {
    const m = tiltMatrix(0, 0, W, H);
    assert.deepEqual(flat(m), flat([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]));
});

// Before the leaned quad was fitted to its box, "in place" meant the centre point
// held still and the near edge overhung the box. It now means the quad stays centred
// on the box and reaches its sides, so these say that instead: the perspective shows
// up as one edge being shorter, not as a look drawn outside its own bounds.
test("a leaned look stays centred on its box", () => {
    for (const t of leans) {
        for (const m of [tiltMatrix(t, 0, W, H), tiltMatrix(0, t, W, H), tiltMatrix(t, t, W, H)]) {
            const q = [[0, 0], [W, 0], [0, H], [W, H]].map(([x, y]) => project(m, x, y));
            const xs = q.map(p => p.x), ys = q.map(p => p.y);
            near((Math.min(...xs) + Math.max(...xs)) / 2, W / 2, `lean ${t}: centred in x`);
            near((Math.min(...ys) + Math.max(...ys)) / 2, H / 2, `lean ${t}: centred in y`);
        }
    }
});

test("the short edge is the one leaning away, both ways round", () => {
    const back = tiltMatrix(25, 0, W, H);
    const backTop = project(back, W, 0).x - project(back, 0, 0).x;
    const backBottom = project(back, W, H).x - project(back, 0, H).x;
    assert.ok(backTop < backBottom - 1, `leaning back should shorten the top (${backTop} vs ${backBottom})`);

    const fwd = tiltMatrix(-25, 0, W, H);
    const fwdTop = project(fwd, W, 0).x - project(fwd, 0, 0).x;
    const fwdBottom = project(fwd, W, H).x - project(fwd, 0, H).x;
    assert.ok(fwdBottom < fwdTop - 1, `leaning forward should shorten the bottom (${fwdBottom} vs ${fwdTop})`);

    const aside = tiltMatrix(0, 25, W, H);
    const asideLeft = project(aside, 0, H).y - project(aside, 0, 0).y;
    const asideRight = project(aside, W, H).y - project(aside, W, 0).y;
    assert.ok(asideRight < asideLeft - 1, `leaning aside should shorten one side (${asideRight} vs ${asideLeft})`);
});

test("a lean about one axis leaves the other axis's centre line straight", () => {
    const m = tiltMatrix(30, 0, W, H);
    for (const y of [0, H / 4, H / 2, H]) {
        const p = project(m, W / 2, y);
        near(p.x, W / 2, `x on the centre line at y=${y}`);
    }
});

test("the clamped range never approaches the vanishing point", () => {
    for (const ax of leans)
        for (const ay of leans) {
            const m = tiltMatrix(ax, ay, W, H);
            for (const [x, y] of [[0, 0], [W, 0], [0, H], [W, H]]) {
                const w = m[3][0] * x + m[3][1] * y + m[3][3];
                assert.ok(w > 0.5, `lean ${ax},${ay} corner ${x},${y}: w=${w} too close to zero`);
                const p = project(m, x, y);
                assert.ok(Number.isFinite(p.x) && Number.isFinite(p.y), "projected corner is finite");
            }
        }
});

test("a degenerate box leans to the identity rather than dividing by zero", () => {
    assert.deepEqual(flat(tiltMatrix(20, 20, 0, 0)), flat(tiltMatrix(0, 0, W, H)));
});

// The dead-space and spill bug: a lean is a shape change inside the box, so the
// leaned quad has to touch all four sides of it and never cross them. Without this
// the near edge drew past the outline while the far edge left the box half empty.
test("a leaned look fills its box exactly and never spills out of it", () => {
    for (const ax of [0, ...leans])
        for (const ay of [0, ...leans]) {
            const m = tiltMatrix(ax, ay, W, H);
            const q = [[0, 0], [W, 0], [0, H], [W, H]].map(([x, y]) => project(m, x, y));
            const xs = q.map(p => p.x), ys = q.map(p => p.y);
            near(Math.min(...xs), 0, `lean ${ax},${ay}: left edge`);
            near(Math.max(...xs), W, `lean ${ax},${ay}: right edge`);
            near(Math.min(...ys), 0, `lean ${ax},${ay}: top edge`);
            near(Math.max(...ys), H, `lean ${ax},${ay}: bottom edge`);
        }
});

test("the fit keeps the trapezoid a trapezoid rather than squaring it off", () => {
    const m = tiltMatrix(30, 0, W, H);
    const tl = project(m, 0, 0), tr = project(m, W, 0);
    const bl = project(m, 0, H), br = project(m, W, H);
    // the far edge is still shorter than the near one: fitting scales, it does not
    // undo the perspective
    assert.ok((tr.x - tl.x) < (br.x - bl.x) - 1, "far edge should stay shorter than near");
    near(tl.y, tr.y, "far edge stays level");
    near(bl.y, br.y, "near edge stays level");
});
