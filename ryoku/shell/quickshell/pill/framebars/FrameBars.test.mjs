import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { defaultConfig: frameBarDefaults, normalize, addWidget, moveWidget, removeWidget, setMenu, setSurface } = require("../../../framebars/FrameBars.js");
const BarCatalog = require("../../../framebars/BarCatalog.js");
const MenuCatalog = require("../../../framebars/MenuCatalog.js");
function defaultConfig() { return frameBarDefaults(MenuCatalog); }

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}

const reference = defaultConfig();
eq(reference.rails.top.center, [], "reference top bar is empty");
eq(reference.rails.left.top, ["quick-settings", "workspaces"], "reference left top zone is quick settings then workspaces");
eq(reference.rails.left.center, ["dock"], "reference dock is left-centre");
eq(reference.rails.bottom.enabled, false, "bottom rail starts disabled");
eq(reference.rails.left.bottom, ["recording", "tray", "audio-input", "audio-output", "bluetooth", "network", "clock", "battery"], "reference status stack is the eight left-bottom entries (reboot, notifications, clipboard, screenshot and wallpaper removed; surfaces stay on keybinds)");
eq(reference.rails.right.top, [], "disabled right rail retains vertical zones");
eq(Object.keys(reference.rails.bottom).sort(), ["center", "enabled", "end", "reveal", "size", "start"], "bottom rail has horizontal zones");
eq(reference.rails.bottom.start, [], "bottom start list defaults empty");
eq(reference.rails.bottom.center, [], "bottom centre list defaults empty");
eq(reference.rails.bottom.end, [], "bottom end list defaults empty");

for (const id of ["quick-settings", "theme", "weather"]) {
    eq(reference.menus[id].widgets, [id], `default ${id} menu is configured`);
}
eq(reference.menus["quick-settings"].modules, ["home", "notifications", "weather"], "quick settings defaults to the current three visible modules");
eq(reference.surfaces.system, undefined, "the legacy system sidebar is absent from the default schema");
eq(reference.menus["app-launcher"], undefined, "the app launcher is Ryoku's own surface, not a frame menu");
eq([reference.menus["quick-settings"].anchor, reference.menus.screenshare.anchor], ["left", "left"], "the reference left menus anchor left");
eq([reference.menus.wallpaper.anchor, reference.menus.wallpaper.minWidth], ["bottom", 1400], "wallpaper anchors bottom-centre at 1400 wide");
eq(reference.menus.wallpaper.widgets, ["theme", "wallpaper"], "wallpaper menu nests the theme picker above the grid");
eq(reference.menus.launcher, undefined, "the retired launcher menu id is gone");
eq(reference.menus.clock, undefined, "the retired clock menu is gone; the clock widget opens quick settings");
eq(reference.menus.notifications, undefined, "the retired notifications menu is gone; the bell opens the quick-settings notifications page");
eq(reference.menus.clipboard, undefined, "the retired clipboard menu is gone; the clipboard button opens the quick-settings clipboard page");
eq(reference.menus.media, undefined, "the retired media menu is gone; media lives in the quick-settings sidebar");
eq(reference.menus.screenshot, undefined, "the retired screenshot menu is gone; capture moved to the floating card");
eq(reference.menus.recording, undefined, "the retired recording menu is gone; capture moved to the floating card");
eq(reference.menus.screenshare.widgets, [], "screenshare is placed with no config widgets");

const normalized = normalize({
    version: 99,
    style: "unknown",
    rails: {
        top: { size: 2, start: ["tray", "tray", "dock", "bad"], center: "clock", unknown: true },
        left: { enabled: "no", size: 900, top: ["clock", "clock", "bad"], center: ["dock"], bottom: 5 }
    },
    menus: { "quick-settings": { anchor: "wrong", minWidth: 1, expansion: "sometimes", widgets: ["clock", "bad"], modules: ["media", "bad", "media", "home"] } },
    surfaces: { stash: { anchor: "bad", minWidth: 9999, panes: ["stash", "bad"] } },
    dock: { pinned: ["firefox", 4] },
    arbitrary: true
}, BarCatalog, MenuCatalog);
eq(normalized.style, "slate-frame", "normalizer resets invalid style");
eq(normalized.rails.top.size, 16, "normalizer clamps horizontal size");
eq(normalized.rails.left.size, 112, "normalizer clamps vertical size");
eq(normalized.rails.left.top, ["clock"], "normalizer drops duplicate and unknown identifiers");
eq(normalized.rails.left.bottom, defaultConfig().rails.left.bottom, "normalizer restores a malformed zone to its default");
eq(normalized.menus["quick-settings"].anchor, "left", "normalizer restores invalid menu anchor");
eq(normalized.menus["quick-settings"].widgets, ["quick-settings"], "normalize pins quick-settings to its fixed cohesive stack");
eq(normalized.menus["quick-settings"].modules, ["media", "home"], "normalize keeps known quick-settings modules in requested order and drops duplicates");
eq(normalized.surfaces.system, undefined, "normalize never restores the retired system sidebar");
const renamed = normalize({ menus: { launcher: { anchor: "right", minWidth: 999 }, "app-launcher": { anchor: "right", minWidth: 999 } } }, BarCatalog, MenuCatalog);
eq(renamed.menus.launcher, undefined, "normalize drops the retired launcher menu id from a stale config");
eq(renamed.menus["app-launcher"], undefined, "normalize drops the retired app-launcher menu id from a stale config");
eq(renamed.menus.notifications, undefined, "the retired notifications menu never returns from normalize");
eq(normalized.surfaces.stash.anchor, "right", "normalizer normalizes invalid surface anchor");
eq(normalized.arbitrary, undefined, "normalizer drops arbitrary keys");

const addInput = defaultConfig();
const added = addWidget(addInput, "left", "top", "vpn", BarCatalog);
eq(added.rails.left.top, ["quick-settings", "workspaces", "vpn"], "compatible widget appends to an occupied zone");
eq(addInput, defaultConfig(), "add leaves its input unchanged");
eq(addWidget(reference, "top", "start", "tray", BarCatalog).rails.top.start, ["tray"], "compatible top widget is added");
eq(addWidget(reference, "top", "start", "dock", BarCatalog).rails.top.start, [], "cross-axis widget is rejected");

const moveInput = defaultConfig();
const moved = moveWidget(moveInput, "left", "top", 0, "top", "end", 0, BarCatalog);
eq(moved.rails.top.end, ["quick-settings"], "widget moves across compatible rails");
eq(moved.rails.left.top, ["workspaces"], "successful move removes only the source widget");
eq(moveInput, defaultConfig(), "move leaves its input unchanged");
const clockDup = addWidget(reference, "left", "top", "clock", BarCatalog);
eq(moveWidget(clockDup, "left", "bottom", 6, "left", "top", 0, BarCatalog), clockDup, "move rejects an existing target-zone widget");
eq(moveWidget(reference, "left", "bottom", 0, "left", "bottom", 2, BarCatalog).rails.left.bottom, ["tray", "audio-input", "recording", "audio-output", "bluetooth", "network", "clock", "battery"], "same-zone move honors target index");
eq(moveWidget(reference, "left", "center", 0, "top", "end", 0, BarCatalog).rails.left.center, ["dock"], "cross-axis move leaves config unchanged");

const removeInput = defaultConfig();
eq(removeWidget(removeInput, "left", "center", 0).rails.left.center, [], "remove deletes only requested occurrence");
eq(removeInput, defaultConfig(), "remove leaves its input unchanged");
eq(removeWidget(reference, "top", "center", 8).rails.top.center, [], "invalid removal leaves config unchanged");

const menuInput = defaultConfig();
eq(setMenu(menuInput, "quick-settings", { anchor: "top-right", widgets: ["clock"] }, MenuCatalog).menus["quick-settings"].anchor, "top-right", "menu updates normalize anchors");
eq(menuInput, defaultConfig(), "setMenu leaves its input unchanged");
const surfaceInput = defaultConfig();
eq(setSurface(surfaceInput, "stash", { anchor: "bad" }, MenuCatalog).surfaces.stash.anchor, "right", "surface updates normalize anchors");
eq(surfaceInput, defaultConfig(), "setSurface leaves its input unchanged");

const nestedInput = defaultConfig();
nestedInput.menus.weather.widgets = ["clock", { id: "container", widgets: ["divider"] }];
eq(normalize(nestedInput, BarCatalog, MenuCatalog).menus.weather.widgets, ["clock", { id: "container", widgets: ["divider"] }], "normalizer preserves bounded nested menu widgets");

// normalize completes a partial config: any absent top-level subtree is restored
// from the schema default, so a reader that goes through normalize never sees a
// missing menus/surfaces/dock and never perpetuates a dropped subtree.
const completed = normalize({ rails: { left: { size: 64 } } }, BarCatalog, MenuCatalog);
for (const key of ["version", "style", "rails", "menus", "surfaces", "dock"]) eq(completed[key] !== undefined, true, `normalize restores the ${key} subtree from a partial config`);
eq(Object.keys(completed.menus).length > 0, true, "normalize restores the menus map from a config that omitted it");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
