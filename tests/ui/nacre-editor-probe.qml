import QtQuick
import Quickshell
import "hub/quickshell/barstudio" as BarStudio

ShellRoot {
    id: root

    property var staged: null

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

    function require(condition, label) {
        if (!condition)
            throw new Error("NACRE-EDITOR-PROBE-FAIL " + label);
    }

    Timer {
        interval: 0
        running: true
        onTriggered: {
            require(editor.islandIds.length === 3, "three islands");
            require(editor.placedCount === 10, "default placed widgets");
            require(editor.unusedCount === 2, "default unused widgets");
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
