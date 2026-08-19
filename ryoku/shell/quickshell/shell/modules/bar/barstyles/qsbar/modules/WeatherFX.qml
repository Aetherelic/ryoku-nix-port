import QtQuick

// Weather-condition Canvas FX (rain/snow/storm/cloud/sun/stars/fog) by WMO
// category + day/night. Deterministic seeding; ticks only while `active`.
Item {
    id: fx

    property string kind: "cloud"    // sun | cloud | fog | rain | snow | storm
    property bool isDay: true
    property bool active: true
    property color tint: "#ffffff"

    clip: true

    property int frame: 0
    property real flash: 0
    property var parts: []

    // fract(sin(seed)*C): a stable pseudo-random in [0,1) without Math.random.
    function rnd(s) { var x = Math.sin(s * 12.9898) * 43758.5453; return x - Math.floor(x); }

    function seed() {
        var arr = [], i, w = Math.max(1, width), h = Math.max(1, height);
        if (fx.kind === "rain" || fx.kind === "storm") {
            for (i = 0; i < 46; i++) arr.push({ x: fx.rnd(i) * w, y: fx.rnd(i + 9) * h, len: 8 + fx.rnd(i + 3) * 10, spd: 6 + fx.rnd(i + 5) * 5 });
        } else if (fx.kind === "snow") {
            for (i = 0; i < 34; i++) arr.push({ x: fx.rnd(i) * w, y: fx.rnd(i + 9) * h, r: 1.2 + fx.rnd(i + 2) * 2, spd: 0.6 + fx.rnd(i + 5) * 1.1, ph: fx.rnd(i + 7) * 6.28 });
        } else if (fx.kind === "cloud") {
            for (i = 0; i < 5; i++) arr.push({ x: fx.rnd(i) * w, y: (0.12 + fx.rnd(i + 4) * 0.5) * h, s: 0.6 + fx.rnd(i + 2) * 0.9, spd: 0.12 + fx.rnd(i + 6) * 0.22 });
        } else if (fx.kind === "sun" && !fx.isDay) {
            for (i = 0; i < 26; i++) arr.push({ x: fx.rnd(i) * w, y: fx.rnd(i + 9) * h, ph: fx.rnd(i + 3) * 6.28, r: 0.6 + fx.rnd(i + 5) * 1.1 });
        } else if (fx.kind === "fog") {
            for (i = 0; i < 4; i++) arr.push({ y: (0.22 + i * 0.2) * h, off: fx.rnd(i) * w, spd: 0.2 + fx.rnd(i + 3) * 0.3 });
        } else {
            arr = [];
        }
        fx.parts = arr;
    }
    onKindChanged: fx.seed()
    onIsDayChanged: fx.seed()
    onWidthChanged: fx.seed()
    onHeightChanged: fx.seed()
    Component.onCompleted: fx.seed()

    function stepParts() {
        var w = width, h = height, p, i;
        if (fx.kind === "rain" || fx.kind === "storm") {
            for (i = 0; i < fx.parts.length; i++) { p = fx.parts[i]; p.y += p.spd; p.x += p.spd * 0.35; if (p.y > h) p.y = -p.len; if (p.x > w) p.x = 0; }
            if (fx.kind === "storm") { fx.flash *= 0.82; if (fx.flash < 0.02 && (fx.frame % 132) === 0) fx.flash = 1; }
        } else if (fx.kind === "snow") {
            for (i = 0; i < fx.parts.length; i++) { p = fx.parts[i]; p.y += p.spd; p.x += Math.sin(fx.frame * 0.03 + p.ph) * 0.4; if (p.y > h) p.y = -4; }
        } else if (fx.kind === "cloud") {
            for (i = 0; i < fx.parts.length; i++) { p = fx.parts[i]; p.x += p.spd; if (p.x - 80 * p.s > w) p.x = -80 * p.s; }
        } else if (fx.kind === "fog") {
            for (i = 0; i < fx.parts.length; i++) { p = fx.parts[i]; p.off += p.spd; if (p.off > w) p.off = 0; }
        }
    }

    Timer {
        running: fx.active && fx.visible && fx.width > 1
        interval: 33
        repeat: true
        onTriggered: { fx.frame++; fx.stepParts(); canvas.requestPaint(); }
    }
    onActiveChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            var ctx = getContext("2d"); ctx.reset();
            var w = width, h = height, i, p;
            var tr = Math.round(fx.tint.r * 255), tg = Math.round(fx.tint.g * 255), tb = Math.round(fx.tint.b * 255);
            function rgba(a) { return "rgba(" + tr + "," + tg + "," + tb + "," + a + ")"; }

            if (fx.kind === "rain" || fx.kind === "storm") {
                ctx.strokeStyle = rgba(0.32); ctx.lineWidth = 1.4; ctx.lineCap = "round";
                for (i = 0; i < fx.parts.length; i++) { p = fx.parts[i]; ctx.beginPath(); ctx.moveTo(p.x, p.y); ctx.lineTo(p.x - p.len * 0.35, p.y + p.len); ctx.stroke(); }
                if (fx.kind === "storm" && fx.flash > 0.02) { ctx.fillStyle = "rgba(255,255,255," + (fx.flash * 0.35) + ")"; ctx.fillRect(0, 0, w, h); }
            } else if (fx.kind === "snow") {
                ctx.fillStyle = rgba(0.75);
                for (i = 0; i < fx.parts.length; i++) { p = fx.parts[i]; ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 6.2832); ctx.fill(); }
            } else if (fx.kind === "cloud") {
                for (i = 0; i < fx.parts.length; i++) {
                    p = fx.parts[i]; var ch = 16 * p.s; ctx.fillStyle = rgba(0.05);
                    ctx.beginPath(); ctx.arc(p.x, p.y, ch, 0, 6.2832); ctx.arc(p.x + ch * 1.2, p.y - ch * 0.5, ch * 1.15, 0, 6.2832); ctx.arc(p.x + ch * 2.4, p.y, ch, 0, 6.2832); ctx.fill();
                }
            } else if (fx.kind === "sun" && fx.isDay) {
                var cx = w * 0.84, cy = h * 0.26, R = Math.min(w, h) * 0.62;
                var g = ctx.createRadialGradient(cx, cy, 2, cx, cy, R);
                g.addColorStop(0, rgba(0.30)); g.addColorStop(1, rgba(0));
                ctx.fillStyle = g; ctx.beginPath(); ctx.arc(cx, cy, R, 0, 6.2832); ctx.fill();
                ctx.strokeStyle = rgba(0.16); ctx.lineWidth = 2; var rot = fx.frame * 0.008;
                for (i = 0; i < 12; i++) { var a = rot + i * 0.5236; ctx.beginPath(); ctx.moveTo(cx + Math.cos(a) * R * 0.34, cy + Math.sin(a) * R * 0.34); ctx.lineTo(cx + Math.cos(a) * R * 0.6, cy + Math.sin(a) * R * 0.6); ctx.stroke(); }
            } else if (fx.kind === "sun" && !fx.isDay) {
                for (i = 0; i < fx.parts.length; i++) { p = fx.parts[i]; var tw = 0.30 + 0.5 * (0.5 + 0.5 * Math.sin(fx.frame * 0.05 + p.ph)); ctx.fillStyle = rgba(tw); ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 6.2832); ctx.fill(); }
            } else if (fx.kind === "fog") {
                for (i = 0; i < fx.parts.length; i++) { p = fx.parts[i]; ctx.fillStyle = rgba(0.05); ctx.fillRect(0, p.y - 6, w, 12); }
            }
        }
    }
}
