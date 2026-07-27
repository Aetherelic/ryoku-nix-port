pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../barstudio"
import Ryoku.FrameBars
import "../barstudio/BarStudioModel.js" as Model

// Bar Studio (DESKTOP), rebuilt as a direct-manipulation editor. The hero is a
// live schematic of the desktop frame and its four rails; click an edge to put
// that rail on the bench, then edit it in the inspector below. It edits only
// the essentials that provably change the running desktop -- the frame's draw
// toggle and opacity, and each rail's on/off, visibility and thickness, plus the
// widgets in its three zones (add, remove, reorder). The retired chrome knobs
// (widget/window radius, border, the two-look style) had no runtime consumer, so
// they are gone; the bounded menus and the stash/system surfaces keep their
// persisted values -- every edit clones the whole frameBars object, so no
// subtree it does not touch is ever dropped -- but they are not edited here.
//
// Everything stages through the shared draft (hub.stageLive), which applies to
// the RUNNING desktop as you work and rides the Hub's Save and Revert like every
// other framed page.
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

    // the selected rail and its on-disk twin, for the inspector's changed marks
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
    // shell reads frameEnabled for the draw toggle and frameOpacity for how solid
    // the frame paints, so they belong on the frame's own studio and stage
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

    // preview height: capped so the inspector always keeps room, and never so
    // small the diagram stops reading.
    readonly property real previewH: Math.max(190, Math.min(330, page.height * 0.42))

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
            text: qsTr("Your desktop frame and its four rails. Click an edge to work on that rail; every change lands live on the desktop, and Save keeps it.")
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
            wrapMode: Text.WordWrap
        }
    }

    // ── the stage: the live diagram and the two working frame knobs ──────────
    Column {
        id: stage
        anchors { left: parent.left; right: parent.right; top: head.bottom; topMargin: Tokens.s5 }
        spacing: Tokens.s3

        FramePreview {
            id: preview
            width: parent.width
            height: page.previewH
            config: page.config
            committedBars: page.committedBars
            selected: page.edge
            frameEnabled: !!page.fval("frameEnabled", true)
            frameOpacity: page.fnum("frameOpacity", 1)
            onSelectEdge: e => page.edge = e
        }

        // the frame's own two live controls, as a caption bound to the diagram
        Item {
            width: parent.width
            height: 46
            Rectangle {
                anchors.fill: parent
                radius: Tokens.radius
                color: "transparent"
                border.width: Tokens.border
                border.color: Tokens.line
            }
            Row {
                anchors { left: parent.left; leftMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                spacing: Tokens.s3
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("DRAW FRAME")
                    color: Tokens.inkMuted
                    font.family: Tokens.ui; font.pixelSize: 10
                    font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                }
                Sw {
                    objectName: "frame-enabled"
                    anchors.verticalCenter: parent.verticalCenter
                    on: !!page.fval("frameEnabled", true)
                    onToggled: value => page.fedit("frameEnabled", value)
                }
            }
            Row {
                anchors { right: parent.right; rightMargin: Tokens.s4; verticalCenter: parent.verticalCenter }
                spacing: Tokens.s3
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("OPACITY")
                    color: Tokens.inkMuted
                    font.family: Tokens.ui; font.pixelSize: 10
                    font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                }
                Slid {
                    objectName: "frame-opacity"
                    anchors.verticalCenter: parent.verticalCenter
                    width: 150
                    from: 0.5; to: 1.0
                    value: page.fnum("frameOpacity", 1)
                    onModified: value => page.fedit("frameOpacity", value)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 34
                    horizontalAlignment: Text.AlignRight
                    text: Math.round(page.fnum("frameOpacity", 1) * 100) + "%"
                    color: Tokens.ink
                    font.family: Tokens.mono; font.pixelSize: Tokens.fSmall
                }
            }
        }
    }

    // ── the inspector: the selected rail's switches and its widgets ──────────
    Flickable {
        id: flick
        anchors { left: parent.left; right: parent.right; top: stage.bottom; bottom: parent.bottom; topMargin: Tokens.s5 }
        contentWidth: width
        contentHeight: col.height + Tokens.s5
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: flick.width - 14
            spacing: Tokens.s5

            Section {
                id: railSect
                width: col.width
                title: qsTr("THE %1 RAIL").arg(labels.edge(page.edge).toUpperCase())

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
                    width: railSect.span(8)
                    controlWidth: 172
                    label: qsTr("Visibility")
                    value: page.rail.reveal ? qsTr("Pinned") : qsTr("Auto-hide")
                    def: page.railWas ? (page.railWas.reveal ? qsTr("Pinned") : qsTr("Auto-hide")) : ""
                    changed: !!page.railWas && page.rail.reveal !== page.railWas.reveal
                    desc: qsTr("Pinned keeps the rail on screen. Auto-hide tucks it away and slides it in when the pointer touches this edge.")
                    source: "shell.json"
                    Seg {
                        objectName: "rail-visibility"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        options: [qsTr("Pinned"), qsTr("Auto-hide")]
                        current: page.rail.reveal ? qsTr("Pinned") : qsTr("Auto-hide")
                        onChose: label => page.stage(Model.setRail(page.config, page.edge, { reveal: label === qsTr("Pinned") }))
                    }
                }
                Cell {
                    width: railSect.span(12)
                    controlWidth: 240
                    label: qsTr("Thickness")
                    unit: "px"
                    value: String(page.rail.size)
                    def: page.railWas ? String(page.railWas.size) : ""
                    changed: !!page.railWas && page.rail.size !== page.railWas.size
                    desc: qsTr("How far the %1 rail stands into the screen.").arg(labels.edge(page.edge).toLowerCase())
                    source: "shell.json"
                    Slid {
                        objectName: "rail-thickness"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        from: page.horizontal ? 16 : 24
                        to: page.horizontal ? 96 : 112
                        value: page.rail.size
                        onModified: value => page.stage(Model.setRail(page.config, page.edge, { size: value }))
                    }
                }
            }

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
