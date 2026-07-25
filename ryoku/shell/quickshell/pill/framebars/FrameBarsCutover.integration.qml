import QtQuick
import Quickshell
import "__RYOWALLS_DIR__" as Ryowalls

ShellRoot {
    id: root

    readonly property string expectedStyle: Quickshell.env("CUTOVER_STYLE")
    readonly property string expectedLayout: Quickshell.env("CUTOVER_LAYOUT")

    function previewRails(item, result) {
        if (item.rail !== undefined && item.modelData !== undefined)
            result.push(item);
        for (let i = 0; i < item.children.length; ++i)
            previewRails(item.children[i], result);
    }

    function rectFor(item, parent) {
        const first = item.mapToItem(parent, 0, 0);
        const last = item.mapToItem(parent, item.width, item.height);
        return {
            x: Math.round(Math.min(first.x, last.x) * 100) / 100,
            y: Math.round(Math.min(first.y, last.y) * 100) / 100,
            width: Math.round(Math.abs(last.x - first.x) * 100) / 100,
            height: Math.round(Math.abs(last.y - first.y) * 100) / 100
        };
    }

    function expectedRect(edge, thickness) {
        if (edge === "top") return { x: 0, y: 0, width: preview.width, height: thickness };
        if (edge === "bottom") return { x: 0, y: preview.height - thickness, width: preview.width, height: thickness };
        if (edge === "left") return { x: 0, y: 0, width: thickness, height: preview.height };
        return { x: preview.width - thickness, y: 0, width: thickness, height: preview.height };
    }

    function sameRect(actual, expected) {
        return Math.abs(actual.x - expected.x) < 0.01 && Math.abs(actual.y - expected.y) < 0.01
            && Math.abs(actual.width - expected.width) < 0.01 && Math.abs(actual.height - expected.height) < 0.01;
    }

    Item {
        id: preview
        width: 600
        height: 400

        Ryowalls.MockDesktop {
            anchors.fill: parent
        }
    }

    Timer {
        interval: 250
        running: true
        onTriggered: {
            const config = preview.children[0].frameBars;
            const rails = [];
            root.previewRails(preview, rails);
            const expectedEdges = root.expectedLayout === "top-left" ? ["top", "left"] : ["bottom", "right"];
            const actualEdges = rails.filter(item => item.visible).map(item => item.modelData).sort();
            let valid = config.style === root.expectedStyle
                && JSON.stringify(actualEdges) === JSON.stringify(expectedEdges.slice().sort());
            const geometry = {};
            for (let i = 0; i < rails.length; ++i) {
                const rail = rails[i];
                if (!rail.visible) continue;
                const thickness = rail.rail.size * preview.children[0].s;
                const actual = root.rectFor(rail, preview);
                geometry[rail.modelData] = actual;
                valid = valid && root.sameRect(actual, root.expectedRect(rail.modelData, thickness));
            }
            const alpha = Math.round(preview.children[0].railMaterial().a * 100) / 100;
            console.log("FRAME-BARS-CUTOVER-GEOMETRY " + root.expectedLayout + " " + JSON.stringify(geometry));
            console.log("FRAME-BARS-CUTOVER-MATERIAL " + root.expectedStyle + " " + alpha);
            console.log(valid ? "FRAME-BARS-CUTOVER-PASS" : "FRAME-BARS-CUTOVER-FAIL");
            Qt.quit();
        }
    }
}
