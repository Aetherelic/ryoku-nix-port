import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const Model = require("./BarStudioModel.js");
const FrameBars = require("../../../shell/quickshell/pill/framebars/FrameBars.js");
const BarCatalog = require("../../../shell/quickshell/pill/framebars/BarCatalog.js");
const MenuCatalog = require("../../../shell/quickshell/pill/framebars/MenuCatalog.js");

let failed = 0;
function ok(value, message) {
    if (!value) {
        console.error(`FAIL: ${message}`);
        failed++;
    }
}
function eq(actual, expected, message) {
    ok(JSON.stringify(actual) === JSON.stringify(expected), `${message}; got ${JSON.stringify(actual)}, want ${JSON.stringify(expected)}`);
}
function fresh(before, after, message) {
    ok(before !== after, `${message} returns a fresh root`);
}

const base = FrameBars.defaultConfig();
const added = Model.addZoneItem(base, "top", "start", "battery", BarCatalog);
fresh(base, added, "add zone item");
eq(base.rails.top.start, [], "add leaves source zone unchanged");
eq(added.rails.top.start, ["battery"], "add places compatible widget in zone");

const moved = Model.moveZoneItem(base, "left", "top", 0, "top", "end", 0, BarCatalog);
fresh(base, moved, "move zone item");
eq(base.rails.left.top[0], "quick-settings", "move leaves source draft untouched");
eq(moved.rails.top.end[0], "quick-settings", "move transfers widget across zones");

const lowered = Model.moveZoneItem(added, "top", "start", 0, "top", "start", 1, BarCatalog);
fresh(added, lowered, "move within zone");
eq(lowered.rails.top.start, ["battery"], "move limits preserve list boundaries");

const removed = Model.removeZoneItem(moved, "top", "end", 0);
fresh(moved, removed, "remove zone item");
eq(moved.rails.top.end, ["quick-settings"], "remove leaves source list unchanged");
eq(removed.rails.top.end, [], "remove deletes selected item");

const rejected = Model.moveZoneItem(base, "left", "center", 0, "top", "start", 0, BarCatalog);
fresh(base, rejected, "reject incompatible zone move");
eq(rejected, base, "incompatible vertical-only widget move is a clean no-op");

const menuCreated = Model.createMenu(base, "clock", MenuCatalog);
fresh(base, menuCreated, "create menu");
eq(menuCreated.menus.clock.widgets, ["clock"], "menu creation uses bounded catalogue record");
const menuAnchored = Model.setMenuAnchor(menuCreated, "clock", "bottom-right", MenuCatalog);
fresh(menuCreated, menuAnchored, "set menu anchor");
eq(menuCreated.menus.clock.anchor, "top", "anchor update leaves source untouched");
eq(menuAnchored.menus.clock.anchor, "bottom-right", "anchor update accepts catalogue anchor");

const nestedMenu = Model.addMenuWidget(menuAnchored, "clock", [], "container", MenuCatalog);
const nestedAdded = Model.addMenuWidget(nestedMenu, "clock", [1, "widgets"], "divider", MenuCatalog);
fresh(nestedMenu, nestedAdded, "add nested menu widget");
eq(nestedAdded.menus.clock.widgets, ["clock", { id: "container", widgets: ["divider"] }], "nested widget is added to bounded container");
const nestedMoved = Model.moveMenuWidget(nestedAdded, "clock", [], 1, [], 0, MenuCatalog);
fresh(nestedAdded, nestedMoved, "move nested menu widget");
eq(nestedMoved.menus.clock.widgets, [{ id: "container", widgets: ["divider"] }, "clock"], "nested widget move reorders children");
const nestedRemoved = Model.removeMenuWidget(nestedMoved, "clock", [0, "widgets"], 0, MenuCatalog);
fresh(nestedMoved, nestedRemoved, "remove nested menu widget");
eq(nestedRemoved.menus.clock.widgets[0].widgets, [], "nested widget removal updates children");
eq(nestedMenu.menus.clock.widgets, ["clock", { id: "container", widgets: [] }], "nested operations leave source menu unchanged");

const nestedMoveSource = Model.createMenu(base, "clock", MenuCatalog);
nestedMoveSource.menus.clock.widgets = [{ id: "container", widgets: [{ id: "container", widgets: ["divider"] }] }];
const directDescendantRejected = Model.moveMenuWidget(nestedMoveSource, "clock", [], 0, [0, "widgets"], 0, MenuCatalog);
fresh(nestedMoveSource, directDescendantRejected, "reject direct descendant menu move");
eq(directDescendantRejected, nestedMoveSource, "direct descendant move preserves the normalized root");
eq(nestedMoveSource.menus.clock.widgets, [{ id: "container", widgets: [{ id: "container", widgets: ["divider"] }] }], "direct descendant move leaves source root intact");
const deepDescendantRejected = Model.moveMenuWidget(nestedMoveSource, "clock", [], 0, [0, "widgets", 0, "widgets"], 0, MenuCatalog);
fresh(nestedMoveSource, deepDescendantRejected, "reject deep descendant menu move");
eq(deepDescendantRejected, nestedMoveSource, "deep descendant move preserves the normalized root");
eq(nestedMoveSource.menus.clock.widgets[0].widgets[0].widgets, ["divider"], "deep descendant move leaves source descendants intact");

if (failed > 0) {
    console.error(`\n${failed} test(s) FAILED`);
    process.exit(1);
}
console.log("\nAll tests PASSED");
