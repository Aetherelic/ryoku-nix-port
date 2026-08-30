pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Availability and provisioning for the opt-in depth engine, plus a door to the
// cutouts in ~/Pictures/Depth. check/models/install drive the control center's
// install-to-enable flow (docs/depth.md).
Singleton {
    id: root

    // On PATH once packaged; a dev run reaches it under RYOKU_SHELL_DIR.
    readonly property string bin: {
        const d = Quickshell.env("RYOKU_SHELL_DIR");
        return (d && d.length > 0) ? d + "/scripts/ryoku-depth" : "ryoku-depth";
    }

    property bool available: false
    property bool installing: false
    property var models: []
    property string progress: ""

    function recheck() {
        checkProc.running = false;
        checkProc.running = true;
    }
    function install(model) {
        if (root.installing)
            return;
        root.installing = true;
        root.progress = "";
        installProc.command = (model && model.length > 0) ? [root.bin, "install", model] : [root.bin, "install"];
        installProc.running = false;
        installProc.running = true;
    }
    // Which curated models are already downloaded (drives the quality option).
    function hasModel(m) {
        return (root.models || []).indexOf(m) >= 0;
    }
    function openFolder() {
        openProc.running = false;
        openProc.running = true;
    }

    // "available"/"missing" on stdout avoids depending on the exit-status enum.
    Process {
        id: checkProc
        command: [root.bin, "check"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.available = ("" + this.text).trim() === "available";
                if (root.available)
                    modelsProc.running = true;
            }
        }
    }

    Process {
        id: modelsProc
        command: [root.bin, "models"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                const lines = ("" + this.text).split("\n");
                for (var i = 0; i < lines.length; i++) {
                    const t = lines[i].trim();
                    if (t.length > 0)
                        out.push(t);
                }
                root.models = out;
            }
        }
    }

    Process {
        id: installProc
        command: [root.bin, "install"]
        stdout: SplitParser {
            onRead: line => root.progress = line
        }
        stderr: SplitParser {
            onRead: line => root.progress = line
        }
        onExited: {
            root.installing = false;
            root.recheck();
        }
    }

    Process {
        id: openProc
        command: ["sh", "-c", "mkdir -p \"$HOME/Pictures/Depth\" && xdg-open \"$HOME/Pictures/Depth\""]
    }

    Component.onCompleted: root.recheck()
}
