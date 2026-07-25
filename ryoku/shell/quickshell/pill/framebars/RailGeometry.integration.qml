import QtQuick
import Quickshell
import "framebars/RailGeometry.js" as RailGeometry

ShellRoot {
    id: root

    readonly property real monitorScale: 1.3
    readonly property real frameLip: 9
    readonly property var frameBars: ({
        rails: {
            top: { enabled: true, size: 32, start: [], center: ["clock"], end: [] },
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

    function checkRail(edge) {
        const rail = findRail(scene, edge);
        const thickness = frameBars.rails[edge].size * monitorScale;
        const expected = RailGeometry.edgeRect(edge, thickness, scene.width, scene.height);
        const reserve = RailGeometry.reserve(edge, frameLip, thickness, true);
        if (!rail) {
            console.log("FAIL " + edge + " rail missing");
            return false;
        }
        const first = rail.mapToItem(scene, 0, 0);
        const last = rail.mapToItem(scene, rail.width, rail.height);
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
        }
    }

    Timer {
        interval: 50
        running: true
        onTriggered: {
            const passed = root.checkRail("top") && root.checkRail("left");
            console.log(passed ? "RAIL-GEOMETRY-PASS" : "RAIL-GEOMETRY-FAIL");
            Qt.quit();
        }
    }
}
