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

// --- leaning into depth ---------------------------------------------------
// `angle` spins the look in the plane of the screen. A lean is the other kind of
// turn: the box pivots about its own horizontal or vertical axis so one edge goes
// away from the viewer and the other comes forward. That needs a perspective
// divide, or the lean is only a squash and reads as nothing.
//
// Flat content (z = 0 everywhere) turned about x by `ax` then about y by `ay`:
//     X = cb*u + sb*sa*v      Y = ca*v      Z = -sb*u + cb*sa*v
// and the divide by 1 - Z/d is the perspective. The viewer distance d scales with
// the box, so a lean of the same degrees reads the same at any size, and it is far
// enough back that the near edge grows by about a third rather than exploding.
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
    // about the box's own centre: the shift after the lean is multiplied by w with
    // it, which is what keeps the centre still through the divide.
    var m = mul(shift(w / 2, h / 2), mul(lean, shift(-w / 2, -h / 2)));

    // A lean leaves the box: the near edge magnifies past it and the far edge falls
    // short, so the look both spilled over one side and left dead space at the other.
    // Fitting the leaned quad back onto the box makes the box mean what it says
    // again, which is what the placement guides and the gestures are drawn from.
    // An affine composed after a projective matrix acts on the divided point, so
    // this is exactly "scale the picture I just computed".
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
    module.exports = { turn, intoBox, centreOf, gripAt, anchorAt, resize, angleAt, magnet, wrap, shortestTurn,
                       tiltMatrix, identity, flat, project };
