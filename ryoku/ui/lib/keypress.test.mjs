import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { addChord, releaseChords, expireChords, clampTopLeft, parseSettings } = require("./keypress.js");

// Returning a duplicate row here would turn key repeat into an unreadable flood.
test("identical recent chords collapse into a repeat count", () => {
    let rows = addChord([], ["Ctrl", "C"], false, 1000);
    rows = addChord(rows, ["Ctrl", "C"], true, 1060);
    assert.deepEqual(rows, [{ keys: ["Ctrl", "C"], count: 2, time: 1060 }]);
});

// A fourth distinct chord must evict the oldest, not the row the viewer just saw.
test("the stack retains only the three newest distinct chords", () => {
    let rows = [];
    rows = addChord(rows, ["A"], false, 100);
    rows = addChord(rows, ["B"], false, 200);
    rows = addChord(rows, ["C"], false, 300);
    rows = addChord(rows, ["D"], false, 400);
    assert.deepEqual(rows, [
        { keys: ["B"], count: 1, time: 200 },
        { keys: ["C"], count: 1, time: 300 },
        { keys: ["D"], count: 1, time: 400 }
    ]);
});

test("a later same key remains a distinct row when the stack is full", () => {
    let rows = [];
    rows = addChord(rows, ["A"], false, 100);
    rows = addChord(rows, ["B"], false, 200);
    rows = addChord(rows, ["C"], false, 300);
    rows = addChord(rows, ["C"], false, 1000);
    assert.deepEqual(rows, [
        { keys: ["B"], count: 1, time: 200 },
        { keys: ["C"], count: 1, time: 300 },
        { keys: ["C"], count: 1, time: 1000 }
    ]);
});

// The boundary is deliberate: a chord lives through the hold interval and is
// absent on the first frame at or beyond it.
test("expired chords leave the stack at the hold boundary", () => {
    const rows = [
        { keys: ["A"], count: 1, time: 1000 },
        { keys: ["B"], count: 1, time: 1500 }
    ];
    assert.deepEqual(expireChords(rows, 2799, 1800), [rows[0], rows[1]]);
    assert.deepEqual(expireChords(rows, 2800, 1800), [rows[1]]);
});

test("held chords remain until release starts their expiry clock", () => {
    const held = { keys: ["Space"], count: 1, time: 1000, held: true };
    assert.deepEqual(expireChords([held], 10000, 1800), [held]);

    const released = { ...held, time: 10000, held: false };
    assert.deepEqual(expireChords([released], 11799, 1800), [released]);
    assert.deepEqual(expireChords([released], 11800, 1800), []);
});

test("one final release lifts every matching held row", () => {
    const rows = [
        { uid: "first-a", keys: ["A"], count: 1, time: 100, held: true },
        { uid: "b", keys: ["B"], count: 1, time: 200, held: true },
        { uid: "second-a", keys: ["A"], count: 1, time: 300, held: true }
    ];
    assert.deepEqual(releaseChords(rows, ["A"], 500), [
        { uid: "first-a", keys: ["A"], count: 1, time: 500, held: false },
        rows[1],
        { uid: "second-a", keys: ["A"], count: 1, time: 500, held: false }
    ]);
});

// Dragging can never strand the visible keycaps outside their monitor.
test("placement clamps the whole stack inside the monitor padding", () => {
    assert.deepEqual(clampTopLeft(-40, 900, 300, 120, 1920, 1080, 24), { x: 24, y: 900 });
    assert.deepEqual(clampTopLeft(1900, 1070, 300, 120, 1920, 1080, 24), { x: 1596, y: 936 });
    assert.deepEqual(clampTopLeft(800, 500, 300, 120, 1920, 1080, 24), { x: 800, y: 500 });
});

test("settings parser preserves valid negative monitor coordinates", () => {
    assert.deepEqual(parseSettings(`{
        "theme": "light",
        "mode": "shortcuts",
        "px": -480,
        "py": 72,
        "monitor": "DP-1"
    }`), {
        theme: "light",
        mode: "shortcuts",
        px: -480,
        py: 72,
        monitor: "DP-1"
    });
});

test("settings parser falls back safely for missing or malformed data", () => {
    const fallback = { theme: "dark", mode: "all", px: null, py: null, monitor: "" };
    assert.deepEqual(parseSettings(""), fallback);
    assert.deepEqual(parseSettings("not json"), fallback);
    assert.deepEqual(parseSettings(`{"theme":"neon","mode":"words","px":4}`), fallback);
});
