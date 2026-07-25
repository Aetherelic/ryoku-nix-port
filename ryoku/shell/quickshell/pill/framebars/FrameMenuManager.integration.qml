import QtQuick
import Quickshell
import Ryoku.Blobs

ShellRoot {
    id: root
    BlobGroup { id: group }
    FrameMenuManager {
        id: first
        width: 1200
        height: 800
        monitorName: "eDP-1"
        scale: 1
        group: root.group
        frameThickness: 16
    }
    FrameMenuManager {
        id: second
        width: 1200
        height: 800
        monitorName: "HDMI-A-1"
        scale: 1
        group: root.group
        frameThickness: 16
    }
    Timer {
        interval: 100
        running: true
        onTriggered: {
            first.openSurface("quick-settings", null, "eDP-1");
            const firstOpen = first.activeIdAt("left") === "quick-settings";
            first.openSurface("stash", null, "eDP-1");
            const replacement = first.activeIdAt("left") === "stash";
            second.openSurface("system", null, "HDMI-A-1");
            const independent = second.activeIdAt("right") === "system" && first.activeIdAt("right") === "";
            first.openSurface("power", null, "HDMI-A-1");
            const monitorGuard = first.activeIdAt("top") === "";
            first.openSurface("power", null, "eDP-1");
            const modalMask = first.modal && first.masks["top"].bw > 0;
            first.closeSurface("power", "eDP-1");
            const closed = first.activeIdAt("top") === "";
            first.closeSurface("stash", "eDP-1");
            first.openSurface("voice-off", null, "eDP-1");
            const voicePassive = first.activeIdAt("top") === "voice" && !first.modal;
            first.openSurface("keyring", null, "eDP-1");
            const keyringFocus = first.activeIdAt("top") === "keyring" && first.modal;
            first.openSurface("plugin:missing", null, "eDP-1");
            const pluginRoute = first.activeIdAt("top") === "plugin:missing";
            console.log((firstOpen && replacement && independent && monitorGuard && modalMask && closed
                && voicePassive && keyringFocus && pluginRoute)
                ? "FRAME-MENU-MANAGER-PASS" : "FRAME-MENU-MANAGER-FAIL");
            Qt.quit();
        }
    }
}
