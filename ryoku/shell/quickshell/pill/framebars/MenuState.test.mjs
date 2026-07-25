import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { open, closeAt, activeAt } = require("./MenuState.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

let state = open({}, "eDP-1", { id: "quick-settings", anchor: "left" });
eq(activeAt(state, "eDP-1", "left").id, "quick-settings", "opens left menu");

state = open(state, "eDP-1", { id: "network", anchor: "left" });
eq(activeAt(state, "eDP-1", "left").id, "network", "replaces occupied anchor");

state = open(state, "eDP-1", { id: "clock", anchor: "top" });
eq(activeAt(state, "eDP-1", "left").id, "network", "left menu untouched by top open");
eq(activeAt(state, "eDP-1", "top").id, "clock", "distinct anchors coexist on one monitor");

state = open(state, "HDMI-A-1", { id: "clock", anchor: "left" });
eq(activeAt(state, "HDMI-A-1", "left").id, "clock", "second monitor owns its menu");
eq(activeAt(state, "eDP-1", "left").id, "network", "first monitor unaffected by second");

eq(activeAt(closeAt(state, "eDP-1", "left"), "eDP-1", "left"), null, "closes one anchor");
eq(activeAt(closeAt(state, "eDP-1", "left"), "HDMI-A-1", "left").id, "clock", "close leaves other monitor open");

const rejectId = open(state, "eDP-1", { id: "", anchor: "right" });
eq(activeAt(rejectId, "eDP-1", "right"), null, "rejects an empty catalog id");

const rejectAnchor = open(state, "eDP-1", { id: "network" });
eq(activeAt(rejectAnchor, "eDP-1", undefined), null, "rejects a missing anchor");

eq(activeAt(state, "eDP-1", "bottom"), null, "unset anchor is null");
eq(activeAt(state, "DP-9", "left"), null, "unknown monitor is null");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
