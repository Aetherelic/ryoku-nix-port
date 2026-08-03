pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// The switcher body: a rounded bottom-centre box in the shell's Material style,
// with a mode switch (Wallpapers / Color scheme) in the header, two endless
// belts below (the top drifts right, the bottom drifts left), a filter/hint
// strip between them, and a footer. In Wallpapers mode the belts carry cached
// image + live tiles and the strip filters by colour; in Color-scheme mode they
// carry the theme cards, with a Follow-wallpaper toggle and a Default button in
// the corner. The belts idle-drift; a scroll pushes them faster and they ease
// back. Hover a tile to light it, click or Enter to set it, Esc to close.
Item {
    id: body

    required property real s
    required property bool active           // the surface is open (drives the drift)
    signal requestClose()

    property string mode: "walls"           // walls | themes
    property string typeFilter: "all"       // all | image | live  (walls)
    property int colorFilter: -1            // -1 = every colour, else a Colors group id
    property var hoverEntry: null
    property int kbRow: 0                    // which belt Enter picks from when not hovering

    readonly property bool themesMode: body.mode === "themes"
    readonly property bool following: Themes.following

    // wallpaper entries under the current type + colour filter, colour-sorted.
    readonly property var wallShown: {
        var out = [];
        var es = Walls.entries;
        for (var i = 0; i < es.length; i++) {
            var e = es[i];
            if (body.typeFilter !== "all" && e.type !== body.typeFilter)
                continue;
            if (body.colorFilter !== -1 && e.group !== body.colorFilter)
                continue;
            out.push(e);
        }
        return out;
    }
    // static themes only; the two dynamic variants are the toggle + Default button.
    readonly property var themeShown: Themes.themes

    readonly property var shown: body.themesMode ? body.themeShown : body.wallShown
    readonly property var topCells: shown.filter((e, i) => i % 2 === 0)
    readonly property var bottomCells: shown.filter((e, i) => i % 2 === 1)

    // colour groups present under the current type filter (walls colour strip).
    readonly property var wallGroups: {
        var seen = ({});
        var es = Walls.entries;
        for (var i = 0; i < es.length; i++) {
            var e = es[i];
            if (body.typeFilter !== "all" && e.type !== body.typeFilter)
                continue;
            seen[e.group] = true;
        }
        var out = [];
        for (var g = 0; g < Colors.order.length; g++)
            if (seen[Colors.order[g]])
                out.push(Colors.order[g]);
        return out;
    }

    function keyOf(e) { return e ? ((body.themesMode ? e.id : e.path) || "") : ""; }
    readonly property string highlightKey: keyOf(body.hoverEntry)
    readonly property string activeKey: (body.themesMode ? Themes.active : Walls.current) || ""

    readonly property var selEntry: hoverEntry ? hoverEntry
        : (kbRow === 0 ? topRow.centerEntry : bottomRow.centerEntry)

    function setMode(m) {
        if (body.mode === m)
            return;
        body.mode = m;
        body.hoverEntry = null;
    }
    function setType(t) {
        if (body.typeFilter === t)
            return;
        body.typeFilter = t;
        body.colorFilter = -1;
        body.hoverEntry = null;
    }
    function setColor(g) {
        body.colorFilter = (body.colorFilter === g) ? -1 : g;
        body.hoverEntry = null;
    }
    // Apply the pick live and stay open (like the shell's menu: click-activate,
    // Esc or a click-out dismisses), so a wallpaper and a scheme can be set in
    // one visit. Theme picks are inert while following the wallpaper.
    function apply(entry) {
        if (!entry)
            return;
        if (body.themesMode) {
            if (body.following)
                return;
            Themes.apply(entry.id);
        } else {
            Walls.apply(entry.path);
        }
    }
    // Follow-wallpaper toggle: on follows the wallpaper palette; off commits the
    // centred theme so the change sticks and the belt re-enables.
    function toggleFollow() {
        if (body.following) {
            var e = topRow.centerEntry || bottomRow.centerEntry;
            if (e)
                Themes.apply(e.id);
        } else {
            Themes.apply("Wallpaper");
        }
    }

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape)
            body.requestClose();
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
            body.apply(body.selEntry);
        else if (e.key === Qt.Key_Tab)
            body.setMode(body.themesMode ? "walls" : "themes");
        else if (e.key === Qt.Key_Right) {
            topRow.boostBy(760);
            bottomRow.boostBy(-760);
        } else if (e.key === Qt.Key_Left) {
            topRow.boostBy(-760);
            bottomRow.boostBy(760);
        } else if (e.key === Qt.Key_Up)
            body.kbRow = 0;
        else if (e.key === Qt.Key_Down)
            body.kbRow = 1;
        else
            return;
        e.accepted = true;
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(30 * body.s)
        width: Math.round(Math.min(parent.width * 0.9, 1680 * body.s))
        height: Math.round(Math.min(parent.height * 0.58, 760 * body.s))
        radius: Theme.radiusWindow
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.outline

        readonly property int pad: Math.round(22 * body.s)

        // one segmented-control pill, reused for the mode switch and the type filter.
        component Segment: Rectangle {
            id: seg
            property string label: ""
            property bool on: false
            signal clicked()
            implicitWidth: segTxt.implicitWidth + Math.round(26 * body.s)
            height: Math.round(32 * body.s)
            radius: Math.round(8 * body.s)
            color: seg.on ? Theme.frameBg : "transparent"
            border.width: Theme.borderWidth
            border.color: seg.on ? Theme.primary : Theme.outline
            Text {
                id: segTxt
                anchors.centerIn: parent
                text: seg.label
                color: seg.on ? Theme.primary : Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Math.round(13 * body.s)
                font.weight: seg.on ? Font.DemiBold : Font.Medium
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.clicked() }
        }

        // ---- header ----
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: card.pad
            height: Math.round(34 * body.s)

            // mode switch (left).
            Row {
                id: modeSwitch
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * body.s)
                Segment { label: "Wallpapers"; on: !body.themesMode; onClicked: body.setMode("walls") }
                Segment { label: "Color scheme"; on: body.themesMode; onClicked: body.setMode("themes") }
            }

            // count (next to the mode switch).
            Row {
                anchors.left: modeSwitch.right
                anchors.leftMargin: Math.round(20 * body.s)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(8 * body.s)
                Text {
                    id: num
                    text: "" + body.shown.length
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: Math.round(22 * body.s)
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.baseline: num.baseline
                    text: body.themesMode ? "schemes"
                        : body.typeFilter === "image" ? "images"
                        : body.typeFilter === "live" ? "live"
                        : "images + live"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: Math.round(13 * body.s)
                }
            }

            // walls: type filter (right).
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * body.s)
                visible: !body.themesMode
                Segment { label: "All"; on: body.typeFilter === "all"; onClicked: body.setType("all") }
                Segment { label: "Images"; on: body.typeFilter === "image"; onClicked: body.setType("image") }
                Segment { label: "Live"; on: body.typeFilter === "live"; onClicked: body.setType("live") }
            }

            // themes: Follow-wallpaper toggle + Default button (right corner).
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(8 * body.s)
                visible: body.themesMode

                Rectangle {
                    id: followBtn
                    readonly property bool on: body.following
                    width: followRow.implicitWidth + Math.round(24 * body.s)
                    height: Math.round(32 * body.s)
                    radius: Math.round(8 * body.s)
                    color: followBtn.on ? Theme.frameBg : "transparent"
                    border.width: Theme.borderWidth
                    border.color: followBtn.on ? Theme.primary : Theme.outline
                    Row {
                        id: followRow
                        anchors.centerIn: parent
                        spacing: Math.round(8 * body.s)
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.round(9 * body.s)
                            height: width
                            radius: width / 2
                            color: followBtn.on ? Theme.primary : Theme.outline
                        }
                        Text {
                            text: "Follow wallpaper"
                            color: followBtn.on ? Theme.primary : Theme.onSurfaceVariant
                            font.family: Theme.fontPrimary
                            font.pixelSize: Math.round(13 * body.s)
                            font.weight: followBtn.on ? Font.DemiBold : Font.Medium
                        }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: body.toggleFollow() }
                }

                Segment { label: "Default"; on: Themes.active === "Default"; onClicked: Themes.apply("Default") }
            }
        }

        // ---- colour strip (walls) / hint (themes) ----
        Item {
            id: strip
            anchors { left: parent.left; right: parent.right; top: header.bottom }
            anchors.leftMargin: card.pad
            anchors.rightMargin: card.pad
            anchors.topMargin: Math.round(16 * body.s)
            height: Math.round(24 * body.s)

            ColorStrip {
                anchors.fill: parent
                visible: !body.themesMode
                s: body.s
                groups: body.wallGroups
                selected: body.colorFilter
                onPicked: (g) => body.setColor(g)
            }

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                visible: body.themesMode
                text: body.following
                    ? "Following the wallpaper palette \u2014 turn off Follow to pick a scheme"
                    : "Pick a scheme to apply it live"
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Math.round(13 * body.s)
            }
        }

        // ---- the two belts ----
        Item {
            id: rows
            anchors {
                left: parent.left; right: parent.right
                top: strip.bottom; bottom: footer.top
                topMargin: Math.round(16 * body.s)
                bottomMargin: Math.round(12 * body.s)
            }
            visible: body.shown.length > 0

            readonly property int rowGap: Math.round(18 * body.s)
            readonly property real rowH: (height - rowGap) / 2
            readonly property real cH: body.themesMode
                ? Math.max(150 * body.s, Math.min(228 * body.s, rowH - 14 * body.s))
                : Math.max(120 * body.s, Math.min(240 * body.s, rowH - 14 * body.s))
            readonly property real cW: body.themesMode ? Math.round(cH * 0.82) : Math.round(cH * 1.55)
            readonly property int cGap: Math.round(14 * body.s)
            property bool scrolling: false

            Belt {
                id: topRow
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: rows.rowH
                s: body.s
                dir: 1
                topRow: true
                kind: body.themesMode ? "theme" : "wall"
                cells: body.topCells
                cellW: rows.cW
                cellH: rows.cH
                gap: rows.cGap
                bg: Theme.surface
                running: body.active
                hovering: rowsHover.hovered
                scrollHold: rows.scrolling
                highlightKey: body.highlightKey
                activeKey: body.activeKey
                frozen: body.themesMode && body.following
                onEntered: (e) => body.hoverEntry = e
                onChosen: (e) => body.apply(e)
            }
            Belt {
                id: bottomRow
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: rows.rowH
                s: body.s
                dir: -1
                topRow: false
                kind: body.themesMode ? "theme" : "wall"
                cells: body.bottomCells
                cellW: rows.cW
                cellH: rows.cH
                gap: rows.cGap
                bg: Theme.surface
                running: body.active
                hovering: rowsHover.hovered
                scrollHold: rows.scrolling
                highlightKey: body.highlightKey
                activeKey: body.activeKey
                frozen: body.themesMode && body.following
                onEntered: (e) => body.hoverEntry = e
                onChosen: (e) => body.apply(e)
            }

            // scroll pushes both belts faster (they ease back to the idle drift).
            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (e) => {
                    var f = e.angleDelta.y * 3.2;
                    topRow.boostBy(f);
                    bottomRow.boostBy(-f);
                    rows.scrolling = true;
                    scrollCool.restart();
                }
            }
            Timer { id: scrollCool; interval: 450; onTriggered: rows.scrolling = false }
            HoverHandler {
                id: rowsHover
                onHoveredChanged: if (!hovered) body.hoverEntry = null
            }

            // faint guide marking the tile Enter picks when nothing is hovered.
            Rectangle {
                visible: !body.hoverEntry
                width: Math.round(30 * body.s)
                height: Math.round(3 * body.s)
                radius: height / 2
                color: Theme.primary
                opacity: 0.7
                x: (rows.width - width) / 2
                y: body.kbRow === 0
                    ? topRow.y + topRow.height - height / 2
                    : bottomRow.y + bottomRow.height - height / 2
            }
        }

        // empty / loading state.
        Text {
            anchors.centerIn: parent
            visible: body.shown.length === 0
            text: body.themesMode
                ? (Themes.loading ? "Reading colour schemes" : "No colour schemes")
                : Walls.loading ? "Reading wallpapers"
                : (body.colorFilter !== -1 || body.typeFilter !== "all" ? "Nothing in this filter"
                : "No wallpapers in ~/Pictures/Wallpapers")
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: Math.round(15 * body.s)
        }

        // ---- footer ----
        Item {
            id: footer
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.margins: card.pad
            height: Math.round(20 * body.s)

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - hint.width - Math.round(20 * body.s)
                elide: Text.ElideRight
                text: body.themesMode
                    ? (body.selEntry
                        ? (body.selEntry.label + (body.following ? "   \u00b7 following wallpaper" : (body.hoverEntry ? "" : "   \u00b7 centre")))
                        : "Scroll to browse schemes, click one to apply it")
                    : (body.selEntry
                        ? (body.selEntry.name + "   " + (body.selEntry.type === "live" ? "Live" : "Image") + " \u00b7 " + Colors.names[body.selEntry.group] + (body.hoverEntry ? "" : "   \u00b7 centre"))
                        : "Scroll to browse, hover a tile to set it")
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Math.round(13 * body.s)
            }
            Text {
                id: hint
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: body.themesMode ? "Click apply \u00b7 Tab wallpapers \u00b7 Esc close" : "Enter set \u00b7 Tab schemes \u00b7 Esc close"
                color: Theme.outline
                font.family: Theme.fontPrimary
                font.pixelSize: Math.round(12 * body.s)
            }
        }
    }
}
