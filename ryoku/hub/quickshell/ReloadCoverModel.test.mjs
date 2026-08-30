import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const Model = require("./ReloadCoverModel.js");

test("empty descriptor is the shipped default", () => {
    assert.deepEqual(Model.empty(), { path: "", name: "", kind: "default", bytes: 0 });
});

test("normalization preserves a valid imported descriptor", () => {
    assert.deepEqual(Model.normalize({ path: "/data/a.mp4", name: "a.mp4", kind: "video", bytes: 14873124 }), {
        path: "/data/a.mp4", name: "a.mp4", kind: "video", bytes: 14873124
    });
});

test("normalization rejects incomplete or unknown descriptors", () => {
    assert.deepEqual(Model.normalize(null), Model.empty());
    assert.deepEqual(Model.normalize({ path: "/data/a.bin", name: "a.bin", kind: "binary", bytes: 5 }), Model.empty());
    assert.deepEqual(Model.normalize({ path: "", name: "stale.mp4", kind: "video", bytes: 9 }), Model.empty());
});

test("path returns only a normalized managed asset path", () => {
    assert.equal(Model.path({ path: "/data/a.mp4", kind: "video" }), "/data/a.mp4");
    assert.equal(Model.path({ path: "/data/a.bin", kind: "binary" }), "");
});

test("formatBytes gives compact decimal user-facing sizes", () => {
    assert.equal(Model.formatBytes(0), "");
    assert.equal(Model.formatBytes(999999), "1000 KB");
    assert.equal(Model.formatBytes(14873124), "14.9 MB");
});

test("filters include lower and uppercase media suffixes", () => {
    const filters = Model.filters();
    assert.ok(filters.includes("*.png"));
    assert.ok(filters.includes("*.PNG"));
    assert.ok(filters.includes("*.mp4"));
    assert.ok(filters.includes("*.MP4"));
});

test("renderer source uses the materialized path unless shell dir is nonempty", () => {
    const materialized = "file:///config/quickshell/reload-cover/ReloadMedia.qml";
    assert.equal(Model.rendererSource(null, "/config", "/home/nero"), materialized);
    assert.equal(Model.rendererSource(undefined, "/config", "/home/nero"), materialized);
    assert.equal(Model.rendererSource("", "/config", "/home/nero"), materialized);
    assert.equal(Model.rendererSource("/work/ryoku/shell", "/config", "/home/nero"),
        "file:///work/ryoku/shell/quickshell/reload-cover/ReloadMedia.qml");
});
