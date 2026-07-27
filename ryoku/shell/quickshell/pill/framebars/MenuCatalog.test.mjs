import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const MenuCatalog = require("../../../framebars/MenuCatalog.js");

let failed = 0;
function eq(actual, expected, msg) {
    const a = JSON.stringify(actual);
    const e = JSON.stringify(expected);
    if (a === e) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg + "\n  expected " + e + "\n  got      " + a); }
}
function ok(condition, msg) { eq(!!condition, true, msg); }

const requiredMenuWidgets = [
    "audio-input", "audio-output", "bluetooth", "clipboard", "clock",
    "container", "divider", "spacer", "network", "notifications", "power-profile",
    "quick-settings", "screenshot", "recording", "theme", "wallpaper", "weather", "media",
    "layout-switcher", "quick-actions"
];
eq(MenuCatalog.widgetIds().sort(), requiredMenuWidgets.sort(), "all approved menu widgets are catalogued");
eq(MenuCatalog.anchors().sort(), ["bottom", "bottom-left", "bottom-right", "left", "right", "top", "top-left", "top-right"].sort(), "all frame anchors exist");
ok(MenuCatalog.surface("stash").panes.includes("stash"), "stash is a registered frame surface");
ok(MenuCatalog.menu("quick-settings").widgets.includes("quick-settings"), "quick settings is one cohesive stack widget");
eq(MenuCatalog.menu("clock"), null, "the clock menu is retired; the clock widget opens quick settings");
eq(MenuCatalog.menu("notifications"), null, "the notifications menu is retired; the bell opens the quick-settings notifications page");
eq(MenuCatalog.menu("clipboard"), null, "the clipboard menu is retired; the clipboard button opens the quick-settings clipboard page");
eq(MenuCatalog.menu("media"), null, "the media menu is retired; media lives in the quick-settings sidebar");
ok(MenuCatalog.widget("container").nested, "container accepts child widget lists");
ok(MenuCatalog.quickAction("lock").action === "lock", "quick action routes are fixed identifiers");
eq(MenuCatalog.quickActionIds().sort(), ["lock", "logout", "reboot", "shutdown", "lens", "color", "ocr", "qr", "mirror", "clipboard", "wifi", "bluetooth", "microphone", "do-not-disturb", "night-light", "keep-awake", "game-mode"].sort(), "all source control centre actions are fixed");
eq(MenuCatalog.menu("missing"), null, "unknown menus have no catalog entry");
eq(MenuCatalog.surface("missing"), null, "unknown surfaces have no catalog entry");

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
