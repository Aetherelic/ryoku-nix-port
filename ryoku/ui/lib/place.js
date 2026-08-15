// Placement maths for a box that turns and leans, framework-free so the shell's
// placer and a test runner derive the same numbers. Everything works in px: a
// fraction of width and a fraction of height are different lengths, so a rotation
// between them would not be a rotation.

// Flat content turned about x by `ax` then y by `ay`, divided by 1 - Z/d for
// perspective. d scales with the box, so the same degrees read the same at any size.
function tiltMatrix(ax, ay, w, h) {
    if (!(w > 0) || !(h > 0))
        return identity();
    var a = ax * Math.PI / 180, b = ay * Math.PI / 180;
    var sa = Math.sin(a), ca = Math.cos(a);
    var sb = Math.sin(b), cb = Math.cos(b);
    var d = 1.2 * Math.max(w, h);
    var lean = [
        [cb, sb * sa, 0, 0],
        [0, ca, 0, 0],
        [0, 0, 1, 0],
        [sb / d, -cb * sa / d, 0, 1]
    ];
    // the shift after the lean is multiplied by w with it, which holds the centre
    var m = mul(shift(w / 2, h / 2), mul(lean, shift(-w / 2, -h / 2)));

    // Raw perspective leaves the box: the near edge magnifies past it, the far edge
    // falls short. An affine composed after a projective matrix acts on the divided
    // point, so this fits the picture just computed back onto the box.
    var q = [project(m, 0, 0), project(m, w, 0), project(m, 0, h), project(m, w, h)];
    var minX = Math.min(q[0].x, q[1].x, q[2].x, q[3].x);
    var maxX = Math.max(q[0].x, q[1].x, q[2].x, q[3].x);
    var minY = Math.min(q[0].y, q[1].y, q[2].y, q[3].y);
    var maxY = Math.max(q[0].y, q[1].y, q[2].y, q[3].y);
    var sx = w / Math.max(1e-6, maxX - minX);
    var sy = h / Math.max(1e-6, maxY - minY);
    var fit = mul(shift(w / 2, h / 2),
                  mul(scale(sx, sy), shift(-(minX + maxX) / 2, -(minY + maxY) / 2)));
    return mul(fit, m);
}

// Lean about the box's own axes, then spin. Qt composes an item's `transform` list
// outside its `rotation`, so setting both gives the reverse and shears the bands.
function boxMatrix(deg, ax, ay, w, h) {
    return mul(spin(deg, w / 2, h / 2), tiltMatrix(ax, ay, w, h));
}

function spin(deg, cx, cy) {
    var a = deg * Math.PI / 180;
    var c = Math.cos(a), s = Math.sin(a);
    var r = [[c, -s, 0, 0], [s, c, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]];
    return mul(shift(cx, cy), mul(r, shift(-cx, -cy)));
}

function scale(sx, sy) {
    return [[sx, 0, 0, 0], [0, sy, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]];
}

function identity() {
    return [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]];
}

function shift(dx, dy) {
    return [[1, 0, 0, dx], [0, 1, 0, dy], [0, 0, 1, 0], [0, 0, 0, 1]];
}

function mul(m, n) {
    var out = [];
    for (var r = 0; r < 4; r++) {
        out.push([]);
        for (var c = 0; c < 4; c++) {
            var s = 0;
            for (var k = 0; k < 4; k++)
                s += m[r][k] * n[k][c];
            out[r].push(s);
        }
    }
    return out;
}

// Row major and flat, which is the order Qt.matrix4x4 takes its sixteen arguments.
function flat(m) {
    return m[0].concat(m[1], m[2], m[3]);
}

// Where a point lands once the matrix is applied and the perspective divided out.
function project(m, x, y) {
    var w = m[3][0] * x + m[3][1] * y + m[3][3];
    return {
        x: (m[0][0] * x + m[0][1] * y + m[0][3]) / w,
        y: (m[1][0] * x + m[1][1] * y + m[1][3]) / w
    };
}

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

// The grip rides the box's local bottom right; the anchor is diagonally opposite.
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

// Reported as a delta from the press, so the lever never jumps to the pointer, with
// a magnet on every `step` degrees.
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
    module.exports = { turn, intoBox, centreOf, gripAt, anchorAt, resize, angleAt, magnet, wrap, shortestTurn,
                       boxMatrix, spin,
                       tiltMatrix, identity, flat, project };
