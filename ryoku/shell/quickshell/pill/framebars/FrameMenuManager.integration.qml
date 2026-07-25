import QtQuick
import Quickshell
import Ryoku.Blobs
import "Singletons"

ShellRoot {
    id: root
    BlobGroup { id: group }
    property int focusCount: 0
    QtObject {
        id: keyring
        property bool active: false
        property bool busy: false
        property int dismissCount: 0
        function dismiss() {
            if (active && !busy) {
                dismissCount++;
                active = false;
            }
        }
    }
    FrameSurfaceLifecycle {
        id: lifecycle
        keyring: keyring
        onFocusRestored: root.focusCount++
    }
    FrameMenuManager {
        id: first
        width: 1200
        height: 800
        monitorName: "eDP-1"
        scale: 1
        group: root.group
        frameThickness: 16
        onSurfaceClosed: id => lifecycle.handleClosed(id)
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
    Connections {
        target: Stash
        function onAuthStepAside(mon, id) {
            first.closeSurface(id, mon);
            second.closeSurface(id, mon);
        }
    }
    Timer {
        interval: 100
        running: true
        onTriggered: {
            function openKeyring() {
                keyring.active = true;
                first.openSurface("keyring", null, "eDP-1");
            }
            function closesKeyring(action) {
                const beforeDismiss = keyring.dismissCount;
                const beforeFocus = root.focusCount;
                action();
                return keyring.dismissCount === beforeDismiss + 1 && root.focusCount === beforeFocus + 1;
            }
            first.openSurface("quick-settings", null, "eDP-1");
            const firstOpen = first.activeIdAt("left") === "quick-settings";
            first.openSurface("stash", null, "eDP-1");
            const replacement = first.activeIdAt("left") === "stash";
            second.openSurface("stash", null, "HDMI-A-1");
            first.openSurface("stash", null, "eDP-1");
            Stash.authStepAside("eDP-1", "stash");
            const authStepAside = first.activeIdAt("left") === "" && second.activeIdAt("left") === "stash";
            second.openSurface("system", null, "HDMI-A-1");
            first.closeSurface("stash", "eDP-1");
            const isolatedClose = first.activeIdAt("left") === "" && second.activeIdAt("right") === "system";
            second.openSurface("quick-settings", null, "HDMI-A-1");
            second.closeSurface("stash", "HDMI-A-1");
            const staleClose = second.activeIdAt("left") === "quick-settings";
            first.openSurface("power", null, "HDMI-A-1");
            const monitorGuard = first.activeIdAt("top") === "";
            first.openSurface("power", null, "eDP-1");
            const modalMask = first.modal && first.masks["top"].bw > 0;
            first.openSurface("power", null, "eDP-1");
            const powerToggle = first.activeIdAt("top") === "";
            first.openSurface("plugin:missing", null, "eDP-1");
            first.openSurface("plugin:missing", null, "eDP-1");
            const pluginToggle = first.activeIdAt("top") === "";
            first.openSurface("voice-off", null, "eDP-1");
            const voicePassive = first.activeIdAt("top") === "voice" && !first.modal;
            openKeyring();
            const keyringFocus = first.activeIdAt("top") === "keyring" && first.modal;
            first.openSurface("power", null, "eDP-1");
            first.closeSurface("voice-off", "eDP-1");
            const normalizedStaleClose = first.activeIdAt("top") === "power";
            openKeyring();
            const bodyClose = closesKeyring(() => first.closeMenu("keyring"));
            openKeyring();
            const escapeClose = closesKeyring(() => first.closeAll());
            openKeyring();
            const backdropClose = closesKeyring(() => first.closeAll());
            openKeyring();
            const focusGrabClose = closesKeyring(() => first.closeAll());
            openKeyring();
            const daemonClose = closesKeyring(() => first.closeSurface("keyring", "eDP-1"));
            openKeyring();
            const fullscreenClose = closesKeyring(() => first.active = false);
            first.active = true;
            openKeyring();
            const replacementClose = closesKeyring(() => first.openSurface("power", null, "eDP-1"));
            first.openSurface("voice", null, "eDP-1");
            openKeyring();
            const beforeStaleDismiss = keyring.dismissCount;
            first.closeSurface("voice-off", "eDP-1");
            const staleKeyringSafe = first.activeIdAt("top") === "keyring" && keyring.dismissCount === beforeStaleDismiss;
            first.closeAll();
            console.log((firstOpen && replacement && authStepAside && isolatedClose && staleClose && monitorGuard && modalMask
                && powerToggle && pluginToggle && voicePassive && keyringFocus && normalizedStaleClose
                && bodyClose && escapeClose && backdropClose && focusGrabClose && daemonClose
                && fullscreenClose && replacementClose && staleKeyringSafe)
                ? "FRAME-MENU-MANAGER-PASS" : "FRAME-MENU-MANAGER-FAIL");
            Qt.quit();
        }
    }
}
