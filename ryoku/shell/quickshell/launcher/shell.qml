//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Io
import "shared/Singletons"
import "shared/providers" as SharedProviders
import "shared/lib/catalog.js" as Catalog

ShellRoot {
    id: root

    property var catalog: null
    property string activeId: ""
    property string requestedId: LauncherConfig.variant
    property string pendingId: ""
    property bool fallbackTried: false
    property bool switchQueued: false
    readonly property bool variantReady:
        variantLoader.status === Loader.Ready && variantLoader.item !== null

    function selectEntry(id) {
        return catalog ? Catalog.entry(catalog, id) : null;
    }

    function activate(id) {
        var next = selectEntry(id);
        if (!next)
            return;
        activeId = next.id;
        variantLoader.source = Qt.resolvedUrl(next.entrypoint);
    }

    function requestVariant(id) {
        var next = selectEntry(id);
        if (!next)
            return;
        if (next.id === activeId) {
            pendingId = "";
            return;
        }
        pendingId = next.id;
        if (variantReady && variantLoader.item.shown)
            variantLoader.item.hide();
        else
            finishSwitch();
    }

    function finishSwitch() {
        if (!pendingId || switchQueued)
            return;
        switchQueued = true;
        Qt.callLater(function () {
            root.switchQueued = false;
            if (!root.pendingId)
                return;
            var next = root.pendingId;
            root.pendingId = "";
            root.fallbackTried = false;
            root.activate(next);
        });
    }

    function show(mon) {
        if (!pendingId && variantReady)
            variantLoader.item.show(mon);
    }

    function hide() {
        if (variantReady)
            variantLoader.item.hide();
    }

    function toggle(mon) {
        if (!pendingId && variantReady)
            variantLoader.item.toggle(mon);
    }

    function stateDump() {
        var state = variantReady ? variantLoader.item.stateDump() : {};
        state.variant = activeId;
        state.requestedVariant = requestedId;
        state.pendingVariant = pendingId;
        state.availableVariants = catalog
            ? catalog.variants.map(function(entry) { return entry.id; }) : [];
        if (state.open === undefined)
            state.open = false;
        return state;
    }

    function runCommand(line) {
        var parts = String(line || "").trim().split(/\s+/);
        var fn = parts[0];
        var mon = parts.length > 1 ? parts[1] : "";
        switch (fn) {
        case "toggle": toggle(mon); return true;
        case "show": show(mon); return true;
        case "hide": hide(); return true;
        default: return false;
        }
    }

    FileView {
        id: catalogFile
        path: Qt.resolvedUrl("catalog.json")
        blockLoading: true
        printErrors: true
        onLoaded: {
            root.catalog = Catalog.normalize(JSON.parse(text()));
            root.activate(LauncherConfig.variant);
        }
    }

    onRequestedIdChanged: if (catalog) requestVariant(requestedId)

    Loader {
        id: variantLoader
        asynchronous: false
        onStatusChanged: {
            if (status !== Loader.Error || !root.catalog)
                return;
            var fallback = Catalog.fallbackEntry(root.catalog);
            if (!root.fallbackTried && fallback && root.activeId !== fallback.id) {
                root.fallbackTried = true;
                root.activeId = fallback.id;
                source = Qt.resolvedUrl(fallback.entrypoint);
            }
        }
    }

    Connections {
        target: root.variantReady ? variantLoader.item : null
        function onShownChanged() {
            if (!target.shown)
                root.finishSwitch();
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(mon: string): void { root.toggle(mon); }
        function show(mon: string): void { root.show(mon); }
        function hide(): void { root.hide(); }
    }

    SocketServer {
        active: true
        path: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp")
            + "/ryoku-launcher.sock"
        handler: Socket {
            id: commandSocket
            parser: SplitParser {
                onRead: line => {
                    var command = String(line || "").trim();
                    if (command === "state") {
                        commandSocket.write(
                            JSON.stringify(root.stateDump()) + "\n");
                    } else {
                        commandSocket.write(
                            (root.runCommand(command) ? "ok" : "err") + "\n");
                    }
                }
            }
        }
    }
}
