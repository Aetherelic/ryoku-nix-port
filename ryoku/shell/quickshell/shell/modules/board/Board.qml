pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

/**
 * Board: the Super+G tool overlay, one instance per monitor. A transparent
 * board over the desktop (compositor-blurred behind, strength = Config.bgBlur)
 * hosting the layer's instrument widgets: drag to place, bracket to resize, pin
 * to keep one on a WlrLayer.Top window after the board closes. The controller
 * drives `active`; Esc or click-out request a close.
 */
Scope {
    id: root

    // the monitor this instance renders on.
    property var screen: null
    // driven by the controller (ShellState.boardOpen).
    property bool active: false

    // Close request from the board surface / Esc. Phase 10: the daemon idle-park
    // report (execDetached ryoku-shell state ryolayer) that tracked board + pin
    // residency is dropped; ShellState.boardOpen owns open/close in-process now.
    function hide() { root.active = false; }

    readonly property string focusedName: {
        var m = Hyprland.focusedMonitor;
        return m && m.name ? m.name : "";
    }

    readonly property string screenName: root.screen && root.screen.name ? root.screen.name : ""

    // --- backdrop blur ------------------------------------------------------
    // Hyprland blur size is one global knob, so while the board is open we drive
    // it to Config.bgBlur and restore the read baseline on close. This carries
    // the launcher's proven pattern verbatim: writes serialize through a single
    // `hyprctl eval "hl.config(...)"` writer (a newer request replaces the
    // pending one and fires when the current exits, so states reach the
    // compositor in order), and the baseline is read only from a drained
    // compositor via getoption, restoring both enabled and size so a blur that
    // was off globally is put back off. At bgBlur = 0 the window takes the
    // "ryolayer-noblur" namespace instead and the compositor rule never matches.
    property bool blurForced: false
    property bool blurKnown: false
    property bool savedBlurEnabled: false
    property int savedBlurSize: 0
    property string blurPending: ""

    Process {
        id: blurWriter
        onRunningChanged: {
            if (running || root.blurPending === "")
                return;
            var next = root.blurPending;
            root.blurPending = "";
            command = ["hyprctl", "eval", next];
            running = true;
        }
    }
    function evalBlur(enabled, size) {
        var cmd = "hl.config({ decoration = { blur = { enabled = " + (enabled ? "true" : "false")
            + ", size = " + Math.max(1, size) + " } } })";
        if (blurWriter.running) {
            root.blurPending = cmd;
            return;
        }
        blurWriter.command = ["hyprctl", "eval", cmd];
        blurWriter.running = true;
    }

    Process {
        id: blurProbe
        command: ["sh", "-c", "hyprctl getoption -j decoration:blur:enabled; hyprctl getoption -j decoration:blur:size"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.active)
                    return;
                var en, sz;
                try {
                    var lines = this.text.trim().split("\n");
                    en = JSON.parse(lines[0]);
                    sz = JSON.parse(lines[1]);
                } catch (e) {
                    return;
                }
                if (typeof en.bool !== "boolean" || typeof sz.int !== "number")
                    return;
                root.savedBlurEnabled = en.bool;
                root.savedBlurSize = sz.int;
                root.blurKnown = true;
                root.forceBackdropBlur();
            }
        }
    }
    function forceBackdropBlur() {
        root.blurForced = true;
        var want = Config.bgBlur | 0;
        root.evalBlur(want > 0, want);
    }
    function applyBackdropBlur() {
        if (Motion.blurDisabled || (Config.bgBlur | 0) <= 0)
            return;
        if (root.blurForced) {
            // already frosted: a live slider drag retunes the forced strength.
            root.forceBackdropBlur();
        } else {
            blurProbe.running = true;
        }
    }
    function restoreBlur() {
        if (!root.blurForced || !root.blurKnown)
            return;
        root.evalBlur(root.savedBlurEnabled, root.savedBlurSize);
        root.blurForced = false;
    }
    Timer {
        id: blurRestoreDelay
        interval: Motion.windowOut
        onTriggered: root.restoreBlur()
    }
    // hold pinned windows mapped through the entrance so the opaque plate sits
    // under the identical board slot fading in over it, then unmaps covered.
    Timer {
        id: openHold
        interval: Motion.window
        repeat: false
    }
    onActiveChanged: {
        if (active) {
            openHold.restart();
            blurRestoreDelay.stop();
            applyBackdropBlur();
        } else {
            blurRestoreDelay.restart();
        }
    }
    // a live slider drag while open retunes the forced strength.
    Connections {
        target: Config
        function onBgBlurChanged() {
            if (root.active)
                root.applyBackdropBlur();
        }
    }

    // --- pinned widgets on this screen --------------------------------------
    property var pinned: []
    function reloadPinned() {
        var out = [];
        var all = Config.widgets || [];
        for (var i = 0; i < all.length; i++)
            if (all[i].screen === root.screenName && all[i].pinned)
                out.push(all[i]);
        root.pinned = out;
    }
    Component.onCompleted: root.reloadPinned()
    Connections {
        target: Config
        function onWidgetsChanged() { root.reloadPinned(); }
    }

    // --- the board window for this screen -----------------------------------
    PanelWindow {
        id: win
        readonly property bool isFocused: !root.focusedName || root.focusedName === root.screenName
        readonly property bool shown: root.active

        screen: root.screen
        visible: shown || closing.running
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.namespace: (Config.bgBlur | 0) > 0 && !Motion.blurDisabled ? "ryolayer" : "ryolayer-noblur"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: (shown && isFocused) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        Timer { id: closing; interval: Motion.windowOut; repeat: false }
        onShownChanged: if (!shown) closing.restart()

        BoardSurface {
            id: board
            anchors.fill: parent
            screenName: root.screenName
            active: win.shown
            focusHere: win.isFocused
            onRequestClose: root.hide()

            opacity: win.shown ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: win.shown ? Motion.window : Motion.windowOut; easing.type: win.shown ? Motion.easeStandard : Motion.easeExit } }
        }
    }

    // --- pinned widgets: small Top-layer windows while the board is closed ---
    // One window per pinned entry, sized to the slot and placed by margins, so
    // input is naturally confined to the widget (the camera-bubble pattern
    // without the mask bookkeeping). Clickthrough pins mask to nothing and
    // fade, an ambient readout the pointer ignores.
    Variants {
        model: root.pinned

        PanelWindow {
            id: pinWin
            required property var modelData
            readonly property var geom: {
                var s = root.screen;
                if (!s)
                    return { x: 0, y: 0 };
                var x = Math.round(modelData.cx * s.width - modelData.w / 2);
                var y = Math.round(modelData.cy * s.height - modelData.h / 2);
                return {
                    x: Math.max(0, Math.min(s.width - modelData.w, x)),
                    y: Math.max(0, Math.min(s.height - modelData.h, y))
                };
            }

            screen: root.screen
            visible: (!root.active) || openHold.running
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.namespace: "ryolayer-pin"
            WlrLayershell.layer: WlrLayer.Top
            // click-to-focus lets a pinned notes plate take typing;
            // OnDemand releases focus on click-away, so pinned plates stay non-intrusive.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            anchors { top: true; left: true }
            margins { top: pinWin.geom.y; left: pinWin.geom.x }
            implicitWidth: modelData.w
            implicitHeight: modelData.h

            // clickthrough: no input at all, and a quieter presence.
            mask: modelData.clickthrough ? passRegion : null
            Region { id: passRegion }

            RyoSlot {
                anchors.fill: parent
                entry: pinWin.modelData
                screenName: root.screenName
                interactive: false
                active: pinWin.visible

                // fade a clickthrough pin to the ambient 0.8; the plate
                // eases with the house settle, the window map does not.
                opacity: pinWin.modelData.clickthrough ? 0.8 : 1
                Behavior on opacity { NumberAnimation { duration: Motion.settle; easing.type: Motion.easeStandard } }
            }
        }
    }
}
