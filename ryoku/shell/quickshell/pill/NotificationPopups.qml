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
// cards. Each card slides in/out over 200 ms (Motion.rowReveal, the reference
// GtkRevealer SlideDown). When the list empties the surface unmaps 260 ms later
// (Motion.notifHide), letting the last slide finish first; a popup arriving in
// that wait cancels the unmap.
//
// `Notifs.popups` is reassigned as a whole array on every change, which resets a
// plain view (no per-item add/remove animation). A local `cards` ListModel is
// reconciled against it incrementally so the ListView's add/remove/displaced
// transitions actually fire per card.
PanelWindow {
    id: win

    required property var modelData
    // Fixed logical px: content width 400, inter-card spacing 10. The reference
    // container is a fixed-size window that does not grow with monitor or font
    // scale, so no scale term.

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
    // Exclusive zone 0: reserve nothing, respect other layers' zones (contract
    // 12 sec 1). ExclusionMode.Ignore would request -1 instead.
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-notifications"

    anchors.top: true
    anchors.left: position === "Left"
    anchors.right: position === "Right"
    margins.top: margin
    margins.left: margin
    margins.right: margin

    implicitWidth: 400
    implicitHeight: Math.max(1, list.contentHeight)

    // Newest-first card view, reconciled from Notifs.popups by id.
    ListModel { id: cards }

    function indexOfId(id) {
        for (var i = 0; i < cards.count; i++)
            if (cards.get(i).nid === id)
                return i;
        return -1;
    }
    function sync() {
        var incoming = win.popups;
        // Drop cards whose notification is gone (this triggers the remove slide).
        for (var i = cards.count - 1; i >= 0; i--) {
            var id = cards.get(i).nid;
            var keep = false;
            for (var k = 0; k < incoming.length; k++)
                if (incoming[k].id === id) { keep = true; break; }
            if (!keep)
                cards.remove(i);
        }
        // Insert new cards and reorder to match the newest-first incoming order.
        for (var j = 0; j < incoming.length; j++) {
            var p = incoming[j];
            var cur = win.indexOfId(p.id);
            if (cur < 0)
                cards.insert(j, { nid: p.id, entry: p });
            else if (cur !== j)
                cards.move(cur, j, 1);
        }
    }

    // Map immediately on the first popup; unmap 260 ms after the list empties,
    // re-checking emptiness so a popup arriving during the wait cancels it.
    onPopupsChanged: {
        sync();
        if (popups.length > 0) {
            unmapTimer.stop();
            mapped = true;
        } else {
            unmapTimer.restart();
        }
    }
    Component.onCompleted: {
        sync();
        mapped = popups.length > 0;
    }

    Timer {
        id: unmapTimer
        interval: Motion.notifHide
        onTriggered: if (win.popups.length === 0) win.mapped = false
    }

    ListView {
        id: list
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: contentHeight
        spacing: 10
        interactive: false
        model: cards

        // Card slide (contract 12 sec 5): 200 ms OutCubic in and out, siblings
        // sliding to fill. The 260 ms unmap delay outlasts this so the last slide
        // completes before the surface drops.
        add: Transition {
            NumberAnimation { properties: "opacity"; from: 0; to: 1; duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve }
            NumberAnimation { properties: "y"; duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve }
        }
        displaced: Transition {
            NumberAnimation { properties: "y"; duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve }
        }
        remove: Transition {
            NumberAnimation { properties: "opacity"; to: 0; duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve }
        }
        removeDisplaced: Transition {
            NumberAnimation { properties: "y"; duration: Motion.rowReveal; easing.type: Motion.rowRevealCurve }
        }

        delegate: NotificationCard {
            required property var entry
            width: ListView.view ? ListView.view.width : implicitWidth
            notif: entry
            // The popup has no menu to close, so it ignores actionInvoked.
        }
    }
}
