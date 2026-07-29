import QtQuick
import Quickshell
import "hub/quickshell/barstudio" as BarStudio

ShellRoot {
    id: root

    property var staged: null
    property var labelFor: id => id === "activeWindow" ? "Active window"
        : id === "connectivity" ? "Connections"
        : id === "utils" ? "Recording" : id

    BarStudio.NacreEditor {
        id: editor
        width: 900
        config: ({
            islands: {
                left: ["brand", "media", "activeWindow"],
                center: ["clock", "workspaces", "resources"],
                right: ["connectivity", "audio", "battery", "tray"]
            },
            height: 40,
            opacity: 0.82,
            padding: 12,
            spacing: 8,
            islandGap: 14,
            occupiedWorkspaces: true
        })
        onStaged: value => root.staged = value
    }

    BarStudio.NacreIslandLane {
        id: sparseLane
        width: 260
        islandId: "left"
        items: ["brand"]
        labelFor: root.labelFor
    }

    BarStudio.NacreIslandLane {
        id: crowdedLane
        width: 260
        islandId: "right"
        items: ["media", "brand", "utils", "weather", "activeWindow"]
        labelFor: root.labelFor
    }

    BarStudio.NacreWidgetChip {
        id: longChip
        widgetId: "activeWindow"
        label: "An extremely long widget name"
        sourceIsland: "left"
        sourceIndex: 0
    }

    function require(condition, label) {
        if (!condition)
            throw new Error("NACRE-EDITOR-PROBE-FAIL " + label);
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

    Timer {
        interval: 0
        running: true
        onTriggered: {
            require(editor.islandIds.length === 3, "three islands");
            require(editor.placedCount === 10, "default placed widgets");
            require(editor.unusedCount === 2, "default unused widgets");
            const left = root.findObject(editor, "nacre-island-left");
            const center = root.findObject(editor, "nacre-island-center");
            const right = root.findObject(editor, "nacre-island-right");
            require(left && center && right, "island lanes");
            require(left.width === editor.width && center.width === editor.width
                && right.width === editor.width, "full width lanes");
            require(left.y < center.y && center.y < right.y, "stacked lanes");
            require(crowdedLane.height > sparseLane.height, "wrapped lane grows");
            require(longChip.width <= 144, "long chip capped");
            editor.moveWidget("brand", "left", "right", 1);
            require(root.staged.islands.left.length === 2, "drag removes source");
            require(root.staged.islands.right[1] === "brand", "drag inserts target");
            editor.config = root.staged;
            editor.setAppearance("height", 48);
            require(root.staged.height === 48, "appearance stages");
            console.log("NACRE-EDITOR-PROBE-PASS");
            Qt.quit();
        }
    }
}
