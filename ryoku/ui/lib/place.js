// Placement maths for a box that can be turned, kept framework-free so the shell's
// placer and a test runner derive the same numbers.
//
// The box is stored as fractions of the screen but rotation only means anything in
// pixels: a fraction of width and a fraction of height are different lengths, so a
// "rotation" between them would not be a rotation. Everything here converts to px,
// turns, and converts back.
//
// The box turns about its own centre. That is what makes resizing subtle: growing
// the box moves the centre, the turn is about the centre, so a naive "grow width by
// the drag" walks the grabbed corner away from the pointer along an axis that has
// nothing to do with the angle. Instead the corner opposite the grip is held still
// and the centre is re-derived from the new size, which makes the grip track the
// pointer exactly at every angle.

// R(a) applied to (x, y), in screen space where y runs down, so a positive angle
// reads as clockwise: the same sense as QQuickItem.rotation.
function turn(x, y, a) {
    var c = Math.cos(a), s = Math.sin(a);
    return { x: x * c - y * s, y: x * s + y * c };
}

// A screen vector expressed in the box's own axes.
function intoBox(dx, dy, deg) {
    return turn(dx, dy, -deg * Math.PI / 180);
}

function centreOf(box, screen) {
    return { x: (box.x + box.w / 2) * screen.w, y: (box.y + box.h / 2) * screen.h };
}

// The two corners that matter, in screen px: the grip rides the box's far corner
// (its local bottom right) and the anchor is the one diagonally opposite.
function gripAt(box, deg, screen) {
    var c = centreOf(box, screen);
    var o = turn(box.w * screen.w / 2, box.h * screen.h / 2, deg * Math.PI / 180);
    return { x: c.x + o.x, y: c.y + o.y };
}

function anchorAt(box, deg, screen) {
    var c = centreOf(box, screen);
    var o = turn(-box.w * screen.w / 2, -box.h * screen.h / 2, deg * Math.PI / 180);
    return { x: c.x + o.x, y: c.y + o.y };
}

// Where the box lands when the grip is dragged by (dx, dy) screen px from `base`.
// `min` is the smallest allowed box, in fractions, so a look cannot be sized away.
function resize(base, deg, dx, dy, screen, min) {
    var l = intoBox(dx, dy, deg);
    var wpx = Math.max(min.w * screen.w, base.w * screen.w + l.x);
    var hpx = Math.max(min.h * screen.h, base.h * screen.h + l.y);
    var a = anchorAt(base, deg, screen);
    var half = turn(wpx / 2, hpx / 2, deg * Math.PI / 180);
    var cx = a.x + half.x;
    var cy = a.y + half.y;
    return {
        x: (cx - wpx / 2) / screen.w,
        y: (cy - hpx / 2) / screen.h,
        w: wpx / screen.w,
        h: hpx / screen.h
    };
}

// A turn taken from where the pointer is around the box centre. Reported as a delta
// from the press so the lever never jumps to the pointer on the first motion, with a
// gentle magnet on every `step` degrees: square and diagonal land without care, and
// everything between stays free.
function angleAt(cx, cy, px, py) {
    return Math.atan2(py - cy, px - cx) * 180 / Math.PI;
}

function magnet(deg, step, tol) {
    var snap = Math.round(deg / step) * step;
    return Math.abs(deg - snap) < tol ? snap : deg;
}

function wrap(deg) {
    var d = deg % 360;
    return d < 0 ? d + 360 : d;
}

// The shortest way round from `from` to `to`, so easing through 360 does not send a
// look the long way back.
function shortestTurn(from, to) {
    return ((to - from + 540) % 360) - 180;
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { turn, intoBox, centreOf, gripAt, anchorAt, resize, angleAt, magnet, wrap, shortestTurn };
