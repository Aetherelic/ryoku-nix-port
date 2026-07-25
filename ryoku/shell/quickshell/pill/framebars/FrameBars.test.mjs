import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { defaultConfig, normalize, addWidget, moveWidget, removeWidget, setMenu, setSurface } = require("./FrameBars.js");
const BarCatalog = require("./BarCatalog.js");
const MenuCatalog = require("./MenuCatalog.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

const reference = defaultConfig();
eq(reference.rails.top.center, ["clock"], "reference clock is top-centre");
eq(reference.rails.left.center, ["dock"], "reference dock is left-centre");
eq(reference.rails.bottom.enabled, false, "bottom rail starts disabled");
eq(reference.rails.left.bottom, ["tray", "network", "clock"], "reference vertical rail shape is preserved");
eq(reference.rails.right.top, [], "disabled right rail retains vertical zones");

const normalized = normalize({
    version: 99,
    style: "unknown",
    rails: {
        top: { size: 2, start: ["tray", "tray", "dock", "bad"], center: "clock", unknown: true },
        left: { enabled: "no", size: 900, top: ["clock", "clock", "bad"], center: ["dock"] }
    },
    menus: { "quick-settings": { anchor: "wrong", minWidth: 1, expansion: "sometimes", widgets: ["clock", "bad"] } },
    surfaces: { stash: { anchor: "bad", minWidth: 9999, panes: ["stash", "bad"] } },
    dock: { pinned: ["firefox", 4] },
    arbitrary: true
}, BarCatalog, MenuCatalog);
eq(normalized.style, "ok-frame", "normalizer resets invalid style");
eq(normalized.rails.top.size, 16, "normalizer clamps horizontal size");
eq(normalized.rails.left.size, 112, "normalizer clamps vertical size");
eq(normalized.rails.left.top, ["clock"], "normalizer drops duplicate and unknown identifiers");
eq(normalized.rails.top.center, ["clock"], "normalizer restores malformed zones");
eq(normalized.menus["quick-settings"].anchor, "left", "normalizer restores invalid menu anchor");
eq(normalized.surfaces.stash.anchor, "left", "normalizer normalizes invalid surface anchor");
eq(normalized.arbitrary, undefined, "normalizer drops arbitrary keys");

eq(addWidget(reference, "top", "start", "tray", BarCatalog).rails.top.start, ["tray"], "compatible top widget is added");
eq(addWidget(reference, "left", "top", "tray", BarCatalog).rails.left.top, ["tray"], "compatible left widget is added");
eq(addWidget(reference, "top", "start", "dock", BarCatalog).rails.top.start, [], "cross-axis widget is rejected");
eq(moveWidget(reference, "left", "bottom", 0, "left", "bottom", 2, BarCatalog).rails.left.bottom, ["network", "clock", "tray"], "same-zone move honors target index");
eq(moveWidget(reference, "left", "center", 0, "top", "end", 0, BarCatalog).rails.left.center, ["dock"], "cross-axis move leaves config unchanged");
eq(removeWidget(reference, "left", "center", 0).rails.left.center, [], "remove deletes only requested occurrence");
eq(addWidget(reference, "top", "start", "clock", BarCatalog).rails.top.start, ["clock"], "widgets may occupy different zones");
eq(setMenu(reference, "quick-settings", { anchor: "top-right", widgets: ["clock"] }, MenuCatalog).menus["quick-settings"].anchor, "top-right", "menu updates normalize anchors");
eq(setSurface(reference, "stash", { anchor: "bad" }, MenuCatalog).surfaces.stash.anchor, "left", "surface updates normalize anchors");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
