pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import "Singletons"

// Notification popup surface (contract 07 sec 1/2.4, sec 8; contract 12 sec 1).
// A per-monitor overlay layer surface anchored to the top edge, on the left or
// right (or centred) per the position setting, reserving nothing (exclusive
// zone 0) and never taking keyboard focus. It holds the flat, newest-first popup
// list (newest at index 0) at a fixed 400 px content width with 10 px between
// cards. When the list empties the surface unmaps 260 ms later, and a popup
// arriving during that wait cancels the unmap. Per-card slide/opacity motion is
// deliberately not reproduced, matching the sibling menu panels; the 260 ms is
// kept as the faithful surface-drop delay.
PanelWindow {
    id: win

    required property var modelData
    readonly property real s: (modelData ? modelData.height / 1080 : 1) * Math.max(0.7, Math.min(1.6, Config.fontScale))

    // Popup anchoring (contract 07 sec 7): Left -> top+left, Right (default) ->
    // top+right, Center -> top only (horizontally centred). The live setting is
    // notifications.notification_position (contract 14, owned by the settings
    // slice); it defaults to Right, the reference default, until that key lands.
    property string position: "Right"
    // popup_window_margins (contract 07 sec 8), default 0.
    property real margin: 0

    readonly property var popups: Notifs.popups
    property bool mapped: false

    screen: modelData
    visible: mapped
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-notifications"

    anchors.top: true
    anchors.left: position === "Left"
    anchors.right: position === "Right"
    margins.top: margin * s
    margins.left: margin * s
    margins.right: margin * s

    implicitWidth: 400 * s
    implicitHeight: Math.max(1, col.implicitHeight)

    // Map immediately on the first popup; unmap 260 ms after the list empties,
    // re-checking emptiness so a popup arriving during the wait cancels it.
    onPopupsChanged: {
        if (popups.length > 0) {
            unmapTimer.stop();
            mapped = true;
        } else {
            unmapTimer.restart();
        }
    }
    Component.onCompleted: mapped = popups.length > 0

    Timer {
        id: unmapTimer
        interval: Motion.notifHide
        onTriggered: if (win.popups.length === 0) win.mapped = false
    }

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 10 * win.s

        Repeater {
            model: win.popups

            delegate: NotificationCard {
                required property var modelData
                width: col.width
                notif: modelData
                // The popup has no menu to close, so it ignores actionInvoked.
            }
        }
    }
}
