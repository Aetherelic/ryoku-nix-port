pragma Singleton

import QtQuick
import Quickshell

Singleton {
    readonly property var skins: []

    function pill(c, x, y, w, h, r) {
        c.beginPath();
        c.moveTo(x + r, y);
        c.lineTo(x + w - r, y); c.quadraticCurveTo(x + w, y, x + w, y + r);
        c.lineTo(x + w, y + h - r); c.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
        c.lineTo(x + r, y + h); c.quadraticCurveTo(x, y + h, x, y + h - r);
        c.lineTo(x, y + r); c.quadraticCurveTo(x, y, x + r, y);
        c.closePath();
    }

    function dot(c, x, y, r) {
        c.beginPath(); c.arc(x, y, r, 0, 2 * Math.PI); c.closePath();
    }

    function draw(c, kind, w, h, fgA, dimA) {
        var fg = "rgba(205,196,186," + fgA + ")";
        var dim = "rgba(205,196,186," + dimA + ")";
        var cx = w / 2;
        var cy = h / 2;
        var outerR = kind === "ryoku" ? 1 : 4;
        var innerR = kind === "ryoku" ? 1 : 2;
        c.lineWidth = 1;
        c.fillStyle = dim;
        c.strokeStyle = fg;

        pill(c, 3, cy - 6, 20, 12, outerR); c.fill();
        c.fillStyle = fg; pill(c, 6, cy - 3, 6, 6, innerR); c.fill();
        c.fillStyle = dim; dot(c, 17, cy, 1.8); c.fill();
        pill(c, cx - 16, cy - 6, 32, 12, outerR); c.fill();
        c.fillStyle = fg; c.fillRect(cx - 9, cy - 2, 18, 4);
        c.fillStyle = dim; pill(c, w - 30, cy - 6, 27, 12, outerR); c.fill();
        c.fillStyle = fg;
        for (var i = 0; i < 3; i++) {
            dot(c, w - 24 + i * 7, cy, 1.6);
            c.fill();
        }
    }
}
