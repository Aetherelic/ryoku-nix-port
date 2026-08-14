import QtQuick
import Quickshell
import "../kit"
import "../../modules"
import Ryoku.Ui.Singletons

// Bars editor route: a scrollable live bar-surface panel ported from Shibumi's
// ActiveBarSettingsPage / BarSurfaceSettings / BarStylePreviewCard, wearing
// qsbar's dark skin. Every control writes straight to `root` (the qsbar Theme),
// so the running bar updates live and mirrors to Bar Studio. Null-guarded - the
// page may briefly exist before `root` is assigned, and some tokens live on the
// V2 Theme first (guard the barShellStyleValid function call in particular).
Item {
    id: page
    property var root: null
    property var cc: null

    // ── null-safe token shortcuts (fallbacks match the kit primitives' own) ──
    readonly property color cAccent: page.root ? page.root.seal : "#c4746e"
    readonly property color cInk: page.root ? page.root.ink : "#dddddd"
    readonly property color cSumi: page.root ? page.root.sumi : "#888888"
    readonly property color cSep: page.root ? page.root.sep : "#333333"
    readonly property color cIdle: page.root ? page.root.fillIdle : "#1a1a1a"
    readonly property string fontMono: page.root ? page.root.mono : "monospace"
    readonly property int rTile: page.root ? page.root.tileRadius : 6
    readonly property real aActive: page.root ? page.root.fillActiveAlpha : 0.22
    readonly property real aHover: page.root ? page.root.fillHoverAlpha : 0.10

    readonly property int gap: (page.cc && page.cc.tokens) ? page.cc.tokens.gap : 10
    readonly property int sectionGap: (page.cc && page.cc.tokens) ? page.cc.tokens.sectionGap : 16

    // the five bar forms + their captions (drives the header + the FORM grid)
    readonly property var formModel: [
        { form: "islands", label: "Islands", detail: "Split pills" },
        { form: "full",  label: "Full",  detail: "Edge to edge" },
        { form: "fit",   label: "Fit",   detail: "Inset rounded frame" },
        { form: "dock",  label: "Dock",  detail: "Open desktop edge" },
        { form: "notch", label: "Notch", detail: "Flowing shoulders" }
    ]
    function formInfo(f) {
        for (var i = 0; i < formModel.length; i++)
            if (formModel[i].form === f) return formModel[i]
        return null
    }

    // header strings, derived live off the active form
    readonly property string formCaption: {
        if (!page.root || !page.root.barShellStyle)
            return "Live bar surface"
        var fi = page.formInfo(String(page.root.barShellStyle))
        return fi ? (fi.label + " · " + fi.detail) : String(page.root.barShellStyle)
    }

    // One shape picker over the single bar: islands is the split-pill form, the
    // rest are the continuous shell forms. Selecting a form just records it.
    readonly property string activeForm:
        page.root && page.root.barShellStyle ? String(page.root.barShellStyle) : "full"
    function selectForm(f) {
        if (page.root && page.root.barShellStyleValid && page.root.barShellStyleValid(f))
            page.root.barShellStyle = f
    }

    // ── gap-animation mode selection (restores the old ControlPanel's picker) ──
    // Direct-select: each tile sets barAnim to its exact mode value (0-8).
    readonly property int curAnim: (page.root && page.root.barAnim !== undefined) ? page.root.barAnim : -1
    function setAnim(v) { if (page.root && page.root.barAnim !== undefined) page.root.barAnim = v }

    component AnimTile: Rectangle {
        property string caption: ""
        property bool on: false
        signal act()
        readonly property color hf: Qt.rgba(page.cInk.r, page.cInk.g, page.cInk.b, 0.06)
        readonly property color hb: Qt.rgba(page.cInk.r, page.cInk.g, page.cInk.b, 0.28)
        height: 32
        radius: page.rTile
        color: on ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, 0.14)
                  : (tileMa.containsMouse ? hf : page.cIdle)
        border.width: 1
        border.color: on ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, 0.52)
                         : (tileMa.containsMouse ? hb : page.cSep)
        Behavior on color { ColorAnimation { duration: 120 } }
        UiText {
            anchors.centerIn: parent
            text: parent.caption
            color: parent.on ? page.cAccent : page.cInk
            font.family: page.fontMono
            font.pixelSize: 11
            font.weight: parent.on ? Font.DemiBold : Font.Normal
        }
        MouseArea { id: tileMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: parent.act() }
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width
            spacing: page.sectionGap

            // ── header card: V<n> ACTIVE + active form caption + LIVE dot ──
            Rectangle {
                width: col.width
                height: 62
                radius: page.rTile
                color: page.root
                    ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, 0.09)
                    : page.cIdle
                border.width: 1
                border.color: page.root
                    ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, 0.5)
                    : page.cSep

                Row {
                    id: liveRow
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 7
                        height: 7
                        radius: 3.5
                        color: page.cAccent
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: true
                            NumberAnimation { from: 1.0; to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 0.3; to: 1.0; duration: 900; easing.type: Easing.InOutSine }
                        }
                    }
                    UiText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("LIVE")
                        color: page.cAccent
                        font.family: page.fontMono
                        font.pixelSize: 10
                        font.letterSpacing: 0.8
                        font.weight: Font.DemiBold
                    }
                }

                Column {
                    anchors.left: parent.left
                    anchors.right: liveRow.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 14
                    anchors.rightMargin: 12
                    spacing: 3

                    UiText {
                        text: page.activeForm.toUpperCase() + I18n.tr(" ACTIVE")
                        color: page.cInk
                        font.family: page.fontMono
                        font.pixelSize: 18
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                    UiText {
                        width: parent.width
                        text: page.formCaption
                        color: page.cSumi
                        elide: Text.ElideRight
                        font.family: page.fontMono
                        font.pixelSize: 11
                    }
                }
            }

            // ── POSITION ──
            CcSection {
                width: col.width
                root: page.root
                title: I18n.tr("POSITION")

                CcSeg {
                    root: page.root
                    options: [{ key: "top", label: "Top" }, { key: "bottom", label: "Bottom" }]
                    current: page.root ? page.root.barPosition : "top"
                    onChose: k => { if (page.root) page.root.barPosition = k }
                }
            }

            // ── SURFACE (one form-aware section over both engines) ──
            CcSection {
                width: col.width
                root: page.root
                title: I18n.tr("SURFACE")

                CcRow {
                    root: page.root
                    label: I18n.tr("Bar border")
                    desc: I18n.tr("Outline the bar")
                    controlWidth: 108
                    CcSeg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        options: [{ key: "on", label: "On" }, { key: "off", label: "Off" }]
                        current: (page.root && page.root.barBorderEnabled) ? "on" : "off"
                        onChose: k => {
                            if (page.root && page.root.barBorderEnabled !== undefined) page.root.barBorderEnabled = (k === "on")
                        }
                    }
                }
                CcRow {
                    root: page.root
                    label: I18n.tr("Corners")
                    desc: I18n.tr("Round the bar's corners")
                    controlWidth: 150
                    CcSeg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        options: [{ key: "square", label: "Square" }, { key: "soft", label: "Soft" }, { key: "round", label: "Round" }]
                        current: (page.root && page.root.barCornerRadius <= 0) ? "square"
                            : (page.root && page.root.barCornerRadius >= 16) ? "round" : "soft"
                        onChose: k => {
                            var px = (k === "square" ? 0 : k === "round" ? 16 : 8)
                            if (page.root && page.root.barCornerRadius !== undefined) page.root.barCornerRadius = px
                        }
                    }
                }
                CcRow {
                    root: page.root
                    label: I18n.tr("Panel + tooltip")
                    desc: I18n.tr("Outline panels and tooltips")
                    controlWidth: 108
                    CcSeg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        options: [{ key: "on", label: "On" }, { key: "off", label: "Off" }]
                        current: (page.root && page.root.panelTooltipBorderEnabled) ? "on" : "off"
                        onChose: k => { if (page.root && page.root.panelTooltipBorderEnabled !== undefined) page.root.panelTooltipBorderEnabled = (k === "on") }
                    }
                }
                CcRow {
                    root: page.root
                    label: I18n.tr("Depth")
                    desc: I18n.tr("Soft shadow behind pills, panels and tooltips")
                    controlWidth: 108
                    CcSeg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        options: [{ key: "on", label: "On" }, { key: "off", label: "Off" }]
                        current: (page.root && page.root.barShadowEnabled) ? "on" : "off"
                        onChose: k => {
                            if (page.root && page.root.barShadowEnabled !== undefined) page.root.barShadowEnabled = (k === "on")
                        }
                    }
                }
                CcRow {
                    root: page.root
                    label: I18n.tr("Frost")
                    desc: I18n.tr("Translucent bar surfaces")
                    controlWidth: 108
                    CcSeg {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        options: [{ key: "on", label: "On" }, { key: "off", label: "Off" }]
                        current: (page.root && page.root.barFrostEnabled) ? "on" : "off"
                        onChose: k => {
                            if (page.root && page.root.barFrostEnabled !== undefined) page.root.barFrostEnabled = (k === "on")
                        }
                    }
                }

            }

            // ── GAPS: how far the shell stays off each output edge ──
            CcSection {
                width: col.width
                root: page.root
                title: I18n.tr("GAPS")

                CcRow {
                    root: page.root
                    label: I18n.tr("Top")
                    desc: I18n.tr("Lift the bar off the top edge")
                    controlWidth: 104
                    CcStepper {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        suffix: "px"
                        value: page.root && page.root.barGapTop !== undefined ? page.root.barGapTop : 0
                        onCommit: v => { if (page.root && page.root.barGapTop !== undefined) page.root.barGapTop = v }
                    }
                }
                CcRow {
                    root: page.root
                    label: I18n.tr("Bottom")
                    desc: I18n.tr("Reserve extra room below the bar")
                    controlWidth: 104
                    CcStepper {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        suffix: "px"
                        value: page.root && page.root.barGapBottom !== undefined ? page.root.barGapBottom : 0
                        onCommit: v => { if (page.root && page.root.barGapBottom !== undefined) page.root.barGapBottom = v }
                    }
                }
                CcRow {
                    root: page.root
                    label: I18n.tr("Left")
                    desc: I18n.tr("Inset the shell from the left edge")
                    controlWidth: 104
                    CcStepper {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        suffix: "px"
                        value: page.root && page.root.barGapLeft !== undefined ? page.root.barGapLeft : 0
                        onCommit: v => { if (page.root && page.root.barGapLeft !== undefined) page.root.barGapLeft = v }
                    }
                }
                CcRow {
                    root: page.root
                    label: I18n.tr("Right")
                    desc: I18n.tr("Inset the shell from the right edge")
                    controlWidth: 104
                    CcStepper {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        root: page.root
                        suffix: "px"
                        value: page.root && page.root.barGapRight !== undefined ? page.root.barGapRight : 0
                        onCommit: v => { if (page.root && page.root.barGapRight !== undefined) page.root.barGapRight = v }
                    }
                }
            }

            // ── BAR FORM (2×2 selectable silhouette cards) ──
            CcSection {
                width: col.width
                root: page.root
                title: I18n.tr("BAR FORM")

                Grid {
                    id: formGrid
                    width: col.width
                    columns: 2
                    columnSpacing: page.gap
                    rowSpacing: page.gap

                    Repeater {
                        model: page.formModel

                        delegate: Rectangle {
                            id: fcard
                            required property var modelData
                            readonly property bool on: page.activeForm === modelData.form
                            readonly property bool hovered: fma.containsMouse

                            width: (formGrid.width - formGrid.columnSpacing) / 2
                            height: 96
                            radius: page.rTile
                            color: fcard.on
                                ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, page.aActive)
                                : fcard.hovered
                                    ? Qt.rgba(page.cAccent.r, page.cAccent.g, page.cAccent.b, page.aHover)
                                    : page.cIdle
                            border.width: fcard.on ? 2 : 1
                            border.color: (fcard.on || fcard.hovered) ? page.cAccent : page.cSep
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Item {
                                id: preview
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 8
                                height: 42
                                clip: true

                                BarSilhouette {
                                    anchors.fill: parent
                                    root: page.root
                                    form: fcard.modelData.form
                                }
                            }

                            Row {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.bottomMargin: 8
                                spacing: 6

                                Column {
                                    width: parent.width - mark.width - parent.spacing
                                    spacing: 1

                                    UiText {
                                        width: parent.width
                                        text: I18n.tr(fcard.modelData.label)
                                        color: fcard.on ? page.cAccent : page.cInk
                                        elide: Text.ElideRight
                                        font.family: page.fontMono
                                        font.pixelSize: 12
                                        font.weight: Font.DemiBold
                                    }
                                    UiText {
                                        width: parent.width
                                        text: fcard.modelData.detail
                                        color: page.cSumi
                                        elide: Text.ElideRight
                                        font.family: page.fontMono
                                        font.pixelSize: 10
                                    }
                                }
                                UiText {
                                    id: mark
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: fcard.on ? "●" : ""
                                    color: page.cAccent
                                    font.family: page.fontMono
                                    font.pixelSize: 10
                                }
                            }

                            MouseArea {
                                id: fma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.selectForm(fcard.modelData.form)
                            }
                        }
                    }
                }
            }

            // ── BAR ACCENT ──
            CcSection {
                width: col.width
                root: page.root
                title: I18n.tr("BAR ACCENT")

                CcSwatchGrid {
                    root: page.root
                    options: page.root ? page.root.barColorOptions : []
                    current: page.root ? page.root.barColor : ""
                    onChose: id => { if (page.root) page.root.barColor = id }
                }
            }

            // ── GAP ANIMATION (the stream in the gaps) ──
            CcSection {
                width: col.width
                root: page.root
                title: I18n.tr("GAP ANIMATION")

                UiText {
                    width: col.width
                    text: I18n.tr("The stream flowing in the gaps between widgets · pick a mode")
                    color: page.cSumi
                    font.family: page.fontMono
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }

                Flow {
                    width: col.width
                    spacing: page.gap
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: I18n.tr("Off");        on: page.curAnim === 0; onAct: page.setAnim(0) }
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: I18n.tr("Stream");     on: page.curAnim === 1; onAct: page.setAnim(1) }
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: I18n.tr("Surge");      on: page.curAnim === 2; onAct: page.setAnim(2) }
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: I18n.tr("Bolt");       on: page.curAnim === 3; onAct: page.setAnim(3) }
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: I18n.tr("Reactor");    on: page.curAnim === 7; onAct: page.setAnim(7) }
                    AnimTile { width: (col.width - 2 * page.gap) / 3; caption: I18n.tr("Quotes");     on: page.curAnim === 8; onAct: page.setAnim(8) }
                }
            }

            // ── action tiles ──
            Row {
                width: col.width
                spacing: page.gap

                CcTile {
                    width: (parent.width - parent.spacing) / 2
                    root: page.root
                    icon: "splitscreen"
                    label: I18n.tr("Edit layout")
                    sub: I18n.tr("Unlock the bar to drag & arrange")
                    onActivated: {
                        if (page.root) page.root.barUnlocked = true
                        if (page.cc) page.cc.close()
                    }
                }
                CcTile {
                    width: (parent.width - parent.spacing) / 2
                    root: page.root
                    icon: "restart_alt"
                    label: I18n.tr("Restore layout")
                    sub: I18n.tr("Reset slots, order & splits")
                    onActivated: {
                        if (page.root && page.root.resetAllBarLayouts) page.root.resetAllBarLayouts()
                    }
                }
            }
        }
    }
}