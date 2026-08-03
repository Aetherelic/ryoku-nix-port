pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var catalog: ({})
    property var categories: []
    property var items: []
    property bool loading: false
    property bool offline: false
    property string generatedAt: ""
    readonly property bool refreshing: loading && items.length > 0
    property string error: ""
    property string busyKey: ""
    property string installStage: ""
    property string installError: ""
    property string installErrorKey: ""
    property string _catalogOutput: ""
    property string _catalogError: ""
    property string _installError: ""
    property bool _clearBusyAfterRefresh: false

    function itemKey(item) {
        return item ? String(item.category || "") + ":" + String(item.id || "") : "";
    }

    function category(id) {
        for (let i = 0; i < categories.length; i++)
            if (categories[i].id === id)
                return categories[i];
        return null;
    }

    function refresh(force) {
        if (catalogProc.running)
            return;
        loading = true;
        error = "";
        _catalogOutput = "";
        _catalogError = "";
        catalogProc.command = force ? ["ryostore", "catalog", "--refresh"] : ["ryostore", "catalog"];
        catalogProc.running = true;
    }

    function install(item, dither) {
        if (!item || busyKey !== "")
            return;
        busyKey = itemKey(item);
        installStage = "FETCHING";
        installError = "";
        installErrorKey = "";
        _installError = "";
        var cmd = ["ryostore", "install", String(item.category), String(item.id)];
        var wantDither = (dither === undefined) ? true : dither;
        if (wantDither && String(item.category) === "decors")
            cmd.push("--dither");
        installProc.command = cmd;
        installProc.running = true;
    }

    function clearInstallError(item) {
        if (installErrorKey !== itemKey(item))
            return;
        installError = "";
        installErrorKey = "";
        installStage = "";
    }

    function retryInstall(item, dither) {
        clearInstallError(item);
        install(item, dither);
    }

    function openSettings(item) {
        if (!item)
            return;
        Quickshell.execDetached(["ryostore", "settings", String(item.category), String(item.id)]);
    }

    Component.onCompleted: refresh(false)

    Process {
        id: catalogProc
        stdout: StdioCollector { onStreamFinished: root._catalogOutput = text }
        stderr: StdioCollector { onStreamFinished: root._catalogError = text }
        onExited: code => {
            root.loading = false;
            if (code !== 0) {
                root.error = root._catalogError.trim() || "Catalogue failed";
                if (root._clearBusyAfterRefresh) {
                    root._clearBusyAfterRefresh = false;
                    root.busyKey = "";
                }
                return;
            }
            try {
                const next = JSON.parse(root._catalogOutput);
                if (!Array.isArray(next.categories) || !Array.isArray(next.items))
                    throw new Error("catalogue arrays are missing");
                root.catalog = next;
                root.categories = next.categories.slice();
                root.items = next.items.slice();
                root.offline = next.offline === true;
                root.generatedAt = String(next.generatedAt || "");
                root.error = "";
                if (root._clearBusyAfterRefresh) {
                    root._clearBusyAfterRefresh = false;
                    root.installStage = "COMPLETE";
                    root.busyKey = "";
                }
            } catch (e) {
                root.error = "Invalid catalogue: " + e;
                if (root._clearBusyAfterRefresh) {
                    root._clearBusyAfterRefresh = false;
                    root.busyKey = "";
                }
            }
        }
    }

    Process {
        id: installProc
        stderr: StdioCollector { onStreamFinished: root._installError = text }
        onRunningChanged: if (running) root.installStage = "INSTALLING"
        onExited: code => {
            if (code !== 0) {
                root.installStage = "FAILED";
                root.installError = root._installError.trim() || "Installation failed";
                root.installErrorKey = root.busyKey;
                root.busyKey = "";
                return;
            }
            root.installStage = "VERIFYING";
            root._clearBusyAfterRefresh = true;
            root.refresh(true);
        }
    }
}
