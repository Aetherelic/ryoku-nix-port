import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { stable } = require("./audioselect.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

// Pipewire rebuilds node objects on every graph change: identity churns but
// node.name is stable. The selected device must survive a refresh by name, not
// by object identity, so the highlight does not flicker mid-scan.
const before = [{ name: "speaker", label: "Speakers" }, { name: "bt", label: "WH-1000XM6" }];
const after = [{ name: "bt", label: "WH-1000XM6" }, { name: "speaker", label: "Speakers" }]; // reordered, new objects

eq(stable(after, "bt", null).label, "WH-1000XM6", "a remembered name resolves the fresh node after a refresh");
eq(stable(after, "bt", null) === after[0], true, "the resolved node is the fresh object, not a stale reference");

// when the remembered device is gone (unplugged), fall back to the live default.
const fallback = { name: "speaker", label: "Speakers" };
eq(stable([fallback], "bt", fallback).name, "speaker", "an unplugged selection falls back to the current default");
eq(stable([], "bt", fallback).name, "speaker", "an empty graph keeps the default rather than dropping selection");
eq(stable(after, null, fallback).name, "speaker", "with no remembered name the default wins");
eq(stable([], null, null), null, "nothing selectable is null, not a throw");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
