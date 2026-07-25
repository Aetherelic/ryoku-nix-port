import QtQuick
import Quickshell
import "Singletons"

// Offscreen check that MenuWidgetHost's finite switch resolves every implemented
// menu id to a real component while catalogued-but-deferred (Task 8) ids still
// hit the developer-error default. Also exercises the open-state gates: a menu
// releases its shared poller/scan/activation when it closes.
ShellRoot {
    id: root

    readonly property var implemented: ["clock", "notifications", "network", "bluetooth",
        "audio-input", "audio-output", "power-profile", "quick-settings", "quick-actions",
        "layout-switcher", "container", "divider", "spacer"]
    readonly property var deferred: ["launcher", "clipboard", "screenshot", "theme", "wallpaper", "weather", "media"]

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

    Timer {
        interval: 300
        running: true
        onTriggered: {
            const all = [];
            root.hosts(scene, all);
            const found = id => all.find(h => h.widgetId === id);

            const resolvedOk = root.implemented.every(id => { const h = found(id); return h && h.loaded; });
            const deferredOk = root.deferred.every(id => { const h = found(id); return h && !h.loaded; });

            // open-state gates: bump on open, release on close.
            const wBase = Toggles.watchers;
            qaHost.open = true;
            const wOn = Toggles.watchers;
            qaHost.open = false;
            const wOff = Toggles.watchers;
            const qaGate = wOn === wBase + 1 && wOff === wBase;

            ppHost.open = true;
            const ppOn = PowerProfiles.active;
            ppHost.open = false;
            const ppGate = ppOn === true && PowerProfiles.active === false;

            nwHost.open = true;
            const nwOn = Network.vpnPolling;
            nwHost.open = false;
            const nwGate = nwOn === true && Network.vpnPolling === false;

            console.log("RESOLVED " + JSON.stringify(root.implemented.filter(id => { const h = found(id); return h && h.loaded; })));
            console.log("DEFERRED-INERT " + JSON.stringify(root.deferred.filter(id => { const h = found(id); return h && !h.loaded; })));
            console.log("GATES qa=" + qaGate + " powerprofile=" + ppGate + " network=" + nwGate);
            console.log((resolvedOk && deferredOk) ? "MENU-HOST-RESOLVE-PASS" : "MENU-HOST-RESOLVE-FAIL");
            console.log((qaGate && ppGate && nwGate) ? "MENU-OPEN-GATE-PASS" : "MENU-OPEN-GATE-FAIL");
            Qt.quit();
        }
    }
}
