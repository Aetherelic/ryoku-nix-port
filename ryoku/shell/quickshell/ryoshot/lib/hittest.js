function bboxOf(a) {
    var xs = a.points.map(function (p) { return p.x; });
    var ys = a.points.map(function (p) { return p.y; });
    var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs);
    var y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);
    if (a.type === "text") {
        var size = a.size || 16;
        var w = Math.max((a.text ? a.text.length : 1) * size * 0.6, size);
        return { x: x0, y: y0, w: w, h: size * 1.4 };
    }
    if (a.type === "counter") {
        var cr = (a.width || 4) * 2.5 + 9;
        return { x: x0 - cr, y: y0 - cr, w: 2 * cr, h: 2 * cr };
    }
    return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

function distToSeg(px, py, a, b) {
    var dx = b.x - a.x, dy = b.y - a.y;
    var len2 = dx * dx + dy * dy;
    if (len2 === 0) return Math.hypot(px - a.x, py - a.y);
    var t = ((px - a.x) * dx + (py - a.y) * dy) / len2;
    t = Math.max(0, Math.min(1, t));
    return Math.hypot(px - (a.x + t * dx), py - (a.y + t * dy));
}

function inBox(gx, gy, b, pad) {
    return gx >= b.x - pad && gx <= b.x + b.w + pad
        && gy >= b.y - pad && gy <= b.y + b.h + pad;
}

function hitOne(a, gx, gy) {
    var tol = Math.max(a.width || 4, 8);
    if (a.type === "rect" || a.type === "marker" || a.type === "blur"
        || a.type === "redact" || a.type === "pixelate" || a.type === "magnify"
        || a.type === "spotlight" || a.type === "text")
        return inBox(gx, gy, bboxOf(a), a.type === "text" ? 0 : tol);
    if (a.type === "line" || a.type === "arrow")
        return distToSeg(gx, gy, a.points[0], a.points[1]) <= tol;
    if (a.type === "pen") {
        for (var i = 1; i < a.points.length; i++)
            if (distToSeg(gx, gy, a.points[i - 1], a.points[i]) <= tol) return true;
        return false;
    }
    if (a.type === "ellipse") {
        var b = bboxOf(a);
        var rx = b.w / 2 + tol, ry = b.h / 2 + tol;
        if (rx <= 0 || ry <= 0) return false;
        var nx = (gx - (b.x + b.w / 2)) / rx, ny = (gy - (b.y + b.h / 2)) / ry;
        return nx * nx + ny * ny <= 1;
    }
    if (a.type === "counter")
        return inBox(gx, gy, bboxOf(a), tol);
    return false;
}

function hitTest(items, gx, gy) {
    for (var i = items.length - 1; i >= 0; i--)
        if (hitOne(items[i], gx, gy)) return i;
    return null;
}

function handleRoles() {
    return ["tl", "t", "tr", "r", "br", "b", "bl", "l"];
}

/** Global centre point of the resize handle named by role on rect {x,y,w,h}. */
function handleCenter(rect, role) {
    var cx = rect.x + rect.w / 2, cy = rect.y + rect.h / 2;
    var x0 = rect.x, y0 = rect.y, x1 = rect.x + rect.w, y1 = rect.y + rect.h;
    switch (role) {
        case "tl": return { x: x0, y: y0 };
        case "t": return { x: cx, y: y0 };
        case "tr": return { x: x1, y: y0 };
        case "r": return { x: x1, y: cy };
        case "br": return { x: x1, y: y1 };
        case "b": return { x: cx, y: y1 };
        case "bl": return { x: x0, y: y1 };
        case "l": return { x: x0, y: cy };
    }
    return null;
}

/**
 * Role of the resize handle within Chebyshev distance tol of (gx, gy), or null.
 * Corners are tested before edges so a corner wins any overlap.
 */
function handleAt(rect, gx, gy, tol) {
    var order = ["tl", "tr", "br", "bl", "t", "r", "b", "l"];
    for (var i = 0; i < order.length; i++) {
        var c = handleCenter(rect, order[i]);
        if (Math.abs(gx - c.x) <= tol && Math.abs(gy - c.y) <= tol) return order[i];
    }
    return null;
}

/**
 * Resize rect {x,y,w,h} by dragging handle role to (gx, gy). Only the named
 * edges move; each axis is clamped to at least min so the rect can never invert.
 * Returns a new rect object.
 */
function resizeRect(rect, role, gx, gy, min) {
    var x0 = rect.x, y0 = rect.y, x1 = rect.x + rect.w, y1 = rect.y + rect.h;
    if (role === "l" || role === "tl" || role === "bl") x0 = Math.min(gx, x1 - min);
    if (role === "r" || role === "tr" || role === "br") x1 = Math.max(gx, x0 + min);
    if (role === "t" || role === "tl" || role === "tr") y0 = Math.min(gy, y1 - min);
    if (role === "b" || role === "bl" || role === "br") y1 = Math.max(gy, y0 + min);
    return { x: x0, y: y0, w: x1 - x0, h: y1 - y0 };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        bboxOf: bboxOf, distToSeg: distToSeg, inBox: inBox, hitOne: hitOne,
        hitTest: hitTest, handleRoles: handleRoles, handleCenter: handleCenter,
        handleAt: handleAt, resizeRect: resizeRect
    };
}
