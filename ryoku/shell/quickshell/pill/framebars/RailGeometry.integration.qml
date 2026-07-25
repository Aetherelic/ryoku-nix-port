import QtQuick
import Quickshell
import "framebars/RailGeometry.js" as RailGeometry

ShellRoot {
    id: root

    readonly property real monitorScale: 1.3
    readonly property real frameLip: 9
    readonly property var frameBars: ({
        style: "ok-frame",
        rails: {
            top: { enabled: true, size: 32, start: ["lock"], center: ["clock"], end: [] },
            left: { enabled: true, size: 48, top: ["quick-settings", "workspaces"], center: ["dock"], bottom: ["tray", "network", "clock"] },
            bottom: { enabled: false, size: 32, start: [], center: [], end: [] },
            right: { enabled: false, size: 48, top: [], center: [], bottom: [] }
        },
        menus: {},
        surfaces: {}
    })

    function findRail(item, edge) {
        if (item.edge === edge && item.rail !== undefined)
            return item;
        for (let i = 0; i < item.children.length; i++) {
            const result = findRail(item.children[i], edge);
            if (result)
                return result;
        }
        return null;
    }

    function closeEnough(actual, expected) {
        return Math.abs(actual - expected) < 0.01;
    }

    function checkRail(sceneItem, bars, edge) {
        const rail = findRail(sceneItem, edge);
        const thickness = bars.rails[edge].size * monitorScale;
        const expected = RailGeometry.edgeRect(edge, thickness, sceneItem.width, sceneItem.height);
        const reserve = RailGeometry.reserve(edge, frameLip, thickness, true);
        if (!rail) {
            console.log("FAIL " + edge + " rail missing");
            return false;
        }
        const first = rail.mapToItem(sceneItem, 0, 0);
        const last = rail.mapToItem(sceneItem, rail.width, rail.height);
        const actual = {
            x: Math.min(first.x, last.x),
            y: Math.min(first.y, last.y),
            width: Math.abs(last.x - first.x),
            height: Math.abs(last.y - first.y)
        };
        const matches = closeEnough(actual.x, expected.x)
            && closeEnough(actual.y, expected.y)
            && closeEnough(actual.width, expected.width)
            && closeEnough(actual.height, expected.height)
            && closeEnough(reserve, frameLip + (edge === "top" || edge === "bottom" ? actual.height : actual.width));
        console.log((matches ? "PASS " : "FAIL ") + edge + " chrome=" + JSON.stringify(actual)
            + " mask=" + JSON.stringify(expected) + " reserve=" + reserve);
        return matches;
    }
    function hosts(item, result) {
        if (item.widgetId !== undefined && item.widgetId.length > 0) result.push(item);
        for (let i = 0; i < item.children.length; ++i) hosts(item.children[i], result);
    }

    Item {
        id: scene
        width: 1920
        height: 1080

        Bar {
            id: bar
            anchors.fill: parent
            railScale: root.monitorScale
            frameBars: root.frameBars
            style: ({ group: null })
            property var menus: []
            property var actions: []
            onMenuRequested: (id, ownerRect) => menus.push({ id: id, rect: ownerRect })
            onActionRequested: id => actions.push(id)
        }
    }
    Item {
        id: bottomRightScene
        width: 1920
        height: 1080
        visible: false

        readonly property var frameBars: ({
            style: "ryoku-frame",
            rails: {
                top: { enabled: false, size: 32, start: [], center: [], end: [] },
                left: { enabled: false, size: 48, top: [], center: [], bottom: [] },
                bottom: { enabled: true, size: 32, start: ["lock"], center: ["clock"], end: [] },
                right: { enabled: true, size: 48, top: ["quick-settings", "workspaces"], center: ["dock"], bottom: ["tray", "network", "clock"] }
            },
            menus: {},
            surfaces: {}
        })

        Bar {
            anchors.fill: parent
            railScale: root.monitorScale
            frameBars: parent.frameBars
            style: ({ group: null })
        }
    }

    Timer {
        interval: 50
        running: true
        onTriggered: {
            const passed = root.checkRail(scene, root.frameBars, "top")
                && root.checkRail(scene, root.frameBars, "left")
                && root.checkRail(bottomRightScene, bottomRightScene.frameBars, "bottom")
                && root.checkRail(bottomRightScene, bottomRightScene.frameBars, "right");
            const allHosts = [];
            root.hosts(scene, allHosts);
            const expected = ["clock", "dock", "lock", "network", "quick-settings", "tray", "workspaces"];
            const resolved = expected.every(id => allHosts.some(host => host.widgetId === id && host.loaded));
            const origins = {};
            const emit = (id, signal) => {
                const host = allHosts.find(candidate => candidate.widgetId === id);
                const widgetLoader = host.children.find(child => child.item !== undefined);
                const item = widgetLoader.item;
                if (signal === "actionRequested") item[signal](id);
                else {
                    const point = item.mapToGlobal(0, 0);
                    origins[id] = { x: point.x, y: point.y };
                    item[signal](id, Qt.rect(0, 0, 1, 1));
                }
            };
            emit("clock", "menuRequested");
            emit("quick-settings", "menuRequested");
            emit("dock", "menuRequested");
            emit("tray", "menuRequested");
            emit("lock", "actionRequested");
            const menuIds = bar.menus.map(entry => entry.id).sort();
            const menus = JSON.stringify(menuIds) === JSON.stringify(["clock", "dock", "quick-settings", "tray"]);
            const rectangles = bar.menus.every(entry => entry.rect.width === 1 && entry.rect.height === 1
                && entry.rect.x === origins[entry.id].x && entry.rect.y === origins[entry.id].y);
            const actions = JSON.stringify(bar.actions) === JSON.stringify(["lock"]);
            console.log(resolved && menus && rectangles && actions ? "FRAME-BAR-CONTRACT-PASS" : "FRAME-BAR-CONTRACT-FAIL");
            console.log(passed ? "RAIL-GEOMETRY-PASS" : "RAIL-GEOMETRY-FAIL");
            Qt.quit();
        }
    }
}
