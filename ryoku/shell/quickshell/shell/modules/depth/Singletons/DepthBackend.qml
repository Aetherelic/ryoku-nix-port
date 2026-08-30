pragma ComponentBehavior: Bound
pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Availability + provisioning for the opt-in depth engine. The base ships the
// UI and the ryoku-depth helper but not the model runtime; this runs
// `ryoku-depth check` to learn whether the engine is installed, `models` to know
// which cutout models are usable, and `install` to provision the runtime on
// first enable. The control center binds to `available`/`installing` to swap
// between the normal controls and an "install to enable" action.
Singleton {
    id: root

    // Resolve the helper the way the daemon does: a dev run points
    // RYOKU_SHELL_DIR at the shell tree where the script is not on PATH; a
    // packaged install ships it to /usr/bin, where the bare name resolves.
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
    function install() {
        if (root.installing)
            return;
        root.installing = true;
        root.progress = "";
        installProc.running = false;
        installProc.running = true;
    }

    // `check` prints "available" or "missing"; reading stdout avoids depending on
    // the exit-status enum and matches the shell's other Process users.
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

    Component.onCompleted: root.recheck()
}
