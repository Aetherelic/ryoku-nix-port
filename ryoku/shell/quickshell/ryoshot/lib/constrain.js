// A zero delta keeps a positive sign so a click cannot produce a negative box.
function square(start, end) {
    var dx = end.x - start.x;
    var dy = end.y - start.y;
    var extent = Math.max(Math.abs(dx), Math.abs(dy));
    var sx = dx < 0 ? -1 : 1;
    var sy = dy < 0 ? -1 : 1;
    return { x: start.x + sx * extent, y: start.y + sy * extent };
}

function snap45(start, end) {
    var dx = end.x - start.x;
    var dy = end.y - start.y;
    var angle = Math.atan2(dy, dx);
    var step = Math.PI / 4;
    var q = Math.round(angle / step) * step;
    var len = Math.hypot(dx, dy);
    return { x: start.x + Math.cos(q) * len, y: start.y + Math.sin(q) * len };
}

function constrain(tool, start, end) {
    switch (tool) {
    case "rect":
    case "ellipse":
    case "spotlight":
    case "redact":
    case "pixelate":
    case "blur":
    case "magnify":
        return square(start, end);
    case "line":
    case "arrow":
        return snap45(start, end);
    default:
        return end;
    }
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { square, snap45, constrain };
}
