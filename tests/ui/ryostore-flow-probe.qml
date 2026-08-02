import QtQuick
import Quickshell
import "ryostore" as Ryo
import "ryostore/Singletons" as RyoState

ShellRoot {
    id: root

    property int phase: 0
    property real savedOffset: 0
    property int attempts: 0

    Ryo.App { id: app; width: 1180; height: 760 }

    function require(condition, label) {
        if (!condition)
            throw new Error("RYOSTORE-FLOW-PROBE-FAIL " + label);
    }

    function findObject(item, name) {
        if (!item)
            return null;
        if (item.objectName === name)
            return item;
        const children = item.children || [];
        for (const child of children) {
            const found = root.findObject(child, name);
            if (found)
                return found;
        }
        return null;
    }

    function item(id) {
        for (const candidate of RyoState.Store.items)
            if (candidate.id === id)
                return candidate;
        return null;
    }

    Timer {
        interval: 50
        repeat: true
        running: true
        onTriggered: {
            root.attempts++;
            if (root.attempts > 300)
                throw new Error("RYOSTORE-FLOW-PROBE-FAIL timed out in phase " + root.phase);

            if (root.phase === 0) {
                if (RyoState.Store.items.length < 10)
                    return;
                app.openRoute("lockscreens");
                app.selectKey("lockscreens:clock");
                root.require(app.categoryID === "lockscreens", "category deep link");
                root.require(app.selectedKey === "lockscreens:clock", "stable keyed selection");
                app.openSelectedDetail();
                root.phase = 1;
                return;
            }

            if (root.phase === 1) {
                if (!root.findObject(app, "ryostore-detail") || !app.detailItem)
                    return;
                RyoState.Store.install(app.detailItem);
                root.phase = 2;
                return;
            }

            if (root.phase === 2) {
                const installed = root.item("clock");
                if (!installed || !installed.installed || RyoState.Store.busyKey !== "")
                    return;
                root.require(installed.active === false, "install did not activate");
                root.require(app.detailItem.installed === true, "detail refreshed from backend");
                app.closeDetail();
                root.require(app.selectedKey === "lockscreens:clock", "detail restored selection");
                root.savedOffset = app.filmstripOffset;
                app.openSearch();
                app.setQuery("installed clock");
                root.require(app.collection.length === 1, "showroom search projection");
                root.require(app.selectedKey === "lockscreens:clock", "search retained matching selection");
                app.openSelectedDetail();
                root.phase = 3;
                return;
            }

            if (root.phase === 3) {
                if (!app.detailOpen)
                    return;
                app.escapeLayer();
                root.require(app.searchOpen && app.query === "installed clock", "detail returns to search layer");
                app.escapeLayer();
                root.require(!app.searchOpen, "search layer closed");
                root.require(app.categoryID === "lockscreens" && app.selectedKey === "lockscreens:clock",
                             "search restored exact context");
                root.require(Math.abs(app.filmstripOffset - root.savedOffset) < 0.5,
                             "search restored filmstrip offset");
                console.log("RYOSTORE-FLOW-PROBE-PASS");
                Qt.quit();
            }
        }
    }
}
