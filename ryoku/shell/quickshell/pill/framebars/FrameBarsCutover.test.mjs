import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { normalize } = require("../../../framebars/FrameBars.js");
const { edgeRect } = require("./RailGeometry.js");
const BarCatalog = require("../../../framebars/BarCatalog.js");
const MenuCatalog = require("../../../framebars/MenuCatalog.js");

let failed = 0;

function eq(actual, expected, message) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + message);
    else {
        failed++;
        console.log("FAIL " + message + "\n  expected " + e + "\n  got      " + a);
    }
}

function layout(style, rails) {
    return normalize({ version: 1, style, rails }, BarCatalog, MenuCatalog);
}

const topLeft = layout("slate-frame", {
    top: { enabled: true, size: 32, start: ["workspaces"], center: ["clock"], end: ["quick-settings"] },
    left: { enabled: true, size: 44, top: ["launcher"], center: ["dock"], bottom: ["tray"] },
    bottom: { enabled: false },
    right: { enabled: false }
});
const bottomRight = layout("ryoku-frame", {
    top: { enabled: false },
    left: { enabled: false },
    bottom: { enabled: true, size: 32, start: ["workspaces"], center: ["clock"], end: ["quick-settings"] },
    right: { enabled: true, size: 44, top: ["launcher"], center: ["dock"], bottom: ["tray"] }
});

eq(topLeft.style, "slate-frame", "slate-frame top-left style survives normalization");
eq(bottomRight.style, "ryoku-frame", "ryoku-frame bottom-right style survives normalization");
eq(edgeRect("top", topLeft.rails.top.size, 1920, 1080), { x: 0, y: 0, width: 1920, height: 32 }, "top rail is visibly placed at the top edge");
eq(edgeRect("left", topLeft.rails.left.size, 1920, 1080), { x: 0, y: 0, width: 44, height: 1080 }, "left rail is visibly placed at the left edge");
eq(edgeRect("bottom", bottomRight.rails.bottom.size, 1920, 1080), { x: 0, y: 1048, width: 1920, height: 32 }, "bottom rail is visibly placed at the bottom edge");
eq(topLeft.rails.right.enabled, false, "disabled right rail does not occupy the top-left layout");
eq(edgeRect("right", bottomRight.rails.right.size, 1920, 1080), { x: 1876, y: 0, width: 44, height: 1080 }, "right rail is visibly placed at the right edge");


if (failed > 0) {
    console.log("\n" + failed + " cutover probe assertion(s) FAILED");
    process.exit(1);
}
console.log("\nFrameBars cutover probe PASSED");
