pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../barstudio"
import Ryoku.FrameBars
import "../barstudio/BarStudioModel.js" as Model

// Bar Studio (DESKTOP), rebuilt simple. The essentials, and only the
// essentials: the frame chrome the shell reads from shell.json (draw toggle,
// widget and window radii, border, opacity), the frame style, the four bounded
// rails (on/off, hover reveal, thickness), and the widgets in each rail's three
// zones (add, remove, reorder). The bounded menus and preserved surfaces keep
// their persisted values -- every edit clones the whole frameBars object, so no
// subtree it does not touch is ever dropped -- but they are not edited here:
// fewer controls that all work beat the full catalogue half working.
//
// Everything stages through the shared draft (hub.stageLive), which applies to
// the RUNNING desktop as you work and rides the Hub's Save and Revert like
// every other framed page.
Item {
    id: page
    property var hub

    // which rail is on the bench
    property string edge: "left"

    // Always normalize what the editor reads. A stored value that lost a subtree
    // (a legacy config, a hand edit, a partial write) would otherwise leave the
    // editor reading undefined and a rail edit cloning the gap straight back to
    // disk. Normalizing restores every subtree from the schema default, so the
    // editor is always whole and the first staged edit heals the store. The
    // probe harness's bare hub has no val(); normalize(null) still yields a
    // complete default, so the page always loads.
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

    // the selected rail and its on-disk twin, for the rail cells' changed marks
    readonly property var rail: page.config.rails[page.edge]
    readonly property var railWas: page.committedBars && page.committedBars.rails ? page.committedBars.rails[page.edge] : null
    readonly property bool horizontal: page.edge === "top" || page.edge === "bottom"

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
    // shell reads them for the frame's draw toggle, corner radii, border and
    // window opacity, so they belong on the frame's own studio and stage
    // through the same live channel.
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
            text: qsTr("The frame's chrome, its four rails, and the widgets on each. Every change lands live on the desktop; Save keeps it, Revert walks it back.")
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
                        objectName: "frame-style"
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
                        objectName: "frame-enabled"
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
                        objectName: "frame-roundness"
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
                        objectName: "frame-window-radius"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 1000
                        value: page.fnum("frameRadius", 9)
                        onModified: value => page.fedit("frameRadius", value)
                    }
                }
                Cell {
                    width: frameSect.span(6)
                    controlWidth: 58
                    label: qsTr("Border width")
                    unit: "px"
                    value: String(page.fnum("frameBorder", 59))
                    def: page.fwas("frameBorder") === undefined ? "" : String(page.fwas("frameBorder"))
                    changed: page.fwas("frameBorder") !== undefined && page.fnum("frameBorder", 59) !== Number(page.fwas("frameBorder"))
                    desc: qsTr("The frame band's thickness around the desktop.")
                    source: "shell.json"
                    Step {
                        objectName: "frame-border"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 200
                        value: page.fnum("frameBorder", 59)
                        onModified: value => page.fedit("frameBorder", value)
                    }
                }
                Cell {
                    width: frameSect.span(6)
                    controlWidth: 100
                    label: qsTr("Opacity")
                    unit: "%"
                    value: String(Math.round(page.fnum("frameOpacity", 1) * 100))
                    def: page.fwas("frameOpacity") === undefined ? "" : String(Math.round(Number(page.fwas("frameOpacity")) * 100))
                    changed: page.fwas("frameOpacity") !== undefined && page.fnum("frameOpacity", 1) !== Number(page.fwas("frameOpacity"))
                    desc: qsTr("How solid the frame draws.")
                    source: "shell.json"
                    Slid {
                        objectName: "frame-opacity"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        from: 0.5; to: 1.0
                        value: page.fnum("frameOpacity", 1)
                        onModified: value => page.fedit("frameOpacity", value)
                    }
                }
            }

            // ── RAILS: pick an edge, then its own switches ───────────────────
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
                            readonly property var pRail: page.config.rails[plate.modelData]
                            readonly property int count: {
                                const zoneIds = plate.modelData === "top" || plate.modelData === "bottom" ? ["start", "center", "end"] : ["top", "center", "bottom"];
                                let n = 0;
                                for (const zone of zoneIds) n += plate.pRail[zone].length;
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
                                    text: plate.pRail.enabled ? qsTr("on · %1").arg(plate.count) : qsTr("off")
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

                Cell {
                    width: railSect.span(4)
                    controlWidth: 54
                    label: qsTr("Show this rail")
                    value: page.rail.enabled ? qsTr("ON") : qsTr("OFF")
                    def: page.railWas ? (page.railWas.enabled ? qsTr("ON") : qsTr("OFF")) : ""
                    changed: !!page.railWas && page.rail.enabled !== page.railWas.enabled
                    desc: qsTr("Draw the %1 rail on the frame.").arg(labels.edge(page.edge).toLowerCase())
                    source: "shell.json"
                    Sw {
                        objectName: "rail-enabled"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: page.rail.enabled
                        onToggled: value => page.stage(Model.setRail(page.config, page.edge, { enabled: value }))
                    }
                }
                Cell {
                    width: railSect.span(4)
                    controlWidth: 54
                    label: qsTr("Reveal on hover")
                    value: page.rail.reveal ? qsTr("ON") : qsTr("OFF")
                    def: page.railWas ? (page.railWas.reveal ? qsTr("ON") : qsTr("OFF")) : ""
                    changed: !!page.railWas && page.rail.reveal !== page.railWas.reveal
                    desc: qsTr("Slide the rail in when the pointer touches this edge.")
                    source: "shell.json"
                    Sw {
                        objectName: "rail-reveal"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        on: page.rail.reveal
                        onToggled: value => page.stage(Model.setRail(page.config, page.edge, { reveal: value }))
                    }
                }
                Cell {
                    width: railSect.span(4)
                    controlWidth: 58
                    label: qsTr("Thickness")
                    unit: "px"
                    value: String(page.rail.size)
                    def: page.railWas ? String(page.railWas.size) : ""
                    changed: !!page.railWas && page.rail.size !== page.railWas.size
                    desc: qsTr("How far the rail stands into the screen.")
                    source: "shell.json"
                    Step {
                        objectName: "rail-thickness"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: page.horizontal ? 16 : 24
                        to: page.horizontal ? 96 : 112
                        value: page.rail.size
                        onModified: value => page.stage(Model.setRail(page.config, page.edge, { size: value }))
                    }
                }
            }

            // ── WIDGETS: the selected rail's three zones and its add flow ─────
            Section {
                id: zoneSect
                width: col.width
                title: qsTr("WIDGETS ON THE %1 RAIL").arg(labels.edge(page.edge).toUpperCase())

                ZoneEditor {
                    width: zoneSect.width
                    config: page.config
                    edge: page.edge
                    catalog: BarCatalog
                    onStaged: next => page.stage(next)
                }
            }
        }
    }
}
