pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string stateRoot: (Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/store"
    readonly property string dataRoot: (Quickshell.env("XDG_DATA_HOME")
        || (Quickshell.env("HOME") + "/.local/share")) + "/ryoku/barstyles"
    property var rows: []
    property string revisionKey: ""

    function parseRows(raw) {
        try {
            const value = JSON.parse(raw || "[]");
            if (!Array.isArray(value))
                return [];
            return value.filter(row => row && /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(String(row.id || ""))
                && String(row.version || "") !== "" && String(row.scene || "") === "Scene.qml");
        } catch (e) {
            return [];
        }
    }

    function sceneUrl(id) {
        if (!id || id === "sumi")
            return "";
        for (const row of root.rows) {
            if (row.id === id)
                return "file://" + root.dataRoot + "/" + row.id + "/" + row.scene
                    + "?v=" + encodeURIComponent(row.version);
        }
        return "";
    }

    function loadRevision(raw) {
        try {
            const revision = JSON.parse(raw || "{}");
            if (revision.category !== "barstyles")
                return;
            const key = String(revision.revision || "") + ":" + String(revision.id || "");
            if (key === root.revisionKey)
                return;
            root.revisionKey = key;
            indexFile.reload();
        } catch (e) {
        }
    }

    FileView {
        id: indexFile
        path: root.stateRoot + "/barstyles.json"
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.rows = root.parseRows(text())
        onLoadFailed: root.rows = []
    }

    FileView {
        id: revisionFile
        path: root.stateRoot + "/revision.json"
        blockLoading: false
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.loadRevision(text())
    }
}
