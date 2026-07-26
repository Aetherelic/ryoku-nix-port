pragma Singleton
import QtQuick
import "FrameBars.js" as Lib

// Frame-bar config schema: defaults, normalization and the bar-studio mutation
// helpers. Wrapped as an installed-module singleton (Ryoku.FrameBars) so every
// config root and the Hub Bar Studio reach one copy by module import, rather
// than a relative JS import that Quickshell sandboxes to the pill config root.
QtObject {
    function defaultConfig() { return Lib.defaultConfig(); }
    // barCatalog / menuCatalog are the sibling BarCatalog / MenuCatalog
    // singletons; the JS reaches entry()/anchors()/widget()/menu()/surface()
    // through them, so callers keep passing them by name.
    function normalize(raw, barCatalog, menuCatalog) { return Lib.normalize(raw, barCatalog, menuCatalog); }
    function addWidget(config, edge, zone, id, barCatalog) { return Lib.addWidget(config, edge, zone, id, barCatalog); }
    function moveWidget(config, fromEdge, fromZone, index, toEdge, toZone, targetIndex, barCatalog) { return Lib.moveWidget(config, fromEdge, fromZone, index, toEdge, toZone, targetIndex, barCatalog); }
    function removeWidget(config, edge, zone, index) { return Lib.removeWidget(config, edge, zone, index); }
    function setMenu(config, id, value, menuCatalog) { return Lib.setMenu(config, id, value, menuCatalog); }
    function setSurface(config, id, value, menuCatalog) { return Lib.setSurface(config, id, value, menuCatalog); }
}
