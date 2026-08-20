import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { uniqueByName, sliceForName, sliceForScreen } = require("./screens.js");

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
ok(deduped.length === 1 && deduped[0] === first, "keeps the first ShellScreen object, so a duplicate the compositor is about to drop rebuilds nothing");

// --- per-monitor slice lookup ---------------------------------------------

const slice = name => ({ modelData: name === null ? null : scr(name) });
const slices = [slice("eDP-1"), slice("HDMI-A-1")];

ok(sliceForName(slices, "HDMI-A-1") === slices[1], "a slice is found by output name");
ok(sliceForName(slices, "DP-3") === null, "an output with no slice built yet is null");
ok(sliceForName(slices, "") === null, "an empty name matches nothing");
ok(sliceForName(undefined, "eDP-1") === null, "a missing slice list is tolerated");
ok(sliceForName([slice(null), slices[0]], "eDP-1") === slices[0], "a slice whose screen went away is skipped, never dereferenced");
ok(sliceForScreen(slices, null) === null, "a null screen resolves to no slice");
ok(sliceForScreen(slices, scr("DP-3")) === null, "a new output gets no slice until its own is built");

// The lid case: an output disabled and re-enabled comes back as a new
// ShellScreen object under the same name. Matching on object identity returned
// nothing here, which left every binding reading the slice on its stale value.
const recreated = scr("eDP-1");
ok(recreated !== slices[0].modelData, "a re-enabled output is a different object");
ok(slices.find(s => s.modelData === recreated) === undefined, "identity matching misses it, which is the bug");
ok(sliceForScreen(slices, recreated) === slices[0], "matching on name still resolves it to its own slice");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
