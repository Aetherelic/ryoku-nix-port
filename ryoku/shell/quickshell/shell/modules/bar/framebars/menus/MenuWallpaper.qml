pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../../../services/lib/WallColors.js" as WallColors

// The wallpaper section of the frame blob menu: two endless belts of cached
// image + live-video thumbnails that idle-drift in opposite directions (the top
// rightwards, the bottom leftwards) and speed up on a scroll, with type (images
// / live) and colour filters above. The source is index.sh (one cached thumbnail, dominant-hue
// reading and muted preview loop per wallpaper, images and videos alike), the
// same index the standalone switcher reads, so a pick shares the transition,
// palette and state. A single click applies through the daemon and never
// dismisses the menu (single-click activate).
Item {
    id: root

    property real s: 1
    property bool open: false
    signal requestClose()

    // Reading + caching is the resident WallIndex's job; these mirror its state
    // so the menu opens with tiles already in hand instead of a fresh index pass.
    readonly property var entries: WallIndex.entries
    readonly property bool loading: WallIndex.loading
    property int colorFilter: -1        // -1 = every colour, else a WallColors group id
    property string typeFilter: "all"   // all | image | live
    property var hoverEntry: null

    // entries under the current type + colour filter (already colour-sorted).
    readonly property var shown: {
        var out = [];
        for (var i = 0; i < entries.length; i++) {
            var e = entries[i];
            if (root.typeFilter !== "all" && e.type !== root.typeFilter)
                continue;
            if (root.colorFilter !== -1 && e.group !== root.colorFilter)
                continue;
            out.push(e);
        }
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
    // colour groups present under the current type filter, in rainbow order.
    readonly property var groups: {
        var seen = ({});
        for (var i = 0; i < entries.length; i++) {
            if (root.typeFilter !== "all" && entries[i].type !== root.typeFilter)
                continue;
            seen[entries[i].group] = true;
        }
        var out = [];
        for (var g = 0; g < WallColors.order.length; g++)
            if (seen[WallColors.order[g]])
                out.push(WallColors.order[g]);
        return out;
    }

    // A menu open nudges the resident index to pick up any wallpaper added since
    // it last ran; it is a no-op when the set is unchanged, so a reopen never
    // churns the belts.
    onOpenChanged: if (root.open) WallIndex.refresh()
    Component.onCompleted: WallIndex.refresh()

    // the wallpaper on screen (on-air dot), from the resident index.
    readonly property string current: WallIndex.current

    function apply(path) { WallIndex.apply(path); }

    // switching type clears the colour pick, so the swatch strip re-reads for the
    // newly shown set instead of stranding a colour that type no longer has.
    function setType(t) {
        if (root.typeFilter === t)
            return;
        root.typeFilter = t;
        root.colorFilter = -1;
        root.hoverEntry = null;
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
                text: root.shown.length + " " + (root.typeFilter === "live" ? qsTr("live") : root.typeFilter === "image" ? qsTr("images") : root.hasLive ? qsTr("images + live") : qsTr("images"))
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
            }
        }

        // type filter: All / Images / Live, shown only when live walls exist.
        Row {
            spacing: 7
            visible: root.hasLive
            Repeater {
                model: [{ k: "all", t: qsTr("All") }, { k: "image", t: qsTr("Images") }, { k: "live", t: qsTr("Live") }]
                delegate: Rectangle {
                    id: tc
                    required property var modelData
                    readonly property bool on: root.typeFilter === tc.modelData.k
                    width: tcTxt.implicitWidth + 18
                    height: 26
                    radius: 6
                    color: tc.on ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12) : "transparent"
                    border.width: Theme.borderWidth
                    border.color: tc.on ? Theme.primary : Theme.outline
                    Text {
                        id: tcTxt
                        anchors.centerIn: parent
                        text: tc.modelData.t
                        color: tc.on ? Theme.primary : Theme.onSurfaceVariant
                        font.family: Theme.fontPrimary
                        font.pixelSize: 12
                        font.weight: tc.on ? Font.DemiBold : Font.Medium
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setType(tc.modelData.k) }
                }
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
                : ((root.colorFilter !== -1 || root.typeFilter !== "all") ? qsTr("Nothing in this filter")
                : qsTr("No wallpapers available"))
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontMd
        }
    }
}
