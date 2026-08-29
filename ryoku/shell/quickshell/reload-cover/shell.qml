pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    readonly property string token: Quickshell.env("RYOKU_RELOAD_COVER_TOKEN")
    property string phase: "closing"
    property bool finishQueued: false
    property int mappedCount: 0
    property var mappedOutputs: ({})

    function mapped(name: string): void {
        if (!mappedOutputs[name]) {
            mappedOutputs[name] = true;
            mappedCount += 1;
        }
    }
    function finish(value: string): bool {
        if (value !== token || phase === "opening" || phase === "failed")
            return false;
        if (phase === "hold")
            phase = "opening";
        else
            finishQueued = true;
        return true;
    }
    function fail(value: string): void {
        if (value === token && phase !== "opening")
            phase = "failed";
    }

    Timer {
        interval: 320
        running: root.phase === "closing"
        onTriggered: {
            root.phase = "hold";
            if (root.finishQueued)
                root.phase = "opening";
        }
    }
    Timer {
        interval: 15000
        running: root.phase !== "opening" && root.phase !== "failed"
        onTriggered: root.phase = "failed"
    }
    Timer {
        interval: 390
        running: root.phase === "opening"
        onTriggered: Qt.quit()
    }

    IpcHandler {
        target: "reload-cover"
        function mapped(value: string): bool {
            return value === root.token && root.mappedCount >= Quickshell.screens.length;
        }
        function finish(value: string): bool { return root.finish(value); }
        function fail(value: string): void { root.fail(value); }
    }

    Variants {
        model: Quickshell.screens
        delegate: Component {
            ReloadCover {
                required property var modelData
                targetScreen: modelData
                phase: root.phase
                onMapped: root.mapped(targetScreen.name)
            }
        }
    }
}
