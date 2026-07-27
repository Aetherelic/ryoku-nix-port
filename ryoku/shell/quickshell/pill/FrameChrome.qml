import QtQuick

// The frame's painted chrome: per-edge surface bands around a rounded hole,
// with a 2px outline stroked just inside the hole edge, arcs included. One
// paint pass, exact geometry; repaints only when a reserve, colour, or radius
// changes (the bar reveal animates the reserves, so it repaints through the
// 250ms envelope and is then idle).
Canvas {
    id: chrome

    property real reserveLeft: 0
    property real reserveTop: 0
    property real reserveRight: 0
    property real reserveBottom: 0
    property real holeRadius: 8
    property color surface: "#101315"
    property color outline: "#565d60"
    property real strokeWidth: 2

    renderStrategy: Canvas.Cooperative

    onReserveLeftChanged: requestPaint()
    onReserveTopChanged: requestPaint()
    onReserveRightChanged: requestPaint()
    onReserveBottomChanged: requestPaint()
    onHoleRadiusChanged: requestPaint()
    onSurfaceChanged: requestPaint()
    onOutlineChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function holePath(ctx, x, y, w, h, r) {
        const cr = Math.max(0, Math.min(r, Math.min(w, h) / 2));
        ctx.moveTo(x + cr, y);
        ctx.lineTo(x + w - cr, y);
        ctx.arcTo(x + w, y, x + w, y + cr, cr);
        ctx.lineTo(x + w, y + h - cr);
        ctx.arcTo(x + w, y + h, x + w - cr, y + h, cr);
        ctx.lineTo(x + cr, y + h);
        ctx.arcTo(x, y + h, x, y + h - cr, cr);
        ctx.lineTo(x, y + cr);
        ctx.arcTo(x, y, x + cr, y, cr);
        ctx.closePath();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const hx = reserveLeft;
        const hy = reserveTop;
        const hw = width - reserveLeft - reserveRight;
        const hh = height - reserveTop - reserveBottom;
        if (hw <= 0 || hh <= 0) {
            ctx.fillStyle = surface;
            ctx.fillRect(0, 0, width, height);
            return;
        }

        // Band fill: whole surface minus the rounded hole (evenodd).
        ctx.beginPath();
        ctx.rect(0, 0, width, height);
        holePath(ctx, hx, hy, hw, hh, holeRadius);
        ctx.fillStyle = surface;
        ctx.fill("evenodd");

        // The outline hugs the hole from the band side: a 2px stroke centred on
        // the hole path grown by half the stroke, so its ink spans the two
        // pixels just inside the hole edge and rounds through the corners.
        const g = strokeWidth / 2;
        ctx.beginPath();
        holePath(ctx, hx - g, hy - g, hw + strokeWidth, hh + strokeWidth, holeRadius + g);
        ctx.lineWidth = strokeWidth;
        ctx.strokeStyle = outline;
        ctx.stroke();
    }
}
