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
        property int promptId: -1
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
        railClearances: ({ top: 16, left: 16, bottom: 16, right: 16 })
        onSurfaceClosed: (id, context) => lifecycle.handleClosed(id, context)
    }
    FrameMenuManager {
        id: second
        width: 1200
        height: 800
        monitorName: "HDMI-A-1"
        scale: 1
        group: root.group
        railClearances: ({ top: 16, left: 16, bottom: 16, right: 16 })
        onSurfaceClosed: (id, context) => lifecycle.handleClosed(id, context)
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
            function openKeyringOn(manager, monitor, promptId) {
                keyring.active = true;
                keyring.busy = false;
                keyring.promptId = promptId;
                first.retireKeyringPrompt(promptId);
                second.retireKeyringPrompt(promptId);
                manager.openSurface("keyring", null, monitor, { promptId: promptId });
            }
            function closesKeyring(action) {
                const beforeDismiss = keyring.dismissCount;
                const beforeFocus = root.focusCount;
                action();
                return keyring.dismissCount === beforeDismiss + 1 && root.focusCount === beforeFocus + 1;
            }
            first.openSurface("quick-settings", null, "eDP-1");
            const firstOpen = first.activeIdAt("left") === "quick-settings";
            const quickSettingsFrame = first.activeMenu !== null
                && first.activeMenu.id === "quick-settings"
                && first.chromeOwner === "quick-settings";
            const quickSettingsFrameSpan = first.chromePanel.anchor === "left"
                && first.chromePanel.y === first.railClearances.top
                && first.chromePanel.h === first.height - first.railClearances.top - first.railClearances.bottom
                && first.chromePanel.w > 0;
            first.openSurface("stash", null, "eDP-1");
            const replacement = first.activeIdAt("right") === "stash";
            second.openSurface("stash", null, "HDMI-A-1");
            first.openSurface("stash", null, "eDP-1");
            Stash.authStepAside("eDP-1", "stash");
            const authStepAside = first.activeIdAt("right") === "" && second.activeIdAt("right") === "stash";
            first.closeSurface("stash", "eDP-1");
            const isolatedClose = first.activeIdAt("right") === "" && second.activeIdAt("right") === "stash";
            second.openSurface("quick-settings", null, "HDMI-A-1");
            second.closeSurface("stash", "HDMI-A-1");
            const staleClose = second.activeIdAt("left") === "quick-settings";
            first.openSurface("polkit", null, "HDMI-A-1");
            const monitorGuard = first.activeIdAt("top") === "";
            first.openSurface("polkit", null, "eDP-1");
            const modalMask = first.surfaceModal && first.masks["top"].bw > 0;
            first.openSurface("polkit", null, "eDP-1");
            const polkitToggle = first.activeIdAt("top") === "";
            first.openSurface("plugin:missing", null, "eDP-1");
            first.openSurface("plugin:missing", null, "eDP-1");
            const pluginToggle = first.activeIdAt("top") === "";
            first.openSurface("plugin:old", null, "eDP-1");
            first.openSurface("plugin:replacement", null, "eDP-1");
            first.pluginUnpinRequested("old");
            const delayedPluginUnpinSafe = first.activeIdAt("top") === "plugin:replacement";
            first.closeAll();
            first.openSurface("voice-off", null, "eDP-1");
            const voicePassive = first.activeIdAt("bottom") === "voice" && !first.surfaceModal;
            openKeyringOn(first, "eDP-1", 1);
            const keyringFocus = first.activeIdAt("top") === "keyring" && first.surfaceModal;
            first.openSurface("polkit", null, "eDP-1");
            first.closeSurface("voice-off", "eDP-1");
            const normalizedStaleClose = first.activeIdAt("top") === "polkit";
            openKeyringOn(first, "eDP-1", 2);
            const bodyClose = closesKeyring(() => first.closeMenu("keyring"));
            openKeyringOn(first, "eDP-1", 3);
            const escapeClose = closesKeyring(() => first.closeAll());
            openKeyringOn(first, "eDP-1", 4);
            const backdropClose = closesKeyring(() => first.closeAll());
            openKeyringOn(first, "eDP-1", 5);
            const focusGrabClose = closesKeyring(() => first.closeAll());
            openKeyringOn(first, "eDP-1", 6);
            const daemonClose = closesKeyring(() => first.closeSurface("keyring", "eDP-1"));
            openKeyringOn(first, "eDP-1", 7);
            const fullscreenClose = closesKeyring(() => first.active = false);
            first.active = true;
            openKeyringOn(first, "eDP-1", 8);
            const replacementClose = closesKeyring(() => first.openSurface("polkit", null, "eDP-1"));
            first.openSurface("voice", null, "eDP-1");
            openKeyringOn(first, "eDP-1", 9);
            const beforeStaleDismiss = keyring.dismissCount;
            first.closeSurface("voice-off", "eDP-1");
            const staleKeyringSafe = first.activeIdAt("top") === "keyring" && keyring.dismissCount === beforeStaleDismiss;
            openKeyringOn(first, "eDP-1", 10);
            openKeyringOn(second, "HDMI-A-1", 11);
            const handoffRetiresOld = first.activeIdAt("top") === "" && second.activeIdAt("top") === "keyring";
            const beforeHandoffDismiss = keyring.dismissCount;
            const beforeHandoffFocus = root.focusCount;
            first.closeSurface("keyring", "eDP-1");
            const staleHandoffCloseSafe = second.activeIdAt("top") === "keyring"
                && keyring.active && keyring.promptId === 11
                && keyring.dismissCount === beforeHandoffDismiss && root.focusCount === beforeHandoffFocus;
            second.closeSurface("keyring", "HDMI-A-1");
            const activeHandoffCloseOnce = keyring.dismissCount === beforeHandoffDismiss + 1
                && root.focusCount === beforeHandoffFocus + 1;
            first.closeAll();
            console.log("FRAME-MENU-MANAGER-GATES " + JSON.stringify({
                firstOpen, quickSettingsFrame, quickSettingsFrameSpan, replacement, authStepAside, isolatedClose, staleClose,
                monitorGuard, modalMask, polkitToggle, pluginToggle, delayedPluginUnpinSafe,
                voicePassive, keyringFocus, normalizedStaleClose, bodyClose, escapeClose,
                backdropClose, focusGrabClose, daemonClose, fullscreenClose, replacementClose,
                staleKeyringSafe, handoffRetiresOld, staleHandoffCloseSafe, activeHandoffCloseOnce
            }));
            console.log((firstOpen && quickSettingsFrame && quickSettingsFrameSpan && replacement && authStepAside && isolatedClose && staleClose
                && monitorGuard && modalMask && polkitToggle && pluginToggle && delayedPluginUnpinSafe
                && voicePassive && keyringFocus && normalizedStaleClose && bodyClose && escapeClose
                && backdropClose && focusGrabClose && daemonClose && fullscreenClose && replacementClose
                && staleKeyringSafe && handoffRetiresOld && staleHandoffCloseSafe && activeHandoffCloseOnce)
                ? "FRAME-MENU-MANAGER-PASS" : "FRAME-MENU-MANAGER-FAIL");
            Qt.quit();
        }
    }
}
