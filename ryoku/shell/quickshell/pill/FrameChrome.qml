import QtQuick

// The frame's painted chrome: the surface band around a rounded hole, with a
// 2px outline hugging the hole edge from the band side, arcs included. When a
// menu is open the hole is the inner desktop rect MINUS the menu's panel rect,
// so the open panel reads as the band grown wider on that edge or corner: one
// silhouette, one stroke, no second surface (menu parity spec). One paint pass;
// it repaints only when a reserve, the panel rect, a colour or the radius
// changes. The bar reveal animates the reserves and the menu reveal animates
// the panel rect, so the canvas repaints through those envelopes and is idle at
// rest.
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

    // The open menu's panel rect (window coords) and its anchor, driven by the
    // menu manager and already interpolated by the reveal, so the band and its
    // stroke track the panel edge every frame. A zero-area rect (or an empty
    // anchor) means no panel is open: the hole is the plain desktop rect.
    property real panelX: 0
    property real panelY: 0
    property real panelW: 0
    property real panelH: 0
    property string panelAnchor: ""
    property var topLobes: []

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
    onPanelXChanged: requestPaint()
    onPanelYChanged: requestPaint()
    onPanelWChanged: requestPaint()
    onPanelHChanged: requestPaint()
    onPanelAnchorChanged: requestPaint()
    onTopLobesChanged: requestPaint()

    function normalizedTopLobes(lx, ty, rx, lobes) {
        const source = Array.isArray(lobes) ? lobes : [];
        const output = [];
        for (const lobe of source) {
            if (!lobe || lobe.visible === false)
                continue;
            const left = Math.max(lx, Math.min(rx, Number(lobe.x) || 0));
            const right = Math.max(lx, Math.min(rx,
                (Number(lobe.x) || 0) + (Number(lobe.width) || 0)));
            const bottom = Math.max(ty,
                (Number(lobe.y) || 0) + (Number(lobe.height) || 0));
            if (right > left && bottom > ty)
                output.push({ left, right, bottom });
        }
        output.sort((a, b) => a.left - b.left);
        return output;
    }

    function topHolePoints(lx, ty, rx, by, lobes) {
        const points = [{ x: lx, y: ty }];
        let cursor = lx;
        for (const lobe of lobes) {
            if (lobe.left > cursor)
                points.push({ x: lobe.left, y: ty });
            points.push(
                { x: lobe.left, y: lobe.bottom },
                { x: lobe.right, y: lobe.bottom },
                { x: lobe.right, y: ty }
            );
            cursor = Math.max(cursor, lobe.right);
        }
        if (cursor < rx)
            points.push({ x: rx, y: ty });
        points.push({ x: rx, y: by }, { x: lx, y: by });
        return points;
    }

    // The rectilinear hole silhouette as a clockwise point list: the inner
    // desktop rect [lx,ty]-[rx,by] with the open panel carved out of the edge
    // or corner it anchors to. Every convex and concave corner in the list is
    // rounded at holeRadius by traceHole. Side panels (left/right) span the
    // full band height, so the hole stays a rounded rect with one edge moved;
    // edge panels (top/bottom) notch the centre of that edge; corner panels
    // bite the corner, leaving one concave inside corner.
    function holePoints(lx, ty, rx, by, lobes) {
        const a = panelAnchor;
        const top = normalizedTopLobes(lx, ty, rx, lobes);
        if (a === "" && top.length > 0)
            return topHolePoints(lx, ty, rx, by, top);
        const px = panelX, py = panelY, pr = panelX + panelW, pb = panelY + panelH;
        if (a === "" || panelW <= 0 || panelH <= 0)
            return [ {x: lx, y: ty}, {x: rx, y: ty}, {x: rx, y: by}, {x: lx, y: by} ];
        if (a === "left")
            return [ {x: pr, y: ty}, {x: rx, y: ty}, {x: rx, y: by}, {x: pr, y: by} ];
        if (a === "right")
            return [ {x: lx, y: ty}, {x: px, y: ty}, {x: px, y: by}, {x: lx, y: by} ];
        if (a === "top")
            return [ {x: lx, y: ty}, {x: px, y: ty}, {x: px, y: pb}, {x: pr, y: pb}, {x: pr, y: ty}, {x: rx, y: ty}, {x: rx, y: by}, {x: lx, y: by} ];
        if (a === "bottom")
            return [ {x: lx, y: ty}, {x: rx, y: ty}, {x: rx, y: by}, {x: pr, y: by}, {x: pr, y: py}, {x: px, y: py}, {x: px, y: by}, {x: lx, y: by} ];
        if (a === "top-left")
            return [ {x: pr, y: ty}, {x: rx, y: ty}, {x: rx, y: by}, {x: lx, y: by}, {x: lx, y: pb}, {x: pr, y: pb} ];
        if (a === "top-right")
            return [ {x: lx, y: ty}, {x: px, y: ty}, {x: px, y: pb}, {x: rx, y: pb}, {x: rx, y: by}, {x: lx, y: by} ];
        if (a === "bottom-left")
            return [ {x: lx, y: ty}, {x: rx, y: ty}, {x: rx, y: by}, {x: pr, y: by}, {x: pr, y: py}, {x: lx, y: py} ];
        if (a === "bottom-right")
            return [ {x: lx, y: ty}, {x: rx, y: ty}, {x: rx, y: py}, {x: px, y: py}, {x: px, y: by}, {x: lx, y: by} ];
        return [ {x: lx, y: ty}, {x: rx, y: ty}, {x: rx, y: by}, {x: lx, y: by} ];
    }

    // Round each corner of a rectilinear point list with arcTo, clamping the
    // radius to half of each adjacent edge so short edges (a barely-open panel)
    // never overshoot. arcTo rounds convex and concave turns alike, so one loop
    // covers the whole silhouette.
    function traceHole(ctx, pts, r) {
        const n = pts.length;
        if (n < 3)
            return;
        function dist(a, b) { return Math.sqrt((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)); }
        function mid(a, b) { return {x: (a.x + b.x) / 2, y: (a.y + b.y) / 2}; }
        const start = mid(pts[n - 1], pts[0]);
        ctx.moveTo(start.x, start.y);
        for (let i = 0; i < n; ++i) {
            const cur = pts[i];
            const nxt = pts[(i + 1) % n];
            const prv = pts[(i - 1 + n) % n];
            const rr = Math.max(0, Math.min(r, dist(prv, cur) / 2, dist(cur, nxt) / 2));
            const m = mid(cur, nxt);
            ctx.arcTo(cur.x, cur.y, m.x, m.y, rr);
        }
        ctx.closePath();
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const lx = reserveLeft;
        const ty = reserveTop;
        const rx = width - reserveRight;
        const by = height - reserveBottom;
        if (rx - lx <= 0 || by - ty <= 0) {
            ctx.fillStyle = surface;
            ctx.fillRect(0, 0, width, height);
            return;
        }
        const pts = holePoints(lx, ty, rx, by, topLobes);

        // The whole frame is surface; the hole is punched back out below.
        ctx.fillStyle = surface;
        ctx.fillRect(0, 0, width, height);

        // Outline: stroke the silhouette at double width straddling the edge,
        // then clear the hole interior. What survives is exactly strokeWidth of
        // ink on the band side of the hole edge -- the 2px the reference paints
        // just inside the band, arcs and inside corner included.
        ctx.beginPath();
        traceHole(ctx, pts, holeRadius);
        ctx.lineWidth = strokeWidth * 2;
        ctx.strokeStyle = outline;
        ctx.lineJoin = "round";
        ctx.stroke();

        ctx.save();
        ctx.beginPath();
        traceHole(ctx, pts, holeRadius);
        ctx.clip();
        ctx.clearRect(0, 0, width, height);
        ctx.restore();
    }
}
