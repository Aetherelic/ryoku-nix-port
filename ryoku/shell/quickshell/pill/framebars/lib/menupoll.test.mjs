import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { watchDelta } = require("./menupoll.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

// A menu that owns a shared poller (Toggles.watchers) bumps the refcount on open
// and releases it on close. The delta must be idempotent so opening/closing the
// same menu twice never leaves a duplicate background scan running.
eq(watchDelta(false, true), { watching: true, delta: 1 }, "opening a closed menu starts one scan");
eq(watchDelta(true, true), { watching: true, delta: 0 }, "re-affirming an open menu adds no duplicate scan");
eq(watchDelta(true, false), { watching: false, delta: -1 }, "closing an open menu releases its scan");
eq(watchDelta(false, false), { watching: false, delta: 0 }, "a menu that was never watching releases nothing");

// double open then double close nets to zero: no leaked scan.
let w = false, net = 0;
for (const open of [true, true, false, false]) {
    const r = watchDelta(w, open);
    w = r.watching;
    net += r.delta;
}
eq(net, 0, "open, open, close, close leaves the refcount balanced");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
