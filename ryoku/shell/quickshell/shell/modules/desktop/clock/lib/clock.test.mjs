import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { parts, dateParts } = require("./clock.js");

let failed = 0;
function eq(actual, expected, message) {
    const a = JSON.stringify(actual), e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + message);
    else { failed++; console.log("FAIL " + message + "\n  expected " + e + "\n  got      " + a); }
}

// 2026-08-05 13:07:09 is a Wednesday (getDay() === 3, getMonth() === 7).
const d = new Date(2026, 7, 5, 13, 7, 9);

// fallback: no locale -> the English tables, i.e. unchanged behaviour.
const en = dateParts(d);
eq(en.weekday, "Wednesday", "fallback weekday is English");
eq(en.weekdayShort, "Wed", "fallback short weekday is English");
eq(en.month, "August", "fallback month is English");
eq(en.monthShort, "Aug", "fallback short month is English");
eq(en.dom, 5, "fallback keeps day of month");
eq(en.year, 2026, "fallback keeps year");

// with a locale: names come from the locale object, not the English tables.
// mirrors a Qt.locale(): standaloneDayName(day0Sun, fmt) / standaloneMonthName(mon0, fmt);
// format ints match the QLocale enum (0 = LongFormat, 1 = ShortFormat).
const mock = {
    standaloneDayName: (day, fmt) => "D" + day + (fmt === 1 ? "s" : "l"),
    standaloneMonthName: (mon, fmt) => "M" + mon + (fmt === 1 ? "s" : "l"),
};
const loc = dateParts(d, mock);
eq(loc.weekday, "D3l", "locale long weekday uses day index 3 (Wed) + LongFormat");
eq(loc.weekdayShort, "D3s", "locale short weekday uses ShortFormat");
eq(loc.month, "M7l", "locale long month uses month index 7 (Aug) + LongFormat");
eq(loc.monthShort, "M7s", "locale short month uses ShortFormat");
eq(loc.dom, 5, "locale path keeps day of month");
eq(loc.dow, 3, "locale path keeps the weekday index");

// clock time parts are untouched by the locale change.
eq(parts(d, true).hh, "13", "24h hour is zero-padded");
eq(parts(d, false).hh, "1", "12h hour is unpadded");
eq(parts(d, false).ampm, "PM", "afternoon resolves to PM");
eq(parts(d, true).mm, "07", "minutes are zero-padded");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
