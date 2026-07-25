pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "framebars/BarCatalog.js" as BarCatalog
import "framebars/widgets"
import "Singletons"

Item {
    id: root

    property string widgetId: ""
    required property string edge
    required property real scale
    signal menuRequested(string id, rect ownerRect)
    signal actionRequested(string id)
    signal activated()

    implicitWidth: widgetLoader.item ? widgetLoader.item.implicitWidth : 0
    readonly property bool loaded: widgetLoader.item !== null
    implicitHeight: widgetLoader.item ? widgetLoader.item.implicitHeight : 0

    function componentFor(id) {
        switch (id) {
        case "clock": return clockComponent;
        case "workspaces": return workspacesComponent;
        case "tray": return trayComponent;
        case "quick-settings": return quickSettingsComponent;
        case "dock": return dockComponent;
        case "layout-switcher": return layoutSwitcherComponent;
        case "power-profile": return powerProfileComponent;
        case "vpn": return vpnComponent;
        case "audio-input":
        case "audio-output":
        case "battery":
        case "bluetooth":
        case "network":
        case "notifications": return statusComponent;
        case "color-picker":
        case "lock":
        case "logout":
        case "reboot":
        case "screenshot":
        case "shutdown":
        case "wallpaper": return actionComponent;
        default:
            if (BarCatalog.entry(id)) console.error("frame bars: no host component for " + id);
            return null;
        }
    }

    function activeClients() {
        const result = [];
        const toplevels = Hyprland.toplevels.values;
        for (let i = 0; i < toplevels.length; ++i) {
            const data = toplevels[i] && toplevels[i].lastIpcObject;
            const className = data && (data.class || data.initialClass);
            if (typeof className === "string" && className) result.push({ className: className, address: data.address || "" });
        }
        return result;
    }

    function updatePinned(className, add) {
        const next = JSON.parse(JSON.stringify(Config.frameBars));
        const pinned = next.dock && Array.isArray(next.dock.pinned) ? next.dock.pinned : [];
        next.dock = { pinned: add ? pinned.concat(pinned.includes(className) ? [] : [className]) : pinned.filter(value => value !== className) };
        Config.frameBars = next;
    }

    function activate(className) {
        const toplevels = Hyprland.toplevels.values;
        for (let i = 0; i < toplevels.length; ++i) {
            const data = toplevels[i] && toplevels[i].lastIpcObject;
            if (data && (data.class === className || data.initialClass === className) && data.address) {
                Hyprland.dispatch('hl.dsp.focus({ window = "address:' + data.address + '" })');
                return;
            }
        }
    }

    Loader {
        id: widgetLoader
        anchors.centerIn: parent
        sourceComponent: root.componentFor(root.widgetId)
    }

    Connections {
        target: widgetLoader.item
        ignoreUnknownSignals: true
        function onMenuRequested(id, ownerRect) {
            const topLeft = widgetLoader.item.mapToGlobal(ownerRect.x, ownerRect.y);
            root.menuRequested(id, { x: topLeft.x, y: topLeft.y, width: ownerRect.width, height: ownerRect.height });
        }
        function onActionRequested(id) { root.actionRequested(id); }
    }

    Component { id: clockComponent; RailClock { edge: root.edge; scale: root.scale } }
    Component { id: workspacesComponent; RailWorkspaces { edge: root.edge; scale: root.scale } }
    Component { id: trayComponent; RailTray { edge: root.edge; scale: root.scale } }
    Component { id: quickSettingsComponent; RailQuickSettings { edge: root.edge; scale: root.scale } }
    Component {
        id: dockComponent
        RailDock {
            edge: root.edge
            scale: root.scale
            pinned: Config.normalizedFrameBars.dock.pinned
            activeClients: root.activeClients()
            onActivate: className => root.activate(className)
            onPin: className => root.updatePinned(className, true)
            onUnpin: className => root.updatePinned(className, false)
        }
    }
    Component { id: statusComponent; RailStatus { edge: root.edge; scale: root.scale; statusId: root.widgetId } }
    Component { id: layoutSwitcherComponent; RailLayoutSwitcher { edge: root.edge; scale: root.scale; active: root.visible } }
    Component { id: powerProfileComponent; RailPowerProfile { edge: root.edge; scale: root.scale; active: root.visible } }
    Component { id: vpnComponent; RailVpn { edge: root.edge; scale: root.scale; active: root.visible } }
    Component { id: actionComponent; RailAction { edge: root.edge; scale: root.scale; actionId: root.widgetId } }
}
