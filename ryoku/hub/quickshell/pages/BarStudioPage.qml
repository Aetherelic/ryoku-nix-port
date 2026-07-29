pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../barstudio"
import Ryoku.FrameBars
import "../barstudio/BarStudioModel.js" as Model

// Bar Studio (DESKTOP). Pick an edge, then edit that rail. It edits only the
// essentials that provably change the running desktop: the frame's draw toggle
// and opacity, each rail's on/off and thickness, and the widgets in its three
// zones (add via a per-zone drawer, remove, reorder). The retired chrome knobs
// (widget/window radius, border, the two-look style) and the rail auto-hide had
// no usable runtime effect, so they are gone; the bounded menus and the
// stash/system surfaces keep their persisted values (every edit clones the whole
// frameBars object, so no subtree it does not touch is ever dropped) but are not
// edited here.
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

    // the selected rail and its on-disk twin, for the rail cells' changed marks
    readonly property var rail: page.config.rails[page.edge]
    readonly property var railWas: page.committedBars && page.committedBars.rails ? page.committedBars.rails[page.edge] : null
    readonly property bool horizontal: page.edge === "top" || page.edge === "bottom"

    // Mirror of shell/quickshell/pill/barstyles/registry.js. The Hub runs as a
    // separate process, so the style list is duplicated here; keep it in step.
    readonly property var barStyles: [
        { id: "sumi", name: "Sumi", desc: "Ink spine: the left rail, paper and ink." },
        { id: "obi", name: "Obi", desc: "Sash: a floating top bar with kanji workspaces." },
        { id: "nacre", name: "Nacre", desc: "Pearl: three frosted islands joined to the desktop frame." }
    ]

    // The Obi bar's widgets, for the per-widget show/hide toggles below. Mirrors
    // barstyles/obi/Scene.qml; Workspaces is the bar's identity and has no toggle.
    readonly property var obiWidgets: [
        { id: "activeWindow", label: qsTr("Active window"), desc: qsTr("The focused window's title, far left.") },
        { id: "resources", label: qsTr("Resources"), desc: qsTr("CPU and memory rings.") },
        { id: "media", label: qsTr("Media"), desc: qsTr("Now playing with a music visualizer.") },
        { id: "audio", label: qsTr("Audio"), desc: qsTr("Output and input volume, with a mixer.") },
        { id: "clock", label: qsTr("Clock"), desc: qsTr("Time and date.") },
        { id: "connectivity", label: qsTr("Connections"), desc: qsTr("Wi-Fi and Bluetooth.") },
        { id: "battery", label: qsTr("Battery"), desc: qsTr("Charge and power profile.") },
        { id: "tray", label: qsTr("Tray"), desc: qsTr("System tray icons.") },
        { id: "weather", label: qsTr("Weather"), desc: qsTr("Current conditions.") }
    ]
    // The running bar style, default the built-in frame style. The frame, rails
    // and zone editors below are Sumi's; a folder style owns its own layout.
    readonly property string activeStyle: page.fval("barStyle", "sumi")
    readonly property bool sumiActive: page.activeStyle === "sumi"
    readonly property string activeName: {
        for (let i = 0; i < page.barStyles.length; i++)
            if (page.barStyles[i].id === page.activeStyle) return page.barStyles[i].name;
        return page.activeStyle;
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

    // Obi's per-widget visibility lives in the `obi` map in shell.json (an absent
    // key reads as shown). Toggling stages the whole map live like every edit.
    function obiShown(id) {
        const o = page.fval("obi", ({}));
        return !o || o[id] !== false;
    }
    function obiSet(id, on) {
        const o = Object.assign({}, page.fval("obi", ({})));
        o[id] = on;
        page.fedit("obi", o);
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
            text: qsTr("The frame's chrome, its left rail, and the widgets on it. Every change lands live on the desktop, and Save keeps it.")
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fBody
            wrapMode: Text.WordWrap
        }
    }

    // ── the sheet: FRAME, RAILS, WIDGETS in one scroll ───────────────────────
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

            // ── BAR STYLE: which bar the desktop draws ───────────────────────
            Section {
                id: styleSect
                width: col.width
                title: qsTr("BAR STYLE")

                Row {
                    width: styleSect.width
                    spacing: Tokens.s2
                    Repeater {
                        model: page.barStyles
                        delegate: Rectangle {
                            id: styleCard
                            required property var modelData
                            readonly property bool on: page.activeStyle === styleCard.modelData.id

                            objectName: "bar-style-" + styleCard.modelData.id
                            width: (styleSect.width - (page.barStyles.length - 1) * Tokens.s2) / page.barStyles.length
                            height: 64
                            radius: Tokens.radius
                            color: styleCard.on ? Tokens.bone : (sma.containsMouse ? Tokens.tint5 : "transparent")
                            border.width: Tokens.border
                            border.color: styleCard.on ? Tokens.bone : Tokens.line
                            Behavior on color { ColorAnimation { duration: Tokens.snap } }

                            Column {
                                anchors { left: parent.left; right: parent.right; margins: Tokens.s3; verticalCenter: parent.verticalCenter }
                                spacing: 3
                                Text {
                                    text: styleCard.modelData.name.toUpperCase()
                                    color: styleCard.on ? Tokens.inkOnBone : Tokens.inkDim
                                    font.family: Tokens.ui
                                    font.pixelSize: 12
                                    font.weight: Font.Medium
                                    font.letterSpacing: Tokens.trackLabel
                                }
                                Text {
                                    width: parent.width
                                    text: styleCard.modelData.desc
                                    color: styleCard.on ? Tokens.inkOnBoneDim : Tokens.inkFaint
                                    font.family: Tokens.ui
                                    font.pixelSize: Tokens.fTiny
                                    elide: Text.ElideRight
                                }
                            }
                            MouseArea {
                                id: sma
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.fedit("barStyle", styleCard.modelData.id)
                            }
                        }
                    }
                }
            }

            // A folder style owns its own frame, rails and widgets inside its
            // barstyles/<id>/ folder, so the Sumi editors below stand down.
            Section {
                id: folderNote
                width: col.width
                visible: !page.sumiActive
                title: qsTr("LAYOUT")

                Text {
                    width: folderNote.width
                    text: qsTr("The %1 style manages its own layout in barstyles/%2. Its controls are below.").arg(page.activeName).arg(page.activeStyle)
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fBody
                    wrapMode: Text.WordWrap
                }
            }

            // OBI WIDGETS: show or hide each widget on the Obi bar.
            Section {
                id: obiSect
                width: col.width
                visible: page.activeStyle === "obi"
                title: qsTr("OBI WIDGETS")

                Column {
                    width: obiSect.width
                    spacing: Tokens.s2
                    Repeater {
                        model: page.obiWidgets
                        delegate: Cell {
                            required property var modelData
                            width: obiSect.width
                            controlWidth: 54
                            label: modelData.label
                            value: page.obiShown(modelData.id) ? qsTr("ON") : qsTr("OFF")
                            desc: modelData.desc
                            source: "shell.json"
                            Sw {
                                objectName: "obi-" + modelData.id
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                on: page.obiShown(modelData.id)
                                onToggled: value => page.obiSet(modelData.id, value)
                            }
                        }
                    }
                }
            }

            Section {
                id: nacreSect
                width: col.width
                visible: page.activeStyle === "nacre"
                title: qsTr("NACRE LAYOUT")

                NacreEditor {
                    width: nacreSect.width
                    config: page.fval("nacre", ({}))
                    onStaged: value => page.fedit("nacre", value)
                }
            }

            // ── FRAME: the chrome the shell draws around the desktop ─────────
            Section {
                id: frameSect
                width: col.width
                title: qsTr("FRAME")
                visible: page.sumiActive

                Cell {
                    width: frameSect.span(6)
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
                    width: frameSect.span(6)
                    controlWidth: 180
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
                Cell {
                    width: frameSect.span(6)
                    controlWidth: 58
                    label: qsTr("Frame thickness")
                    unit: "px"
                    value: String(page.fnum("frameThickness", 2))
                    def: page.fwas("frameThickness") === undefined ? "" : String(page.fwas("frameThickness"))
                    changed: page.fwas("frameThickness") !== undefined && page.fnum("frameThickness", 2) !== Number(page.fwas("frameThickness"))
                    desc: qsTr("How thick the frame band around the desktop is drawn.")
                    source: "shell.json"
                    Step {
                        objectName: "frame-thickness"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 24
                        value: page.fnum("frameThickness", 2)
                        onModified: value => page.fedit("frameThickness", value)
                    }
                }
                Cell {
                    width: frameSect.span(6)
                    controlWidth: 58
                    label: qsTr("Corner radius")
                    unit: "px"
                    value: String(page.fnum("frameCorner", 8))
                    def: page.fwas("frameCorner") === undefined ? "" : String(page.fwas("frameCorner"))
                    changed: page.fwas("frameCorner") !== undefined && page.fnum("frameCorner", 8) !== Number(page.fwas("frameCorner"))
                    desc: qsTr("How round the frame cuts the screen's corners.")
                    source: "shell.json"
                    Step {
                        objectName: "frame-corner"
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        from: 0; to: 40
                        value: page.fnum("frameCorner", 8)
                        onModified: value => page.fedit("frameCorner", value)
                    }
                }
            }

            // ── RAILS: pick an edge, then its own switches ───────────────────
            Section {
                id: railSect
                width: col.width
                title: qsTr("RAILS")
                visible: page.sumiActive

                Row {
                    width: railSect.width
                    spacing: Tokens.s2
                    Repeater {
                        model: ["left"]
                        delegate: Rectangle {
                            id: plate
                            required property string modelData
                            readonly property var pRail: page.config.rails[plate.modelData]
                            readonly property int count: {
                                const zs = plate.modelData === "top" || plate.modelData === "bottom" ? ["start", "center", "end"] : ["top", "center", "bottom"];
                                let n = 0;
                                for (const zone of zs) n += (plate.pRail[zone] || []).length;
                                return n;
                            }
                            readonly property bool on: page.edge === plate.modelData

                            objectName: "rail-edge-" + plate.modelData
                            width: (railSect.width - 3 * Tokens.s2) / 4
                            height: 48
                            radius: Tokens.radius
                            color: plate.on ? Tokens.bone : (pma.containsMouse ? Tokens.tint5 : "transparent")
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
                            MouseArea {
                                id: pma
                                anchors.fill: parent
                                hoverEnabled: true
                                preventStealing: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.edge = plate.modelData
                            }
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
                    width: railSect.span(8)
                    controlWidth: 180
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

            // ── WIDGETS: the selected rail's three zones and its add drawers ──
            Section {
                id: zoneSect
                width: col.width
                title: qsTr("WIDGETS ON THE %1 RAIL").arg(labels.edge(page.edge).toUpperCase())
                visible: page.sumiActive

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
