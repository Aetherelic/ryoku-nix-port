pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../framebars/lib/providers.js" as Providers

Singleton {
    id: root

    property string profile: ""
    property bool available: false
    property var profiles: []
    property bool active: false


    function setActive(enabled) {
        active = enabled;
        if (active) refresh();
        else {
            readProc.running = false;
            setProc.running = false;
        }
    }

    function refresh() {
        if (active) readProc.running = true;
    }

    function setProfile(name) {
        if (!active || typeof name !== "string" || !profiles.includes(name)) return;
        setProc.command = ["powerprofilesctl", "set", name];
        setProc.running = true;
    }

    Process {
        id: readProc
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null; printf '\n--\n'; powerprofilesctl list 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("\n--\n");
                const profiles = Providers.parseProfiles(parts[1]);
                root.profiles = profiles;
                root.available = profiles.length > 0;
                const profile = (parts[0] || "").trim();
                root.profile = profiles.includes(profile) ? profile : "";
            }
        }
    }

    Process {
        id: setProc
        onExited: root.refresh()
    }
}
