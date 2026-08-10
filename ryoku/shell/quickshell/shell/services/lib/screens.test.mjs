import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { uniqueByName } = require("./screens.js");

let failed = 0;
function eq(actual, expected, message) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + message);
    else { failed++; console.log("FAIL " + message + "\n  expected " + e + "\n  got      " + a); }
}
function ok(cond, message) {
    if (cond) console.log("PASS " + message);
    else { failed++; console.log("FAIL " + message); }
}

const scr = (name, width = 2560, height = 1600) => ({ name, width, height });
const names = list => list.map(s => s.name);

eq(names(uniqueByName([])), [], "empty list yields no surfaces");
eq(names(uniqueByName(undefined)), [], "missing list is tolerated");
eq(names(uniqueByName([{ name: "", width: 0, height: 0 }])), [], "nameless 0x0 placeholder is dropped");
eq(names(uniqueByName([scr("eDP-1"), scr("HDMI-A-1")])), ["eDP-1", "HDMI-A-1"], "distinct outputs are preserved in order");
eq(names(uniqueByName([scr("eDP-1"), scr("eDP-1")])), ["eDP-1"], "a duplicate output announce collapses to one surface set");
eq(names(uniqueByName([scr("eDP-1"), { name: "eDP-1", width: 0, height: 0 }])), ["eDP-1"], "an invalid same-name entry never adds a second bar");
eq(names(uniqueByName([{ name: "eDP-1", width: 0, height: 0 }, scr("eDP-1")])), ["eDP-1"], "a valid entry is kept even when an invalid same-name one precedes it");

const first = scr("eDP-1");
const second = scr("eDP-1");
const deduped = uniqueByName([first, second]);
ok(deduped.length === 1 && deduped[0] === first, "keeps the first ShellScreen object so forScreen() identity stays stable");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
