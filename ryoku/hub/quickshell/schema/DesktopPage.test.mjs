import fs from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";
import test from "node:test";

const source = fs.readFileSync(new URL("./DesktopPage.js", import.meta.url), "utf8").replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);
const rows = context.rows;

test("reload cover is a brand-backed General setting after Brand", () => {
    const index = rows.findIndex(row => row.key === "reloadCover");
    assert.ok(index >= 0);
    assert.deepEqual(JSON.parse(JSON.stringify(rows[index])), {
        tab: "General",
        group: "SHELL RELOAD",
        key: "reloadCover",
        label: "Reload cover",
        desc: "Shown while the desktop shell restarts; media is fitted without cropping and video is always muted",
        ctl: "reload-cover",
        src: "brand"
    });
    assert.equal(rows[index - 1].key, "markTint");
    assert.equal(rows[index + 1].tab, "Visualizer");
});
