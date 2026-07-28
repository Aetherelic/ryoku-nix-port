pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"
import "WallColors.js" as WallColors

// The wallpaper section of the frame blob menu: two endless belts of cached
// image + live-video thumbnails that idle-drift in opposite directions (the top
// rightwards, the bottom leftwards) and speed up on a scroll, with a colour
// filter above. The source is index.sh (one cached thumbnail, dominant-hue
// reading and muted preview loop per wallpaper, images and videos alike), the
// same index the standalone switcher reads, so a pick shares the transition,
// palette and state. A single click applies through the daemon and never
// dismisses the menu (single-click activate).
Item {
    id: root

    property real s: 1
    property bool open: false
    signal requestClose()

    // index.sh path = RYOKU_SHELL_DIR in dev, else the installed quickshell tree.
    readonly property string shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string script: (shellDir && shellDir.length > 0)
        ? shellDir + "/quickshell/wallpaper/index.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/wallpaper/index.sh"

    property var entries: []
    property bool loading: false
    property int colorFilter: -1        // -1 = every colour, else a WallColors group id
    property var hoverEntry: null

    // entries under the current colour filter (already colour-sorted by index).
    readonly property var shown: {
        var out = [];
        for (var i = 0; i < entries.length; i++)
            if (colorFilter === -1 || entries[i].group === colorFilter)
                out.push(entries[i]);
        return out;
    }
    readonly property var topCells: shown.filter((e, i) => i % 2 === 0)
    readonly property var bottomCells: shown.filter((e, i) => i % 2 === 1)
    readonly property bool hasLive: {
        for (var i = 0; i < entries.length; i++)
            if (entries[i].type === "live")
                return true;
        return false;
    }
    // colour groups present, in rainbow order (neutral last).
    readonly property var groups: {
        var seen = ({});
        for (var i = 0; i < entries.length; i++)
            seen[entries[i].group] = true;
        var out = [];
        for (var g = 0; g < WallColors.order.length; g++)
            if (seen[WallColors.order[g]])
                out.push(WallColors.order[g]);
        return out;
    }

    function refresh() {
        if (indexProc.running)
            return;
        root.loading = true;
        indexProc.running = true;
    }
    onOpenChanged: if (root.open) root.refresh()
    Component.onCompleted: root.refresh()

    Process {
        id: indexProc
        command: ["sh", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t");
                    if (p.length < 6)
                        continue;
                    var hue = parseFloat(p[4]) || 0;
                    var sat = parseFloat(p[5]) || 0;
                    var path = p[2];
                    out.push({
                        type: p[0],
                        mtime: parseFloat(p[1]) || 0,
                        path: path,
                        name: path.substring(path.lastIndexOf("/") + 1),
                        thumb: p[3],
                        preview: p.length > 6 ? p[6] : "",
                        hue: hue,
                        sat: sat,
                        group: WallColors.bucket(hue, sat)
                    });
                }
                out.sort(function (a, b) {
                    var ga = a.group === 99 ? 100 : a.group;
                    var gb = b.group === 99 ? 100 : b.group;
                    if (ga !== gb)
                        return ga - gb;
                    return b.sat - a.sat;
                });
                root.entries = out;
                root.loading = false;
            }
        }
    }

    // the wallpaper on screen (on-air dot), watched so a pick lights its tile.
    readonly property string current: stateView.text().trim()
    FileView {
        id: stateView
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku-wallpaper"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    function apply(path) {
        if (path && path.length > 0)
            Quickshell.execDetached(["ryoku-shell", "wallpaper", "set", path]);
    }

    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 14

        // header: title + count.
        Row {
            spacing: 10
            Text {
                id: title
                text: qsTr("Wallpaper")
                color: Theme.onSurface
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontXl
                font.weight: Font.Bold
            }
            Text {
                anchors.baseline: title.baseline
                text: root.shown.length + (root.hasLive ? qsTr(" images + live") : qsTr(" images"))
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
            }
        }

        // colour filter: an ALL chip then one rounded swatch per hue group present.
        Row {
            spacing: 7
            visible: root.groups.length > 0

            Rectangle {
                id: allChip
                readonly property bool on: root.colorFilter === -1
                width: allTxt.implicitWidth + 18
                height: 26
                radius: 6
                color: allChip.on ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                border.width: Theme.borderWidth
                border.color: allChip.on ? Theme.primary : Theme.outline
                Text {
                    id: allTxt
                    anchors.centerIn: parent
                    text: qsTr("All")
                    color: allChip.on ? Theme.primary : Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: 12
                    font.weight: allChip.on ? Font.DemiBold : Font.Medium
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.colorFilter = -1 }
            }

            Repeater {
                model: root.groups
                delegate: Rectangle {
                    id: sw
                    required property var modelData
                    readonly property bool on: root.colorFilter === sw.modelData
                    readonly property var hsl: WallColors.swatchHsl(sw.modelData)
                    width: 26
                    height: 26
                    radius: 6
                    color: hh.hovered ? Qt.hsla(sw.hsl[0], sw.hsl[1], Math.min(1, sw.hsl[2] + 0.08), 1)
                        : Qt.hsla(sw.hsl[0], sw.hsl[1], sw.hsl[2], 1)
                    opacity: (root.colorFilter !== -1 && !sw.on) ? 0.45 : 1
                    border.width: sw.on ? 2 : 1
                    border.color: sw.on ? Theme.primary : Qt.rgba(0, 0, 0, 0.35)
                    Behavior on opacity { NumberAnimation { duration: Motion.thumbHover } }
                    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.colorFilter = (root.colorFilter === sw.modelData ? -1 : sw.modelData) }
                }
            }
        }

        // the two opposite-drifting belts.
        Item {
            id: belts
            width: parent.width
            readonly property int rowGap: 16
            readonly property real rowH: 150
            readonly property real cH: rowH - 6
            readonly property real cW: Math.round(cH * 1.55)
            readonly property int cGap: 14
            height: root.shown.length > 0 ? (rowH * 2 + rowGap) : 0
            visible: root.shown.length > 0
            property bool scrolling: false

            WallBelt {
                id: topRow
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: belts.rowH
                s: root.s
                dir: 1
                cells: root.topCells
                cellW: belts.cW
                cellH: belts.cH
                gap: belts.cGap
                bg: Theme.surface
                current: root.current
                running: root.open
                hovering: beltsHover.hovered
                scrollHold: belts.scrolling
                highlightKey: root.hoverEntry ? root.hoverEntry.path : ""
                onEntered: (e) => root.hoverEntry = e
                onChosen: (e) => root.apply(e.path)
            }
            WallBelt {
                id: bottomRow
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: belts.rowH
                s: root.s
                dir: -1
                cells: root.bottomCells
                cellW: belts.cW
                cellH: belts.cH
                gap: belts.cGap
                bg: Theme.surface
                current: root.current
                running: root.open
                hovering: beltsHover.hovered
                scrollHold: belts.scrolling
                highlightKey: root.hoverEntry ? root.hoverEntry.path : ""
                onEntered: (e) => root.hoverEntry = e
                onChosen: (e) => root.apply(e.path)
            }

            // scroll pushes both belts faster (they ease back to the idle drift).
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => {
                    var f = e.angleDelta.y * 3.2;
                    topRow.boostBy(f);
                    bottomRow.boostBy(-f);
                    belts.scrolling = true;
                    scrollCool.restart();
                }
            }
            Timer { id: scrollCool; interval: 450; onTriggered: belts.scrolling = false }
            HoverHandler {
                id: beltsHover
                onHoveredChanged: if (!hovered) root.hoverEntry = null
            }
        }

        // empty / loading state.
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.shown.length === 0
            text: root.loading ? qsTr("Reading wallpapers")
                : (root.colorFilter !== -1 ? qsTr("Nothing in this colour")
                : qsTr("No wallpapers available"))
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontMd
        }
    }
}
