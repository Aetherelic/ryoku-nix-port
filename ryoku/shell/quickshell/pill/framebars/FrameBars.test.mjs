import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { defaultConfig, normalize, addWidget, moveWidget, removeWidget, setMenu, setSurface } = require("../../../framebars/FrameBars.js");
const BarCatalog = require("../../../framebars/BarCatalog.js");
const MenuCatalog = require("../../../framebars/MenuCatalog.js");

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
eq(reference.rails.left.bottom, ["recording", "tray", "screenshot", "wallpaper", "clipboard", "notifications", "audio-input", "audio-output", "bluetooth", "network", "clock", "battery", "reboot"], "reference status stack is the thirteen left-bottom entries");
eq(reference.rails.right.top, [], "disabled right rail retains vertical zones");
eq(Object.keys(reference.rails.bottom).sort(), ["center", "enabled", "end", "reveal", "size", "start"], "bottom rail has horizontal zones");
eq(reference.rails.bottom.start, [], "bottom start list defaults empty");
eq(reference.rails.bottom.center, [], "bottom centre list defaults empty");
eq(reference.rails.bottom.end, [], "bottom end list defaults empty");

for (const id of ["quick-settings", "clock", "clipboard", "notifications", "screenshot", "wallpaper", "recording", "theme", "weather", "media"]) {
    eq(reference.menus[id].widgets, [id], `default ${id} menu is configured`);
}
eq(reference.menus["app-launcher"].widgets, ["launcher"], "app-launcher menu hosts the launcher widget");
eq(reference.menus["app-launcher"].anchor, "top-left", "app-launcher anchors top-left");
eq([reference.menus.clock.anchor, reference.menus.clipboard.anchor, reference.menus.notifications.anchor, reference.menus.screenshot.anchor], ["left", "left", "left", "left"], "the reference side menus all anchor left");
eq([reference.menus.wallpaper.anchor, reference.menus.wallpaper.minWidth], ["bottom-left", 1200], "wallpaper anchors bottom-left at 1200 wide");
eq(reference.menus.launcher, undefined, "the retired launcher menu id is gone");
eq(reference.menus.screenshare.widgets, [], "screenshare is placed with no config widgets");

const normalized = normalize({
    version: 99,
    style: "unknown",
    rails: {
        top: { size: 2, start: ["tray", "tray", "dock", "bad"], center: "clock", unknown: true },
        left: { enabled: "no", size: 900, top: ["clock", "clock", "bad"], center: ["dock"], bottom: 5 }
    },
    menus: { "quick-settings": { anchor: "wrong", minWidth: 1, expansion: "sometimes", widgets: ["clock", "bad"] } },
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
const renamed = normalize({ menus: { launcher: { anchor: "right", minWidth: 999 } } }, BarCatalog, MenuCatalog);
eq(renamed.menus.launcher, undefined, "normalize drops the retired launcher menu id from a stale config");
eq(renamed.menus["app-launcher"].anchor, "top-left", "normalize re-seeds app-launcher from defaults");
eq(renamed.menus.notifications.anchor, "left", "normalize re-seeds the added notifications menu");
eq(normalized.surfaces.stash.anchor, "left", "normalizer normalizes invalid surface anchor");
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
eq(moveWidget(clockDup, "left", "bottom", 10, "left", "top", 0, BarCatalog), clockDup, "move rejects an existing target-zone widget");
eq(moveWidget(reference, "left", "bottom", 0, "left", "bottom", 2, BarCatalog).rails.left.bottom, ["tray", "screenshot", "recording", "wallpaper", "clipboard", "notifications", "audio-input", "audio-output", "bluetooth", "network", "clock", "battery", "reboot"], "same-zone move honors target index");
eq(moveWidget(reference, "left", "center", 0, "top", "end", 0, BarCatalog).rails.left.center, ["dock"], "cross-axis move leaves config unchanged");

const removeInput = defaultConfig();
eq(removeWidget(removeInput, "left", "center", 0).rails.left.center, [], "remove deletes only requested occurrence");
eq(removeInput, defaultConfig(), "remove leaves its input unchanged");
eq(removeWidget(reference, "top", "center", 8).rails.top.center, [], "invalid removal leaves config unchanged");

const menuInput = defaultConfig();
eq(setMenu(menuInput, "quick-settings", { anchor: "top-right", widgets: ["clock"] }, MenuCatalog).menus["quick-settings"].anchor, "top-right", "menu updates normalize anchors");
eq(menuInput, defaultConfig(), "setMenu leaves its input unchanged");
const surfaceInput = defaultConfig();
eq(setSurface(surfaceInput, "stash", { anchor: "bad" }, MenuCatalog).surfaces.stash.anchor, "left", "surface updates normalize anchors");
eq(surfaceInput, defaultConfig(), "setSurface leaves its input unchanged");

const nestedInput = defaultConfig();
nestedInput.menus.clock.widgets = ["clock", { id: "container", widgets: ["divider"] }];
eq(normalize(nestedInput, BarCatalog, MenuCatalog).menus.clock.widgets, ["clock", { id: "container", widgets: ["divider"] }], "normalizer preserves bounded nested menu widgets");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
