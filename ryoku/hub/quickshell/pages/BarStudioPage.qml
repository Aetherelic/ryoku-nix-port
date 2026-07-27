pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../barstudio"
import Ryoku.FrameBars
import "../barstudio/BarStudioModel.js" as Model

// Bar Studio (DESKTOP). The frame's own studio: the chrome keys the shell
// reads from shell.json (draw toggle, radii, border, opacity, interface
// font), the four bounded rails and their widget zones, the bounded menus,
// the two preserved frame surfaces, and the catalogue that bounds what can be
// saved. Everything stages through the shared draft (hub.edit); the shell's
// ledger shows the pending write and its action bar owns Save and Revert,
// like every other framed page.
Item {
    id: page
    property var hub

    // which rail is on the bench
    property string edge: "left"

    // Always normalize what the editor reads. A stored value that lost a subtree
    // (a legacy config, a hand edit, a partial write from any surface) would
    // otherwise leave menus/surfaces undefined: the menu editor would throw, every
    // menu edit would be a silent no-op, and a rail edit would clone the gap
    // straight back to disk. Normalizing restores every subtree from the schema
    // default, so the editor is always whole and the first staged edit heals the
    // store. The probe harness's bare hub has no val(); normalize(null) still
    // yields a complete default, so the page always loads.
    readonly property var config: {
        const v = page.hub && page.hub.val ? page.hub.val("frameBars") : null;
        return FrameBars.normalize(v, BarCatalog, MenuCatalog);
    }
    // the on-disk config, normalized to the same shape so the changed marks and
    // struck defaults compare like against like.
    readonly property var committedBars: {
        const c = page.hub && page.hub.committed ? page.hub.committed.frameBars : null;
        return c ? FrameBars.normalize(c, BarCatalog, MenuCatalog) : null;
    }

    // Stage AND apply: edits ride the shared draft like every page, and the
    // hub's stageLive coalesces a settings.patch to the daemon so the running
    // desktop repaints as you work. The probe harness's bare hub has neither;
    // fall back so the page still loads and stages inertly.
    function stage(next) {
        if (!next || !page.hub) return;
        if (page.hub.stageLive) page.hub.stageLive("frameBars", next);
        else if (page.hub.edit) page.hub.edit("frameBars", next);
    }

    // The frame chrome keys live beside frameBars in shell.json: the running
    // shell reads them for the frame's draw toggle, corner radii, border,
    // window opacity and interface font, so they belong on the frame's own
    // studio and stage through the same draft.
    function fval(key, fall) {
        if (!page.hub || !page.hub.val) return fall;
        const v = page.hub.val(key);
        return v === undefined || v === null ? fall : v;
    }
    function fnum(key, fall) {
        const v = Number(page.fval(key, fall));
        return isFinite(v) ? v : fall;
    }
    function fedit(key, value) {
        if (!page.hub) return;
        if (page.hub.stageLive) page.hub.stageLive(key, value);
        else if (page.hub.edit) page.hub.edit(key, value);
    }
    function fwas(key) {
        return page.hub && page.hub.committed ? page.hub.committed[key] : undefined;
    }

    CatalogLabels { id: labels }

    // ── head: the eyebrow band, the title, the blurb ─────────────────────────
    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: Tokens.s2

        Item {
            width: parent.width
            height: 14
            Row {
                id: ebrow
                spacing: Tokens.s2
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { width: 16; height: 1; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "力"; color: Tokens.ink; font.family: Tokens.jp
                    font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: qsTr("DESKTOP"); color: Tokens.inkMuted; font.family: Tokens.ui
                    font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Rectangle {
                anchors { left: ebrow.right; right: crossMark.left; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: Tokens.s3; anchors.rightMargin: Tokens.s3
                height: 1; color: Tokens.lineSoft
            }
            Text {
                id: crossMark
                anchors { right: slashMark.left; rightMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                text: "+"; color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: 10
            }
            Text {
                id: slashMark
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "///"; color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: 10
            }
        }
        Text {
            text: qsTr("Bar Studio")
            color: Tokens.ink
            font.family: Tokens.display
            font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 720)
            text: qsTr("The frame's chrome, its four rails and their widget zones, the bounded menus, and the preserved surfaces.")
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
            wrapMode: Text.WordWrap
        }
    }

    // ── the sheet: titled sections in one scroll ─────────────────────────────
    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.s5 }
        contentWidth: width
        contentHeight: col.height + Tokens.s5
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: flick.width - 14
            spacing: Tokens.s5

            // ── FRAME: the chrome the shell draws around the desktop ─────────
            Section {
                id: frameSect
                width: col.width
                title: qsTr("FRAME")

                Cell {
                    width: frameSect.span(12)
                    controlWidth: 200
                    label: qsTr("Frame style")
                    value: labels.style(page.config.style)
                    def: page.committedBars ? labels.style(page.committedBars.style) : ""
                    changed: !!page.committedBars && page.config.style !== page.committedBars.style
                    desc: qsTr("The construction the rails and menus are drawn in.")
                    source: "shell.json"
                    Seg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: [labels.style("slate-frame"), labels.style("ryoku-frame")]
                        current: labels.style(page.config.style)
                        onChose: label => page.stage(Model.setStyle(page.config, label === labels.style("ryoku-frame") ? "ryoku-frame" : "slate-frame"))
                    }
                }
                Cell {
                    width: frameSect.span(4)
                    controlWidth: 54
                    label: qsTr("Draw frame")
                    value: page.fval("frameEnabled", true) ? qsTr("ON") : qsTr("OFF")
                    def: page.fwas("frameEnabled") === undefined ? "" : (page.fwas("frameEnabled") ? qsTr("ON") : qsTr("OFF"))
                    changed: page.fwas("frameEnabled") !== undefined && !!page.fval("frameEnabled", true) !== !!page.fwas("frameEnabled")
                    desc: qsTr("Draw the bounded frame around the desktop at all.")
                    source: "shell.json"
                    Sw {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: !!page.fval("frameEnabled", true)
                        onToggled: value => page.fedit("frameEnabled", value)
                    }
                }
                Cell {
                    width: frameSect.span(4)
                    controlWidth: 58
                    label: qsTr("Widget radius")
                    unit: "px"
                    value: String(page.fnum("roundness", 10))
                    def: page.fwas("roundness") === undefined ? "" : String(page.fwas("roundness"))
                    changed: page.fwas("roundness") !== undefined && page.fnum("roundness", 10) !== Number(page.fwas("roundness"))
                    desc: qsTr("Corner rounding for the frame's own widgets.")
                    source: "shell.json"
                    Step {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 1000
                        value: page.fnum("roundness", 10)
                        onModified: value => page.fedit("roundness", value)
                    }
                }
                Cell {
                    width: frameSect.span(4)
                    controlWidth: 58
                    label: qsTr("Window radius")
                    unit: "px"
                    value: String(page.fnum("frameRadius", 9))
                    def: page.fwas("frameRadius") === undefined ? "" : String(page.fwas("frameRadius"))
                    changed: page.fwas("frameRadius") !== undefined && page.fnum("frameRadius", 9) !== Number(page.fwas("frameRadius"))
                    desc: qsTr("How round the frame cuts the screen's corners.")
                    source: "shell.json"
                    Step {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 1000
                        value: page.fnum("frameRadius", 9)
                        onModified: value => page.fedit("frameRadius", value)
                    }
                }
                Cell {
                    width: frameSect.span(4)
                    controlWidth: 58
                    label: qsTr("Border width")
                    unit: "px"
                    value: String(page.fnum("frameBorder", 59))
                    def: page.fwas("frameBorder") === undefined ? "" : String(page.fwas("frameBorder"))
                    changed: page.fwas("frameBorder") !== undefined && page.fnum("frameBorder", 59) !== Number(page.fwas("frameBorder"))
                    desc: qsTr("The frame band's thickness around the desktop.")
                    source: "shell.json"
                    Step {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 200
                        value: page.fnum("frameBorder", 59)
                        onModified: value => page.fedit("frameBorder", value)
                    }
                }
                Cell {
                    width: frameSect.span(4)
                    controlWidth: 100
                    label: qsTr("Opacity")
                    unit: "%"
                    value: String(Math.round(page.fnum("frameOpacity", 1) * 100))
                    def: page.fwas("frameOpacity") === undefined ? "" : String(Math.round(Number(page.fwas("frameOpacity")) * 100))
                    changed: page.fwas("frameOpacity") !== undefined && page.fnum("frameOpacity", 1) !== Number(page.fwas("frameOpacity"))
                    desc: qsTr("How solid the frame draws.")
                    source: "shell.json"
                    Slid {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        from: 0.5; to: 1.0
                        value: page.fnum("frameOpacity", 1)
                        onModified: value => page.fedit("frameOpacity", value)
                    }
                }
                Cell {
                    width: frameSect.span(4)
                    height: neededHeight
                    footH: 34
                    label: qsTr("Interface font")
                    value: ""
                    desc: qsTr("The family the frame and shell set their text in.")
                    source: "shell.json"
                    Field {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        tabular: true
                        text: String(page.fval("fontFamily", ""))
                        onCommitted: value => page.fedit("fontFamily", value)
                    }
                }
            }

            // ── RAILS: pick an edge, then its switches, zones and widgets ────
            Section {
                id: railSect
                width: col.width
                title: qsTr("RAILS")

                Row {
                    width: railSect.width
                    spacing: Tokens.s2
                    Repeater {
                        model: ["top", "left", "bottom", "right"]
                        delegate: Rectangle {
                            id: plate
                            required property string modelData
                            readonly property var rail: page.config.rails[plate.modelData]
                            readonly property int count: {
                                const zoneIds = plate.modelData === "top" || plate.modelData === "bottom" ? ["start", "center", "end"] : ["top", "center", "bottom"];
                                let n = 0;
                                for (const zone of zoneIds) n += plate.rail[zone].length;
                                return n;
                            }
                            readonly property bool on: page.edge === plate.modelData

                            objectName: "rail-edge-" + plate.modelData
                            width: (railSect.width - 3 * Tokens.s2) / 4
                            height: 46
                            radius: Tokens.radius
                            color: plate.on ? Tokens.bone : (plateHover.hovered ? Tokens.tint5 : "transparent")
                            border.width: Tokens.border
                            border.color: plate.on ? Tokens.bone : Tokens.line
                            Behavior on color { ColorAnimation { duration: Tokens.snap } }

                            Column {
                                anchors { left: parent.left; leftMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                                spacing: 2
                                Text {
                                    text: labels.edge(plate.modelData).toUpperCase()
                                    color: plate.on ? Tokens.inkOnBone : Tokens.inkDim
                                    font.family: Tokens.ui
                                    font.pixelSize: 11
                                    font.weight: Font.Medium
                                    font.letterSpacing: Tokens.trackLabel
                                }
                                Text {
                                    text: plate.rail.enabled ? qsTr("on · %1").arg(plate.count) : qsTr("off")
                                    color: plate.on ? Tokens.inkOnBoneDim : Tokens.inkFaint
                                    font.family: Tokens.mono
                                    font.pixelSize: Tokens.fTiny
                                }
                            }
                            HoverHandler { id: plateHover; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: page.edge = plate.modelData }
                        }
                    }
                }

                RailEditor {
                    width: railSect.width
                    config: page.config
                    edge: page.edge
                    committed: page.committedBars
                    onStaged: next => page.stage(next)
                }
                ZoneEditor {
                    width: railSect.width
                    config: page.config
                    edge: page.edge
                    catalog: BarCatalog
                    onStaged: next => page.stage(next)
                }
            }

            // ── MENUS: the bounded frame menus ───────────────────────────────
            Section {
                id: menuSect
                width: col.width
                title: qsTr("MENUS")

                MenuEditor {
                    width: menuSect.width
                    config: page.config
                    catalog: MenuCatalog
                    committed: page.committedBars
                    onStaged: next => page.stage(next)
                }
            }

            // ── FRAME SURFACES: the preserved stash and system bodies ────────
            Section {
                id: surfaceSect
                width: col.width
                title: qsTr("FRAME SURFACES")

                SurfaceEditor {
                    width: surfaceSect.width
                    config: page.config
                    catalog: MenuCatalog
                    committed: page.committedBars
                    onStaged: next => page.stage(next)
                }
            }

            // ── CATALOGUE: what can be saved ─────────────────────────────────
            Section {
                id: catalogSect
                width: col.width
                title: qsTr("CATALOGUE")

                CatalogPanel {
                    width: catalogSect.width
                    barCatalog: BarCatalog
                    menuCatalog: MenuCatalog
                }
            }
        }
    }
}
