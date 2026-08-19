pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import shell.services

// The dock's app islands, grouped into custom launchers (pinned, not running)
// and running apps (the ones with window popups), split by a separator. Each app
// is its own frosted pill in the qsbar islands language; DockSlot feeds pillRects
// to a ReactorLayer so the reactor wave flows in the gaps. Left click activates,
// right click pins/unpins, hover grows a DockPreview. Magnify tracks the cursor
// continuously across the whole band (icons AND gaps) as a smooth scale + rise.
//
// Islands render from a Repeater over a diffed ListModel (not the raw slots
// array) so an app that opens or is pinned pops in, one that closes or is
// unpinned is removed, and every other island slides to its new spot -- without
// recreating the whole row on each toplevel event. The geometry maths stay on the
// resting `slots` array (stable reactor + magnify anchor). Every animation is
// gated on reduce-motion, so Power Saver adds/removes/slides instantly.
Item {
    id: row

    required property var theme
    required property string edge
    property real reservedDepth: 0

    property real baseSize: 46
    property real iconSize: 30
    property real gap: 16
    property real islandRadius: 12
    property real sepWidth: 15

    readonly property bool magnify: !!(theme && theme.dockMagnify) && !Perf.reduceMotion
    readonly property bool animate: !Perf.reduceMotion
    readonly property real maxScale: 1.4
    readonly property real reach: (baseSize + gap) * 1.9

    // ── groups ──────────────────────────────────────────────────────────────
    readonly property var pins: {
        const dp = theme && theme.dockPinned ? Array.from(theme.dockPinned) : [];
        return dp.length ? dp : Dock.starterPins();
    }
    readonly property var runningClasses: {
        const seen = {}, out = [];
        const cs = Dock.clients;
        for (let i = 0; i < cs.length; ++i) {
            const c = cs[i].className;
            if (c && !seen[c]) { seen[c] = true; out.push(c); }
        }
        return out;
    }
    // custom = pinned launchers not currently running; tray = running apps.
    readonly property var customGroup: row.pins.filter(c => row.runningClasses.indexOf(c) === -1)
    readonly property var trayGroup: row.runningClasses
    // Flat slot list: app slots plus one separator between the two non-empty groups.
    readonly property var slots: {
        const s = [];
        for (let i = 0; i < row.customGroup.length; ++i)
            s.push({ kind: "app", className: row.customGroup[i] });
        if (row.customGroup.length && row.trayGroup.length)
            s.push({ kind: "sep", className: "" });
        for (let j = 0; j < row.trayGroup.length; ++j)
            s.push({ kind: "app", className: row.trayGroup[j] });
        return s;
    }

    function slotW(i) { return row.slots[i] && row.slots[i].kind === "sep" ? row.sepWidth : row.baseSize; }
    function slotX(i) {
        let x = 0;
        for (let j = 0; j < i; ++j) x += row.slotW(j) + row.gap;
        return x;
    }
    readonly property real restSpan: {
        let x = 0;
        for (let i = 0; i < row.slots.length; ++i) x += row.slotW(i);
        return x + Math.max(0, row.slots.length - 1) * row.gap;
    }

    // Resting app-island rects (band coords) for the reactor to channel between.
    readonly property var pillRects: {
        const out = [];
        for (let i = 0; i < row.slots.length; ++i)
            if (row.slots[i].kind === "app") out.push({ x: row.slotX(i), w: row.baseSize });
        return out;
    }

    // Diff the desired slots into the ListModel so a Repeater over it creates ONLY
    // genuinely new islands (pop-in) and drops removed ones, instead of recreating
    // the whole row every time a toplevel event bumps the client list.
    ListModel { id: slotModel }
    onSlotsChanged: row.syncSlots()
    Component.onCompleted: row.syncSlots()
    function syncSlots() {
        const desired = row.slots;
        for (let i = slotModel.count - 1; i >= 0; --i) {
            const m = slotModel.get(i);
            if (!desired.some(d => d.kind === m.kind && d.className === m.className))
                slotModel.remove(i);
        }
        for (let j = 0; j < desired.length; ++j) {
            const d = desired[j];
            let cur = -1;
            for (let k = 0; k < slotModel.count; ++k) {
                const m = slotModel.get(k);
                if (m.kind === d.kind && m.className === d.className) { cur = k; break; }
            }
            if (cur === -1) slotModel.insert(j, { kind: d.kind, className: d.className });
            else if (cur !== j) slotModel.move(cur, j, 1);
        }
    }

    // ── continuous cursor tracking (icons + gaps, no dropout) ─────────────────
    property real cursorX: 0
    readonly property bool hovering: bandHover.hovered && row.magnify

    // Nearest app slot to the cursor, for the highlight + preview.
    readonly property int hoveredSlot: {
        if (!bandHover.hovered) return -1;
        let best = -1, bestD = 1e9;
        for (let i = 0; i < row.slots.length; ++i) {
            if (row.slots[i].kind !== "app") continue;
            const d = Math.abs(row.slotX(i) + row.baseSize / 2 - row.cursorX);
            if (d < bestD) { bestD = d; best = i; }
        }
        return best;
    }
    onHoveredSlotChanged: row.syncPreview()
    function syncPreview() {
        if (row.hoveredSlot < 0) {
            DockPreview.hoveredClass = "";
            return;
        }
        const cn = row.slots[row.hoveredSlot].className;
        const g = row.mapToGlobal(row.slotX(row.hoveredSlot) + row.baseSize / 2, row.baseSize / 2);
        DockPreview.gx = g.x;
        DockPreview.gy = g.y;
        DockPreview.edge = row.edge;
        DockPreview.margin = row.reservedDepth + 14;
        DockPreview.hoveredClass = Dock.countFor(cn) > 0 ? cn : "";
    }

    implicitWidth: restSpan
    implicitHeight: baseSize

    HoverHandler {
        id: bandHover
        onPointChanged: row.cursorX = point.position.x
    }

    Repeater {
        model: slotModel
        delegate: Item {
            id: slot
            required property int index
            required property string kind
            required property string className
            readonly property bool isSep: slot.kind === "sep"
            readonly property int count: slot.isSep ? 0 : Dock.countFor(slot.className)
            readonly property bool isActive: !slot.isSep && Dock.activeClass === slot.className
            readonly property color indColor: slot.isActive ? row.theme.seal : Theme.onSurface
            readonly property real mag: {
                if (slot.isSep || !row.hovering) return 1;
                const t = Math.max(0, 1 - Math.abs(row.slotX(slot.index) + row.baseSize / 2 - row.cursorX) / row.reach);
                return 1 + (row.maxScale - 1) * t * t;
            }

            // Reflow: when a neighbour opens/closes this island slides to its new
            // spot. `ready` gates out the first layout so islands do not fly in
            // from x=0 on load.
            property bool ready: false
            Component.onCompleted: slot.ready = true

            x: row.slotX(slot.index)
            y: 0
            width: row.slotW(slot.index)
            height: row.baseSize
            Behavior on x {
                enabled: row.animate && slot.ready
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }

            // ── separator ──
            Rectangle {
                visible: slot.isSep
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: 2
                height: Math.round(row.baseSize * 0.5)
                radius: 1
                color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.22)
            }

            // ── app island ──
            Item {
                id: content
                visible: !slot.isSep
                anchors.fill: parent

                // Pop-in: a freshly created island scales + fades up from the edge.
                // `shown` flips true on completion so the Behaviors animate the
                // entrance; under reduce-motion the Behaviors are off and it just
                // appears.
                property bool shown: false
                Component.onCompleted: content.shown = true
                opacity: content.shown ? 1 : 0
                scale: content.shown ? 1 : 0.3
                transformOrigin: row.edge === "bottom" ? Item.Bottom : Item.Top
                Behavior on opacity { enabled: row.animate; NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
                Behavior on scale { enabled: row.animate; NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

                transform: Scale {
                    origin.x: content.width / 2
                    origin.y: row.edge === "bottom" ? content.height : 0
                    xScale: slot.mag
                    yScale: slot.mag
                    Behavior on xScale { enabled: row.magnify; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                    Behavior on yScale { enabled: row.magnify; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }

                Rectangle {
                    id: pill
                    anchors.fill: parent
                    radius: row.islandRadius
                    readonly property real frostA: row.theme.dockFrost ? 0.68 : 0.94
                    color: slot.index === row.hoveredSlot
                        ? Qt.rgba(row.theme.paper.r + (1 - row.theme.paper.r) * 0.07,
                                  row.theme.paper.g + (1 - row.theme.paper.g) * 0.07,
                                  row.theme.paper.b + (1 - row.theme.paper.b) * 0.07, frostA)
                        : Qt.rgba(row.theme.paper.r, row.theme.paper.g, row.theme.paper.b, frostA)
                    border.width: row.theme.barBorderEnabled ? 1 : 0
                    border.color: row.theme.v2BarBorder

                    RectangularShadow {
                        anchors.fill: parent
                        radius: parent.radius
                        blur: 12; spread: 0
                        offset: Qt.vector2d(0, row.edge === "bottom" ? -2 : 2)
                        color: row.theme.v2BarShadow
                        visible: row.theme.dockShadow === true
                        z: -1
                    }
                }

                Image {
                    anchors.centerIn: parent
                    width: row.iconSize
                    height: row.iconSize
                    source: {
                        const i = Dock.iconFor(slot.className);
                        return i !== "" ? i : Quickshell.iconPath("application-x-executable", true);
                    }
                    sourceSize.width: Math.round(row.iconSize * row.maxScale)
                    sourceSize.height: Math.round(row.iconSize * row.maxScale)
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }

                Row {
                    spacing: 3
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: row.edge === "bottom" ? parent.bottom : undefined
                    anchors.top: row.edge === "top" ? parent.top : undefined
                    anchors.margins: 3
                    visible: slot.count >= 1 && slot.count <= 3
                    Repeater {
                        model: slot.count
                        delegate: Rectangle { width: 4; height: 4; radius: 2; color: slot.indColor }
                    }
                }
                Rectangle {
                    visible: slot.count >= 4
                    width: 14; height: 4; radius: 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: row.edge === "bottom" ? parent.bottom : undefined
                    anchors.top: row.edge === "top" ? parent.top : undefined
                    anchors.margins: 3
                    color: slot.indColor
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onSingleTapped: (eventPoint, button) => {
                        if (button === Qt.RightButton)
                            row.theme.updateDockPinned(slot.className, !row.pins.includes(slot.className));
                        else
                            Dock.activate(slot.className);
                    }
                }
            }
        }
    }
}
