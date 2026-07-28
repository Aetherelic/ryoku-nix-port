import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const BarCatalog = require("../../../framebars/BarCatalog.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(condition, msg) { eq(!!condition, true, msg); }

const requiredBars = ["audio-input", "audio-output", "battery", "bluetooth", "clock",
    "dock", "workspaces", "lock", "logout", "music", "network",
    "notifications", "quick-settings", "recording", "sysmon", "shutdown", "tray", "vpn"];
eq(BarCatalog.ids().sort(), requiredBars.sort(), "all approved bar widgets are catalogued");
ok(BarCatalog.entry("clock").axes.includes("horizontal"), "clock fits top rail");
ok(BarCatalog.entry("dock").axes.includes("vertical"), "dock fits left rail");
eq(Object.keys(BarCatalog.entry("clock")).sort(), ["axes", "id", "kind", "label", "menuId"], "entries expose the fixed contract");
eq(BarCatalog.entry("missing"), null, "unknown widgets have no catalog entry");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
