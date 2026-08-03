import QtQuick
import Quickshell
import "Singletons"
import "framebars/menus" as Menus
import "framebars/widgets" as Widgets
import "popouts" as Popouts

ShellRoot {
    id: root

    readonly property var implemented: ["clock", "notifications", "network", "bluetooth",
        "audio-input", "audio-output", "power-profile", "quick-settings", "quick-actions",
        "layout-switcher", "container", "divider", "spacer", "clipboard",
        "theme", "wallpaper", "weather", "media"]
    readonly property var deferred: []
    QtObject { id: probeOwnerA }
    QtObject { id: probeOwnerB }
    property bool tabReadyStaged: false
    property bool pageReadyStaged: false
    property bool nestedWasPending: false
    property var nestedWidgets: []
    function hosts(item, out) {
        if (item.widgetId !== undefined) out.push(item);
        for (let i = 0; i < item.children.length; ++i) root.hosts(item.children[i], out);
    }

    Item {
        id: scene
        width: 600
        height: 400
        property bool layoutStopped: false

        Column {
            Repeater {
                model: root.implemented.concat(root.deferred)
                delegate: MenuWidgetHost {
                    required property var modelData
                    width: 360
                    scale: 1
                    open: false
                    widgetId: modelData
                }
            }
        }

        MenuWidgetHost { id: qaHost; width: 360; scale: 1; open: false; widgetId: "quick-actions" }
        MenuWidgetHost { id: ppHost; width: 360; scale: 1; open: false; widgetId: "power-profile" }
        MenuWidgetHost { id: nwHost; width: 360; scale: 1; open: false; widgetId: "network" }
    }

    Menus.MenuColumn {
        id: retainedColumn
        width: 360
        height: 600
        widgets: root.nestedWidgets
        open: true
        incubate: true
        Component.onCompleted: nestedOpen.start()
    }

    Timer {
        id: nestedOpen
        interval: 20
        onTriggered: {
            root.nestedWidgets = ["theme"];
            root.nestedWasPending = !retainedColumn.ready;
        }
    }

    Menus.MenuQuickSettings {
        id: asyncQs
        width: 360
        height: 600
        avail: 600
        open: false
    }

    Timer {
        interval: 20
        running: true
        onTriggered: {
            asyncQs.switchToModule("notifications");
            root.tabReadyStaged = (asyncQs.activeModule === "home" && asyncQs.pendingModule === "notifications")
                || (asyncQs.activeModule === "notifications" && asyncQs.pendingModule === "");
            asyncQs.showPage("network");
            root.pageReadyStaged = asyncQs.page === "" && asyncQs.pendingPage === "network";
        }
    }

        Loader {
            id: layoutHost
            active: true
            sourceComponent: Component {
                Widgets.LayoutControl {
                    active: true
                    processCommand: ["sh", "-c", "sleep 5"]
                    onStopped: scene.layoutStopped = true
                }
            }
        }

    Loader {
        id: ppDestroyHost
        active: true
        sourceComponent: Component {
            MenuWidgetHost { width: 360; scale: 1; open: false; widgetId: "power-profile" }
        }
    }

    Loader {
        id: nwDestroyHost
        active: true
        sourceComponent: Component {
            MenuWidgetHost { width: 360; scale: 1; open: false; widgetId: "network" }
        }
    }

    Loader {
        id: qsDestroyHost
        active: true
        sourceComponent: Component {
            MenuWidgetHost { width: 360; scale: 1; open: false; widgetId: "quick-settings"; avail: 600 }
        }
    }


    Timer {
        interval: 600
        running: true
        onTriggered: {
            const all = [];
            root.hosts(scene, all);
            const found = id => all.find(h => h.widgetId === id);

            const resolvedOk = root.implemented.every(id => { const h = found(id); return h && h.loaded; });
            const deferredOk = root.deferred.every(id => { const h = found(id); return h && !h.loaded; });

            const wBase = Toggles.watchers;
            qaHost.open = true;
            const wOn = Toggles.watchers;
            qaHost.open = false;
            const wOff = Toggles.watchers;
            const qaGate = wOn === wBase + 1 && wOff === wBase;

            const qsBase = Toggles.watchers;
            qsDestroyHost.item.open = true;
            const qsOn = Toggles.watchers === qsBase + 1;
            qsDestroyHost.active = false;
            const qsDestroyed = Toggles.watchers === qsBase;
            const qsLifecycleGate = qsOn && qsDestroyed;
            Devices.startProbes(probeOwnerA);
            Devices.startProbes(probeOwnerB);
            Devices.stopProbes(probeOwnerA);
            const probeShared = Devices.probesWanted;
            Devices.stopProbes(probeOwnerB);
            const probeOwnershipGate = probeShared && !Devices.probesWanted;
            const asyncReadyGate = root.tabReadyStaged && root.pageReadyStaged
                && asyncQs.activeModule === "notifications" && asyncQs.pendingModule === ""
                && asyncQs.page === "network" && asyncQs.pendingPage === "";
            const nestedReadyGate = root.nestedWasPending && retainedColumn.ready;

            ppHost.open = true;
            ppDestroyHost.item.open = true;
            ppHost.open = false;
            const ppConcurrentClose = PowerProfiles.active;
            ppDestroyHost.active = false;
            const ppFinalRelease = PowerProfiles.active === false;

            nwHost.open = true;
            nwDestroyHost.item.open = true;
            nwHost.open = false;
            const nwConcurrentClose = Network.vpnPolling;
            nwDestroyHost.active = false;
            const nwFinalRelease = Network.vpnPolling === false;

            layoutHost.active = false;
            const lifecycleGate = ppConcurrentClose && ppFinalRelease && nwConcurrentClose && nwFinalRelease;
            Qt.callLater(function() {
                const qsProbesReleased = Devices.probeOwners.length === 0;
                console.log("RESOLVED " + JSON.stringify(root.implemented.filter(id => { const h = found(id); return h && h.loaded; })));
                console.log("DEFERRED-INERT " + JSON.stringify(root.deferred.filter(id => { const h = found(id); return h && !h.loaded; })));
                console.log("GATES qa=" + qaGate + " lifecycle=" + lifecycleGate
                    + " quick-settings-destruction=" + qsLifecycleGate
                    + " quick-settings-probes=" + qsProbesReleased
                    + " probe-ownership=" + probeOwnershipGate
                    + " layout-destruction=" + scene.layoutStopped
                    + " async-readiness=" + asyncReadyGate
                    + " nested-readiness=" + nestedReadyGate);
                console.log("ASYNC-STATE active=" + asyncQs.activeModule + " pending=" + asyncQs.pendingModule
                    + " page=" + asyncQs.page + " pending-page=" + asyncQs.pendingPage
                    + " staged-tab=" + root.tabReadyStaged + " staged-page=" + root.pageReadyStaged);
                console.log((resolvedOk && deferredOk) ? "MENU-HOST-RESOLVE-PASS" : "MENU-HOST-RESOLVE-FAIL");
                console.log((qaGate && lifecycleGate && qsLifecycleGate && qsProbesReleased
                    && probeOwnershipGate && asyncReadyGate && nestedReadyGate && scene.layoutStopped)
                    ? "MENU-OPEN-GATE-PASS" : "MENU-OPEN-GATE-FAIL");
                Qt.quit();
            });

        }
    }
}
