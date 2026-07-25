import QtQuick
import Quickshell
import "Singletons"
import "framebars/widgets" as Widgets
import "popouts" as Popouts

ShellRoot {
    id: root

    readonly property var implemented: ["clock", "notifications", "network", "bluetooth",
        "audio-input", "audio-output", "power-profile", "quick-settings", "quick-actions",
        "layout-switcher", "container", "divider", "spacer"]
    readonly property var deferred: ["launcher", "clipboard", "screenshot", "theme", "wallpaper", "weather", "media"]
    property bool layoutStopped: false

    function hosts(item, out) {
        if (item.widgetId !== undefined) out.push(item);
        for (let i = 0; i < item.children.length; ++i) root.hosts(item.children[i], out);
    }

    Item {
        id: scene
        width: 600
        height: 400

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

        Loader {
            id: layoutHost
            active: true
            sourceComponent: Component {
                Widgets.LayoutControl {
                    active: true
                    processCommand: ["sh", "-c", "sleep 5"]
                    onStopped: root.layoutStopped = true
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

    Popouts.SidebarSystem {
        width: 340
        height: 600
        open: false
        panes: ["notifications"]
    }

    Timer {
        interval: 300
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
                console.log("RESOLVED " + JSON.stringify(root.implemented.filter(id => { const h = found(id); return h && h.loaded; })));
                console.log("DEFERRED-INERT " + JSON.stringify(root.deferred.filter(id => { const h = found(id); return h && !h.loaded; })));
                console.log("GATES qa=" + qaGate + " lifecycle=" + lifecycleGate + " layout-destruction=" + root.layoutStopped);
                console.log((resolvedOk && deferredOk) ? "MENU-HOST-RESOLVE-PASS" : "MENU-HOST-RESOLVE-FAIL");
                console.log((qaGate && lifecycleGate && root.layoutStopped) ? "MENU-OPEN-GATE-PASS" : "MENU-OPEN-GATE-FAIL");
                Qt.quit();
            });

        }
    }
}
