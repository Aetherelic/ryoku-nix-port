import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { nerdFor, symbolFor, glyphFor, labelFor } = require("./weather.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

// WMO code -> Nerd Font weather glyph, the set the qsbar bar widget draws inline
// with its clock. Day/night faces where the font has both.
eq(nerdFor(0, true), "\ue30d", "clear day");
eq(nerdFor(0, false), "\ue32b", "clear night");
eq(nerdFor(2, true), "\ue302", "partly cloudy day");
eq(nerdFor(2, false), "\ue32e", "partly cloudy night");
eq(nerdFor(3, true), "\ue33d", "overcast");
eq(nerdFor(45, true), "\ue313", "fog");
eq(nerdFor(48, true), "\ue313", "depositing rime fog");
eq(nerdFor(53, true), "\ue308", "drizzle day");
eq(nerdFor(53, false), "\ue333", "drizzle night");
eq(nerdFor(63, true), "\ue30a", "rain day");
eq(nerdFor(63, false), "\ue327", "rain night");
eq(nerdFor(67, true), "\ue318", "freezing rain reads as sleet");
eq(nerdFor(73, true), "\ue3ad", "snow");
eq(nerdFor(81, true), "\ue308", "rain showers day");
eq(nerdFor(86, true), "\ue31a", "snow showers");
eq(nerdFor(99, true), "\ue31d", "thunder with hail");

// Defaults and unknown codes: one glyph, never empty, never the thunder bolt for
// a code the map does not know.
eq(nerdFor(0), "\ue30d", "isDay defaults to day");
eq(nerdFor(999, true), "\ue33d", "unknown code falls back to cloud");
eq(nerdFor(-1, true), "\ue33d", "negative code falls back to cloud");
for (const code of [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67,
                    71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]) {
    for (const day of [true, false]) {
        const glyph = nerdFor(code, day);
        eq([...glyph].length, 1, "code " + code + (day ? " day" : " night") + " is one glyph");
    }
}

// The three maps stay in step on the same code: a rainy code is rainy in all of
// them, so the bar glyph, the dashboard icon and the label never disagree.
eq(glyphFor(63), "rain", "code 63 -> rain family");
eq(symbolFor(63, true), "rainy", "code 63 -> Material rainy");
eq(labelFor(63), "Rain", "code 63 -> Rain label");

if (failed > 0) {
    console.log(failed + " assertion(s) failed");
    process.exit(1);
}
console.log("weather model: ok");
