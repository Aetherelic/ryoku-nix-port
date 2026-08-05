pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// The switcher body: a bottom-centre paper card in the desktop's own language
// (near-black paper, bone ink, a single red seal). A prominent Wallpapers |
// Themes tab splits the two so neither clutters the other; a control row filters
// by type and colour, sorts, switches layout, and takes a type-to-search; one
// focused view (filmstrip / carousel / grid) fills the stage. Arrows or a wheel
// move the focus, Enter or a click sets it, Tab flips tabs, Esc clears the search
// then closes. The backend (Walls / Themes / index.sh / ryoku-shell wallpaper)
// is untouched; this is only how it is shown.
Item {
    id: body

    required property real s
    required property bool active
    signal requestClose()

    // transient per-open state (the body unloads on close); the layout + sort
    // preference lives in the View singleton so it survives a reopen.
    property string mode: "walls"            // walls | themes
    property string typeFilter: "all"        // all | image | live
    property int colorFilter: -1             // -1 = every colour, else a group id
    property string search: ""
    property int selIndex: 0

    readonly property bool themesMode: body.mode === "themes"
    readonly property bool following: Themes.following

    function norm(t) { return String(t || "").toLowerCase(); }

    // walls: type + colour + search filter, then the chosen sort.
    readonly property var wallBase: {
        var out = [];
        var q = body.norm(body.search);
        var es = Walls.entries;
        for (var i = 0; i < es.length; i++) {
            var e = es[i];
            if (body.typeFilter !== "all" && e.type !== body.typeFilter) continue;
            if (body.colorFilter !== -1 && e.group !== body.colorFilter) continue;
            if (q.length > 0 && body.norm(e.name).indexOf(q) < 0) continue;
            out.push(e);
        }
        return out;
    }
    function sorted(a) {
        var v = View.sort;
        if (v === "recent") return a.slice().sort((x, y) => y.mtime - x.mtime);
        if (v === "name") return a.slice().sort((x, y) => body.norm(x.name).localeCompare(body.norm(y.name)));
        return a;   // colour: the scan's own hue order
    }
    readonly property var wallShown: body.sorted(body.wallBase)

    // themes: label search only (no colour / mtime axis).
    readonly property var themeShown: {
        var q = body.norm(body.search);
        if (q.length === 0) return Themes.themes;
        return Themes.themes.filter(t => body.norm(t.label).indexOf(q) >= 0);
    }

    readonly property var shown: body.themesMode ? body.themeShown : body.wallShown
    readonly property var selEntry: (body.selIndex >= 0 && body.selIndex < body.shown.length)
        ? body.shown[body.selIndex] : null
    readonly property string activeKey: (body.themesMode ? Themes.active : Walls.current) || ""

    // colour groups present under the current type filter (walls strip).
    readonly property var wallGroups: {
        var seen = ({});
        var es = Walls.entries;
        for (var i = 0; i < es.length; i++) {
            var e = es[i];
            if (body.typeFilter !== "all" && e.type !== body.typeFilter) continue;
            seen[e.group] = true;
        }
        var out = [];
        for (var g = 0; g < Colors.order.length; g++)
            if (seen[Colors.order[g]]) out.push(Colors.order[g]);
        return out;
    }

    // keep the focus in range as filters shrink the list.
    onShownChanged: if (body.selIndex >= body.shown.length)
        body.selIndex = Math.max(0, body.shown.length - 1)

    function setMode(m) {
        if (body.mode === m) return;
        body.mode = m; body.selIndex = 0; body.search = "";
    }
    function setType(t) {
        if (body.typeFilter === t) return;
        body.typeFilter = t; body.colorFilter = -1; body.selIndex = 0;
    }
    function setColor(g) {
        body.colorFilter = (body.colorFilter === g) ? -1 : g; body.selIndex = 0;
    }
    function moveSel(d) {
        if (body.shown.length === 0) return;
        body.selIndex = Math.max(0, Math.min(body.shown.length - 1, body.selIndex + d));
    }
    function apply(entry) {
        if (!entry) return;
        if (body.themesMode) {
            if (body.following) return;
            Themes.apply(entry.id);
        } else {
            Walls.apply(entry.path);
        }
    }
    function toggleFollow() {
        if (body.following) {
            if (body.selEntry) Themes.apply(body.selEntry.id);
        } else {
            Themes.apply("Wallpaper");
        }
    }

    readonly property int hostCols: (host.item && host.item.columns) ? host.item.columns : 1

    focus: true
    Component.onCompleted: forceActiveFocus()
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_Escape) {
            if (body.search.length > 0) body.search = "";
            else body.requestClose();
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            body.apply(body.selEntry);
        } else if (e.key === Qt.Key_Tab) {
            body.setMode(body.themesMode ? "walls" : "themes");
        } else if (e.key === Qt.Key_Left) {
            body.moveSel(-1);
        } else if (e.key === Qt.Key_Right) {
            body.moveSel(1);
        } else if (e.key === Qt.Key_Up) {
            body.moveSel(-body.hostCols);
        } else if (e.key === Qt.Key_Down) {
            body.moveSel(body.hostCols);
        } else if (e.key === Qt.Key_Backspace) {
            if (body.search.length > 0) body.search = body.search.slice(0, -1);
        } else if (e.text && e.text.length === 1 && e.text.charCodeAt(0) >= 32 && e.text.charCodeAt(0) !== 127
                   && (e.modifiers === Qt.NoModifier || e.modifiers === Qt.ShiftModifier)) {
            if (e.text !== " " || (body.search.length > 0 && !body.search.endsWith(" ")))
                body.search += e.text;
        } else {
            return;
        }
        e.accepted = true;
    }

    // ── a paper-and-ink chip: a hairline pill that lifts to the seal when on ──
    component Chip: Rectangle {
        id: chip
        property string label: ""
        property string glyph: ""
        property bool on: false
        signal clicked()
        implicitWidth: chipRow.implicitWidth + Math.round(22 * body.s)
        height: Math.round(30 * body.s)
        radius: Math.round(7 * body.s)
        color: chip.on ? Qt.rgba(Theme.seal.r, Theme.seal.g, Theme.seal.b, 0.12)
            : (chipHover.hovered ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06) : "transparent")
        border.width: 1
        border.color: chip.on ? Theme.seal : Theme.outline
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Math.round(6 * body.s)
            Text {
                visible: chip.glyph.length > 0
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                color: chip.on ? Theme.seal : Theme.onSurfaceVariant
                font.family: Theme.mono
                font.pixelSize: Math.round(12 * body.s)
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.on ? Theme.seal : Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Math.round(13 * body.s)
                font.weight: chip.on ? Font.DemiBold : Font.Medium
            }
        }
        HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: chip.clicked() }
    }

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Math.round(30 * body.s)
        width: Math.round(Math.min(parent.width * 0.92, 1720 * body.s))
        height: Math.round(Math.min(parent.height * 0.62, 800 * body.s))
        radius: Math.round(14 * body.s)
        color: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.8)
        border.width: 1
        border.color: Theme.outline
        readonly property int pad: Math.round(22 * body.s)

        // absorb clicks landing on empty card space so they never fall through
        // to the scrim and dismiss the picker; controls/tiles sit on top.
        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: false }

        // ── header: tabs (left) · type / follow (right) ──
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right }
            anchors.margins: card.pad
            height: Math.round(32 * body.s)

            Row {
                id: tabs
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * body.s)
                Chip { label: "Wallpapers"; on: !body.themesMode; onClicked: body.setMode("walls") }
                Chip { label: "Themes"; on: body.themesMode; onClicked: body.setMode("themes") }
            }
            Row {
                anchors.left: tabs.right
                anchors.leftMargin: Math.round(16 * body.s)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(7 * body.s)
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "" + body.shown.length
                    color: Theme.onSurface
                    font.family: Theme.fontPrimary
                    font.pixelSize: Math.round(20 * body.s)
                    font.weight: Font.DemiBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: body.themesMode ? "schemes"
                        : body.typeFilter === "image" ? "images"
                        : body.typeFilter === "live" ? "live" : "images + live"
                    color: Theme.onSurfaceVariant
                    font.family: Theme.fontPrimary
                    font.pixelSize: Math.round(12 * body.s)
                }
            }

            // walls: type filter
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * body.s)
                visible: !body.themesMode
                Chip { label: "All"; on: body.typeFilter === "all"; onClicked: body.setType("all") }
                Chip { label: "Images"; on: body.typeFilter === "image"; onClicked: body.setType("image") }
                Chip { label: "Live"; on: body.typeFilter === "live"; onClicked: body.setType("live") }
            }
            // themes: follow + default
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(6 * body.s)
                visible: body.themesMode
                Chip { label: "Follow wallpaper"; glyph: body.following ? "\u25c9" : "\u25cb"; on: body.following; onClicked: body.toggleFollow() }
                Chip { label: "Default"; on: Themes.active === "Default"; onClicked: Themes.apply("Default") }
            }
        }

        // ── control row: colour strip / hint (left) · search · sort · layout (right) ──
        Item {
            id: controls
            anchors { left: parent.left; right: parent.right; top: header.bottom }
            anchors.leftMargin: card.pad
            anchors.rightMargin: card.pad
            anchors.topMargin: Math.round(14 * body.s)
            height: Math.round(30 * body.s)

            ColorStrip {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - rightControls.width - Math.round(16 * body.s)
                height: parent.height
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

            Row {
                id: rightControls
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(8 * body.s)

                // search readout (fed by type-to-search)
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.round(150 * body.s)
                    height: Math.round(30 * body.s)
                    radius: Math.round(7 * body.s)
                    color: "transparent"
                    border.width: 1
                    border.color: body.search.length > 0 ? Theme.onSurfaceVariant : Theme.outline
                    Behavior on border.color { ColorAnimation { duration: Motion.fast } }
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: Math.round(9 * body.s)
                        anchors.right: parent.right
                        anchors.rightMargin: Math.round(9 * body.s)
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(6 * body.s)
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u2315"
                            color: Theme.onSurfaceVariant
                            font.family: Theme.mono
                            font.pixelSize: Math.round(13 * body.s)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - Math.round(22 * body.s)
                            elide: Text.ElideRight
                            text: body.search.length > 0 ? body.search : "Type to search"
                            color: body.search.length > 0 ? Theme.onSurface : Theme.outline
                            font.family: Theme.fontPrimary
                            font.pixelSize: Math.round(13 * body.s)
                        }
                    }
                }

                Chip {
                    glyph: "\u21c5"
                    label: View.sortLabel(View.sort)
                    visible: !body.themesMode
                    onClicked: View.cycleSort()
                }
                Chip {
                    glyph: "\u25a4"
                    label: View.layoutLabel(View.layout)
                    onClicked: View.cycleLayout()
                }
            }
        }

        // ── stage: the active layout ──
        Item {
            id: stage
            anchors {
                left: parent.left; right: parent.right
                top: controls.bottom; bottom: footer.top
                topMargin: Math.round(14 * body.s)
                bottomMargin: Math.round(10 * body.s)
            }
            visible: body.shown.length > 0

            Loader {
                id: host
                anchors.fill: parent
                sourceComponent: View.layout === "carousel" ? carouselC
                    : View.layout === "grid" ? gridC : filmstripC
                onItemChanged: if (item) { item.selIndex = Qt.binding(() => body.selIndex); }
            }
            Component {
                id: filmstripC
                LayoutFilmstrip {
                    s: body.s; model: body.shown; kind: body.themesMode ? "theme" : "wall"
                    bg: Theme.surface; active: body.active; activeKey: body.activeKey
                    interactive: !(body.themesMode && body.following)
                    onFocusIndex: (i) => body.selIndex = i
                    onChosen: (i) => body.apply(body.shown[i])
                }
            }
            Component {
                id: carouselC
                LayoutCarousel {
                    s: body.s; model: body.shown; kind: body.themesMode ? "theme" : "wall"
                    bg: Theme.surface; active: body.active; activeKey: body.activeKey
                    interactive: !(body.themesMode && body.following)
                    onFocusIndex: (i) => body.selIndex = i
                    onChosen: (i) => body.apply(body.shown[i])
                }
            }
            Component {
                id: gridC
                LayoutGrid {
                    s: body.s; model: body.shown; kind: body.themesMode ? "theme" : "wall"
                    bg: Theme.surface; active: body.active; activeKey: body.activeKey
                    interactive: !(body.themesMode && body.following)
                    onFocusIndex: (i) => body.selIndex = i
                    onChosen: (i) => body.apply(body.shown[i])
                }
            }
        }

        // empty / loading
        Text {
            anchors.centerIn: parent
            visible: body.shown.length === 0
            horizontalAlignment: Text.AlignHCenter
            text: body.themesMode
                ? (Themes.loading ? "Reading colour schemes" : (body.search.length > 0 ? "No schemes match \u201c" + body.search + "\u201d" : "No colour schemes"))
                : Walls.loading ? "Reading wallpapers"
                : (body.search.length > 0 ? "No wallpapers match \u201c" + body.search + "\u201d"
                    : (body.colorFilter !== -1 || body.typeFilter !== "all") ? "Nothing in this filter"
                    : "No wallpapers in ~/Pictures/Wallpapers")
            color: Theme.onSurfaceVariant
            font.family: Theme.fontPrimary
            font.pixelSize: Math.round(15 * body.s)
        }

        // ── footer: the pick + hints ──
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
                    ? (body.selEntry ? (body.selEntry.label + (body.following ? "   \u00b7 following wallpaper" : "")) : "Pick a scheme")
                    : (body.selEntry ? (body.selEntry.name + "   " + (body.selEntry.type === "live" ? "Live" : "Image") + " \u00b7 " + Colors.names[body.selEntry.group]) : "Browse wallpapers")
                color: Theme.onSurfaceVariant
                font.family: Theme.fontPrimary
                font.pixelSize: Math.round(13 * body.s)
            }
            Text {
                id: hint
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: (body.selIndex + 1) + " / " + body.shown.length + "    \u2190\u2192 browse \u00b7 Enter set \u00b7 Tab " + (body.themesMode ? "wallpapers" : "themes") + " \u00b7 Esc close"
                color: Theme.outline
                font.family: Theme.fontPrimary
                font.pixelSize: Math.round(12 * body.s)
            }
        }
    }
}
