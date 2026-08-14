import QtQuick
import "../kit"
import "../../modules"
import Ryoku.Ui.Singletons

// APPEARANCE route: a scrollable per-widget list. One row per bar widget group
// with a visibility toggle (the mod* booleans), an assigned-accent control (the
// per-widget colour system, reached through a small palette popover) and a
// density toggle where the widget supports it. Ported from Shibumi's
// WidgetAppearanceWorkbench, wearing qsbar's dark skin and driving `root` (the
// Theme) directly. Every helper call is capability-gated so the page also loads
// clean under the offscreen probe Theme.
Item {
    id: page
    property var root: null
    property var cc: null

    // Colour popover state (a single floating menu, addressed by widget group).
    property string colorGid: ""
    property string colorLabel: ""

    // Per-widget colour is gated on widgetHasFill so the page stays error-free
    // if the live Theme (or the offscreen probe) does not expose the helpers.
    readonly property bool colorSupported: !!(page.root && page.root.widgetHasFill)

    // ── visibility (mod* booleans) ──
    function boolOf(prop) {
        return (page.root && prop !== "") ? page.root[prop] === true : false
    }
    function toggleMod(prop) {
        if (page.root && prop !== "" && page.root[prop] !== undefined)
            page.root[prop] = !page.root[prop]
    }

    // ── density (compact) - drive whichever mechanism the live Theme consumes ──
    // The bar renders one presentation toggled per-group via iconOnly() /
    // mprisBarStyle; `flag` is an optional legacy per-group compact property.
    function compactOf(gid, flag) {
        if (!page.root || flag === "") return false
        if (gid === "G9" && page.root.mprisBarStyle !== undefined)
            return page.root.mprisBarStyle === "full"
        if (page.root.iconOnly !== undefined)
            return page.root.iconOnly(gid) === true
        return page.root[flag] === true
    }
    function toggleCompact(gid, flag) {
        if (!page.root || flag === "") return
        if (gid === "G9" && page.root.mprisBarStyle !== undefined) {
            page.root.mprisBarStyle = (page.root.mprisBarStyle === "full") ? "default" : "full"
            return
        }
        if (page.root.toggleIconOnly !== undefined) { page.root.toggleIconOnly(gid); return }
        if (page.root[flag] !== undefined) page.root[flag] = !page.root[flag]
    }

    // Separator: ends the widget's island run, so it stands alone in islands form.
    function sepOf(gid) {
        return (page.root && gid !== "" && page.root.sepAfter !== undefined)
            ? page.root.sepAfter(gid) === true : false
    }
    function toggleSep(gid) {
        if (page.root && gid !== "" && page.root.toggleSep !== undefined)
            page.root.toggleSep(gid)
    }

    // Labelled chip for the On/Off pair and the density switch.
    component StateChip: Rectangle {
        id: chip
        property string label: ""
        property bool active: false
        property bool live: true
        signal act

        width: Math.max(38, chipText.implicitWidth + 16)
        height: 24
        radius: page.root ? page.root.tileRadius : 4
        color: !page.root ? "transparent"
            : chip.active
                ? Qt.rgba(page.root.seal.r, page.root.seal.g, page.root.seal.b, 0.18)
                : (chipMa.containsMouse && chip.live
                    ? Qt.rgba(page.root.ink.r, page.root.ink.g, page.root.ink.b, 0.07)
                    : page.root.fillIdle)
        border.width: 1
        border.color: !page.root ? "transparent"
            : chip.active
                ? Qt.rgba(page.root.seal.r, page.root.seal.g, page.root.seal.b, 0.55)
                : page.root.sep
        opacity: chip.live ? 1 : 0.4
        Behavior on color { ColorAnimation { duration: 120 } }

        UiText {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: page.root ? (chip.active ? page.root.seal : page.root.sumiHi) : "#888888"
            font.family: page.root ? page.root.mono : "monospace"
            font.pixelSize: 10
            font.weight: chip.active ? Font.DemiBold : Font.Normal
            Behavior on color { ColorAnimation { duration: 120 } }
        }
        MouseArea {
            id: chipMa
            anchors.fill: parent
            enabled: chip.live
            hoverEnabled: true
            cursorShape: chip.live ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: chip.act()
        }
    }

    // One widget as a state card: mark and accent on top, On/Off and density below.
    component WidgetCard: Rectangle {
        id: wc
        property string modProp: ""
        property string gid: ""
        property string flag: ""
        property string title: ""
        property string offLabel: "Full"
        property string onLabel: "Icon"
        // The mark the widget draws in the bar, so the card previews it.
        property string icon: ""

        readonly property bool shown: page.boolOf(modProp)
        readonly property bool colorable: page.colorSupported && gid !== ""
        readonly property bool framed: colorable && page.root && page.root.widgetHasBorder(gid)
        readonly property bool compactable: flag !== ""
        readonly property bool compactOn: page.compactOf(gid, flag)
        readonly property bool menuOpen: gid !== "" && page.colorGid === gid
        readonly property bool sepOn: page.sepOf(gid)

        height: 68
        radius: page.root ? page.root.tileRadius : 4
        color: page.root ? (wc.shown ? page.root.fillActive : page.root.fillIdle) : "transparent"
        border.width: 1
        border.color: !page.root ? "transparent"
            : (cardHover.hovered || wc.menuOpen) ? page.root.seal
            : wc.framed ? Qt.rgba(page.root.seal.r, page.root.seal.g, page.root.seal.b, 0.55)
            : wc.shown ? Qt.rgba(page.root.seal.r, page.root.seal.g, page.root.seal.b, 0.34)
            : page.root.sep
        Behavior on color { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

        HoverHandler { id: cardHover }

        IconText {
            id: cardIcon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.top: parent.top
            anchors.topMargin: 8
            visible: wc.icon !== ""
            text: wc.icon
            color: !page.root ? "#888888"
                : (wc.colorable && page.root.widgetHasFill(wc.gid))
                    ? page.root.widgetAssignedColor(wc.gid)
                    : (wc.shown ? page.root.ink : page.root.sumi)
            font.pixelSize: 12
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        UiText {
            id: cardName
            anchors.left: cardIcon.visible ? cardIcon.right : parent.left
            anchors.leftMargin: cardIcon.visible ? 7 : 10
            anchors.right: colorChipHolder.visible ? colorChipHolder.left : parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: cardIcon.visible ? cardIcon.verticalCenter : undefined
            anchors.top: cardIcon.visible ? undefined : parent.top
            anchors.topMargin: cardIcon.visible ? 0 : 9
            text: wc.title
            color: page.root ? (wc.shown ? page.root.ink : page.root.sumi) : "#888888"
            font.family: page.root ? page.root.mono : "monospace"
            font.pixelSize: 12
            font.weight: wc.shown ? Font.Medium : Font.Normal
            elide: Text.ElideRight
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        // palette chip → opens the accent popover for this group
        Rectangle {
            id: colorChipHolder
            anchors.right: parent.right
            anchors.rightMargin: 7
            anchors.top: parent.top
            anchors.topMargin: 5
            width: 24
            height: 24
            visible: wc.colorable
            readonly property bool assigned: wc.colorable && page.root && page.root.widgetHasFill(wc.gid)
            radius: page.root ? page.root.tileRadius : 4
            color: !page.root ? "transparent"
                : assigned
                    ? Qt.rgba(page.root.seal.r, page.root.seal.g, page.root.seal.b, 0.16)
                    : (colorMa.containsMouse || wc.menuOpen) ? page.root.fillHover : page.root.fillIdle
            border.width: 1
            border.color: !page.root ? "transparent"
                : (assigned || wc.menuOpen) ? page.root.seal : page.root.sep
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            IconText {
                anchors.centerIn: parent
                text: "palette"
                color: colorChipHolder.assigned
                    ? page.root.widgetAssignedColor(wc.gid)
                    : (page.root
                        ? (colorMa.containsMouse || wc.menuOpen ? page.root.seal : page.root.sumiHi)
                        : "#888888")
                font.pixelSize: 12
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            MouseArea {
                id: colorMa
                anchors.fill: parent
                enabled: wc.colorable
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (page.colorGid === wc.gid) { page.colorGid = ""; page.colorLabel = "" }
                    else { page.colorGid = wc.gid; page.colorLabel = wc.title }
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 9
            spacing: 4

            StateChip {
                label: I18n.tr("On")
                active: wc.shown
                onAct: if (!wc.shown) page.toggleMod(wc.modProp)
            }
            StateChip {
                label: I18n.tr("Off")
                active: !wc.shown
                onAct: if (wc.shown) page.toggleMod(wc.modProp)
            }
            StateChip {
                visible: wc.compactable
                label: wc.compactOn ? wc.onLabel : wc.offLabel
                active: wc.shown && wc.compactOn
                live: wc.shown
                onAct: page.toggleCompact(wc.gid, wc.flag)
            }
            StateChip {
                visible: wc.gid !== ""
                label: I18n.tr("Split")
                active: wc.shown && wc.sepOn
                live: wc.shown
                onAct: page.toggleSep(wc.gid)
            }
        }
    }

    // ── the scrollable list ──
    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: contentCol
            width: flick.width
            spacing: 12

            CcSection {
                width: contentCol.width
                root: page.root
                title: I18n.tr("WIDGETS")
                desc: I18n.tr("On · Off sets visibility · palette assigns an accent · density chip · Split gives the widget its own island")

                // Bento: as many equal-width cards per row as the panel can hold.
                Grid {
                    id: widgetGrid
                    width: parent.width
                    columnSpacing: 8
                    rowSpacing: 8
                    columns: Math.max(1,
                        Math.floor((width + columnSpacing) / (232 + columnSpacing)))
                    readonly property real cellW: columns > 0
                        ? (width - columnSpacing * (columns - 1)) / columns : width

                    WidgetCard { width: widgetGrid.cellW; modProp: "modStatus";     gid: "G3";  icon: "notifications";     title: I18n.tr("Status") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modMemory";     gid: "G4";  icon: "memory";            flag: "compactMemory";     title: I18n.tr("Memory") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modCpu";        gid: "G5";  icon: "planner_review";    flag: "compactCpu";        title: I18n.tr("CPU") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modVolume";     gid: "G6";  icon: "graphic_eq";        flag: "compactVolume";     title: I18n.tr("Volume") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modClaude";     gid: "G7";  icon: "smart_toy";         title: I18n.tr("AI Usage") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modWeather";    gid: "G8";  icon: "schedule";          title: I18n.tr("Clock / Weather") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modMpris";      gid: "G9";  icon: "music_note";        flag: "compactMpris";      title: I18n.tr("Now Playing"); offLabel: "Def"; onLabel: "Full" }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modQuick";      gid: "G10"; icon: "tune";              title: I18n.tr("Quick Tools") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modMedia";                  icon: "collections";       title: I18n.tr("Media") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modNetwork";    gid: "G11"; icon: "wifi";              flag: "compactNetwork";    title: I18n.tr("Network") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modBattery";    gid: "G12"; icon: "battery_5_bar";     flag: "compactBattery";    title: I18n.tr("Battery") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modBrightness"; gid: "G13"; icon: "brightness_6";      flag: "compactBrightness"; title: I18n.tr("Brightness") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modPower";      gid: "G14"; icon: "bolt";              flag: "compactPower";      title: I18n.tr("Power Profile") }
                    WidgetCard { width: widgetGrid.cellW; modProp: "modBluetooth";  gid: "G15"; icon: "bluetooth";         flag: "compactBluetooth";  title: I18n.tr("Bluetooth") }
                    WidgetCard { width: widgetGrid.cellW; visible: page.root && page.root.modGpu !== undefined;            modProp: "modGpu";            gid: "G17"; icon: "developer_board";   flag: "compactGpu";            title: I18n.tr("GPU") }
                    WidgetCard { width: widgetGrid.cellW; visible: page.root && page.root.modCpuTemperature !== undefined; modProp: "modCpuTemperature"; gid: "G16"; icon: "device_thermostat"; flag: "compactCpuTemperature"; title: I18n.tr("CPU Temp") }
                    WidgetCard { width: widgetGrid.cellW; visible: page.root && page.root.modStorage !== undefined;        modProp: "modStorage";        gid: "G18"; icon: "hard_drive_2";      flag: "compactStorage";        title: I18n.tr("Storage") }
                }
            }

            // AI-usage tool: which coding-agent meter the pill shows. A per-widget
            // behaviour, not a mod*/palette/density knob, so it sits in its own
            // section under the list and only shows while the widget is enabled.
            CcSection {
                width: contentCol.width
                root: page.root
                title: I18n.tr("AI USAGE")
                desc: I18n.tr("Which coding-agent meter the AI pill tracks")
                visible: page.boolOf("modClaude")

                CcSeg {
                    root: page.root
                    options: [{ key: "claude", label: "Claude" }, { key: "codex", label: "Codex" }, { key: "opencode", label: "OpenCode" }]
                    current: page.root ? page.root.aiTool : ""
                    onChose: (key) => { if (page.root) page.root.aiTool = key }
                }
            }

            // Temperature source for the CPU-temperature widget: the same sensor
            // picker the Thermals panel carries, surfaced while the widget is
            // enabled (hidden when the widget has no temperature source).
            CcSection {
                width: contentCol.width
                root: page.root
                title: I18n.tr("TEMPERATURE")
                desc: I18n.tr("Which sensor the CPU temperature widget reads")
                visible: page.boolOf("modCpuTemperature")

                CcSeg {
                    root: page.root
                    options: [{ key: "cpu", label: "CPU" }, { key: "core", label: "Core" }, { key: "gpu", label: "GPU" }, { key: "nvme", label: "NVMe" }, { key: "memory", label: "Memory" }]
                    current: page.root ? page.root.barTemperatureSource : ""
                    onChose: (key) => { if (page.root) page.root.barTemperatureSource = key }
                }
            }
        }
    }

    // ── accent popover ── floats above the list, addressed by page.colorGid.
    // Only instantiated when the Theme supports per-widget colour, so its
    // widget*() bindings never evaluate under the offscreen probe Theme.
    Loader {
        anchors.fill: parent
        z: 50
        active: page.colorSupported && page.colorGid !== ""
        sourceComponent: popoverComp
    }

    Component {
        id: popoverComp
        Item {
            anchors.fill: parent

            // preset row for a per-widget geometry knob (opacity/radius/pad)
            component GeomRow: Column {
                id: grow
                property string glabel: ""
                property string gkey: ""
                property var opts: []
                width: parent ? parent.width : 0
                spacing: 3
                UiText {
                    text: grow.glabel
                    color: page.root.sumiHi
                    font.family: page.root.mono; font.pixelSize: 10; font.letterSpacing: 0.7
                }
                Row {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: grow.opts
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: page.root.widgetGeomOf(page.colorGid)[grow.gkey] === modelData.v
                            width: page.root.evenW((grow.width - (grow.opts.length - 1) * 4) / grow.opts.length)
                            height: 28
                            radius: page.root.tileRadius
                            color: sel ? Qt.rgba(page.root.seal.r, page.root.seal.g, page.root.seal.b, 0.16)
                                : gma.containsMouse ? page.root.fillHover : "transparent"
                            border.color: sel ? page.root.seal : page.root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.sel ? page.root.seal : page.root.ink
                                font.family: page.root.mono; font.pixelSize: 10
                            }
                            MouseArea {
                                id: gma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.root.setWidgetGeom(page.colorGid, grow.gkey, modelData.v)
                            }
                        }
                    }
                }
            }

            // frame width preset row - GeomRow's language, wired to the border
            // width instead of the widgetGeom map.
            component FrameWidthRow: Column {
                id: fwrow
                property string glabel: ""
                property var opts: []
                width: parent ? parent.width : 0
                spacing: 3
                UiText {
                    text: fwrow.glabel
                    color: page.root.sumiHi
                    font.family: page.root.mono; font.pixelSize: 10; font.letterSpacing: 0.7
                }
                Row {
                    width: parent.width
                    spacing: 4
                    Repeater {
                        model: fwrow.opts
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: page.root.widgetBorderWidth(page.colorGid) === modelData.v
                            width: page.root.evenW((fwrow.width - (fwrow.opts.length - 1) * 4) / fwrow.opts.length)
                            height: 28
                            radius: page.root.tileRadius
                            color: sel ? Qt.rgba(page.root.seal.r, page.root.seal.g, page.root.seal.b, 0.16)
                                : fwma.containsMouse ? page.root.fillHover : "transparent"
                            border.color: sel ? page.root.seal : page.root.sep
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }
                            UiText {
                                anchors.centerIn: parent
                                text: modelData.label
                                color: parent.sel ? page.root.seal : page.root.ink
                                font.family: page.root.mono; font.pixelSize: 10
                            }
                            MouseArea {
                                id: fwma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.root.setWidgetBorderWidth(page.colorGid, modelData.v)
                            }
                        }
                    }
                }
            }

            // frame colour row - swatches for the border key. inherit/surface are
            // labelled chips (not fixed palette colours); the rest render as the
            // palette swatches do.
            component FrameColorRow: Column {
                id: fcrow
                property string glabel: ""
                width: parent ? parent.width : 0
                spacing: 3
                UiText {
                    text: fcrow.glabel
                    color: page.root.sumiHi
                    font.family: page.root.mono; font.pixelSize: 10; font.letterSpacing: 0.7
                }
                Grid {
                    width: parent.width
                    columns: 8
                    columnSpacing: 4
                    rowSpacing: 4
                    Repeater {
                        model: ["inherit", "surface"].concat(page.root.barColorOptions)
                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool labelled: modelData === "inherit" || modelData === "surface"
                            readonly property bool selected: page.root.widgetBorderColorKey(page.colorGid) === modelData
                            width: page.root.evenW((fcrow.width - 28) / 8)
                            height: 22
                            radius: page.root.tileRadius
                            color: labelled
                                ? (selected ? page.root.fillActive : fcma.containsMouse ? page.root.fillHover : "transparent")
                                : page.root.paletteColor(modelData)
                            border.color: labelled
                                ? (selected || fcma.containsMouse ? page.root.seal : page.root.sep)
                                : page.root.sep
                            border.width: 1
                            scale: fcma.containsMouse ? 1.06 : 1.0
                            z: fcma.containsMouse ? 1 : 0
                            Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                            UiText {
                                anchors.centerIn: parent
                                text: parent.labelled
                                    ? (modelData === "inherit" ? I18n.tr("Auto") : I18n.tr("Fill"))
                                    : (modelData === "foreground" ? I18n.tr("F") : modelData.slice(-1))
                                color: parent.labelled
                                    ? (parent.selected || fcma.containsMouse ? page.root.seal : page.root.ink)
                                    : page.root.paletteContrastColor(modelData)
                                font.family: page.root.mono
                                font.pixelSize: 10
                                font.weight: Font.Medium
                            }
                            Rectangle {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 2
                                width: 12; height: 2; radius: 1
                                visible: parent.selected && !parent.labelled
                                color: page.root.paletteContrastColor(modelData)
                            }
                            MouseArea {
                                id: fcma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.root.setWidgetBorderColorKey(page.colorGid, modelData)
                            }
                        }
                    }
                }
            }

            // dim backdrop: click outside to dismiss
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.38)
                MouseArea { anchors.fill: parent; onClicked: { page.colorGid = ""; page.colorLabel = "" } }
            }

            Rectangle {
                id: menu
                anchors.centerIn: parent
                width: Math.min(360, page.width - 40)
                height: menuCol.implicitHeight + 20
                radius: page.root.pillRadius
                color: page.root.bg
                border.color: page.root.sep
                border.width: 1

                MouseArea { anchors.fill: parent; onClicked: {} }   // eat clicks inside

                Column {
                    id: menuCol
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    // header: "<WIDGET> COLOR" + reset / inherit hint
                    Item {
                        width: parent.width
                        height: 16
                        UiText {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: page.colorLabel.toUpperCase() + I18n.tr(" APPEARANCE")
                            color: page.root.sumiHi
                            font.family: page.root.mono
                            font.pixelSize: 12
                            font.letterSpacing: 0.7
                        }
                        UiText {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: (page.root.widgetPaletteId(page.colorGid) === "inherit" && !page.root.widgetGeomCustomized(page.colorGid)) ? I18n.tr("INHERIT") : I18n.tr("RESET")
                            color: resetMa.containsMouse ? page.root.seal : page.root.sumiHi
                            font.family: page.root.mono
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: resetMa
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 48
                            height: parent.height
                            enabled: page.root.widgetPaletteId(page.colorGid) !== "inherit" || page.root.widgetGeomCustomized(page.colorGid)
                            hoverEnabled: enabled
                            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: { page.root.resetWidgetColor(page.colorGid); page.root.resetWidgetGeom(page.colorGid) }
                        }
                    }

                    // palette swatches (colors.toml palette, 8 across)
                    Grid {
                        width: parent.width
                        columns: 8
                        columnSpacing: 4
                        rowSpacing: 4
                        Repeater {
                            model: page.root.barColorOptions
                            delegate: Rectangle {
                                required property string modelData
                                readonly property bool selected:
                                    page.root.widgetPaletteId(page.colorGid) === modelData
                                width: page.root.evenW((menuCol.width - 28) / 8)
                                height: 22
                                radius: page.root.tileRadius
                                color: page.root.paletteColor(modelData)
                                border.color: page.root.sep
                                border.width: 1
                                scale: swatchMa.containsMouse ? 1.06 : 1.0
                                z: swatchMa.containsMouse ? 1 : 0
                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                UiText {
                                    anchors.centerIn: parent
                                    text: modelData === "foreground" ? I18n.tr("F") : modelData.slice(-1)
                                    color: page.root.paletteContrastColor(modelData)
                                    font.family: page.root.mono
                                    font.pixelSize: 10
                                    font.weight: Font.Medium
                                }
                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    width: 12; height: 2; radius: 1
                                    visible: parent.selected
                                    color: page.root.paletteContrastColor(modelData)
                                }
                                MouseArea {
                                    id: swatchMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (parent.selected) page.root.resetWidgetColor(page.colorGid)
                                        else page.root.setWidgetPaletteColor(page.colorGid, modelData)
                                    }
                                }
                            }
                        }
                    }

                    // frame (border) toggle
                    Rectangle {
                        width: parent.width
                        height: 24
                        radius: page.root.tileRadius
                        readonly property bool outlineOn: page.root.widgetHasBorder(page.colorGid)
                        color: outlineOn ? page.root.fillActive : borderMa.containsMouse ? page.root.fillHover : page.root.fillIdle
                        border.color: outlineOn || borderMa.containsMouse ? page.root.seal : page.root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        UiText {
                            anchors.centerIn: parent
                            text: I18n.tr("Frame")
                            color: parent.outlineOn || borderMa.containsMouse ? page.root.seal : page.root.ink
                            font.family: page.root.mono
                            font.pixelSize: 10
                        }
                        MouseArea {
                            id: borderMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: page.root.setWidgetBorderEnabled(
                                page.colorGid, !page.root.widgetHasBorder(page.colorGid))
                        }
                    }

                    FrameWidthRow {
                        glabel: I18n.tr("WIDTH")
                        visible: page.root.widgetHasBorder(page.colorGid)
                        opts: [{ v: 0.5, label: "0.5" }, { v: 1, label: "1" }, { v: 1.5, label: "1.5" }, { v: 2, label: "2" }]
                    }
                    FrameColorRow {
                        glabel: I18n.tr("COLOUR")
                        visible: page.root.widgetHasBorder(page.colorGid)
                    }

                    // content tone - only meaningful when the group carries a fill
                    Row {
                        width: parent.width
                        spacing: 4
                        visible: page.root.widgetHasFill(page.colorGid)
                        Repeater {
                            model: [
                                { id: "auto",       label: "Auto" },
                                { id: "background", label: "BG" },
                                { id: "foreground", label: "FG" }
                            ]
                            delegate: Rectangle {
                                required property var modelData
                                readonly property bool selected:
                                    page.root.widgetTone(page.colorGid) === modelData.id
                                width: page.root.evenW((menuCol.width - 8) / 3)
                                height: 24
                                radius: page.root.tileRadius
                                color: selected ? page.root.fillActive
                                    : toneMa.containsMouse ? page.root.fillHover : "transparent"
                                border.color: selected || toneMa.containsMouse ? page.root.seal : page.root.sep
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 120 } }
                                UiText {
                                    anchors.centerIn: parent
                                    text: I18n.tr(modelData.label)
                                    color: parent.selected ? page.root.seal : page.root.ink
                                    font.family: page.root.mono
                                    font.pixelSize: 10
                                }
                                MouseArea {
                                    id: toneMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: page.root.setWidgetTone(page.colorGid, modelData.id)
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: page.root.sep }
                    GeomRow {
                        glabel: "OPACITY"
                        gkey: "opacity"
                        opts: [{ v: 1, label: "100" }, { v: 0.85, label: "85" }, { v: 0.7, label: "70" }, { v: 0.5, label: "50" }]
                    }
                    GeomRow {
                        glabel: "CORNERS"
                        gkey: "radius"
                        opts: [{ v: 0, label: "0" }, { v: 4, label: "4" }, { v: 8, label: "8" }, { v: 12, label: "12" }]
                    }
                    GeomRow {
                        glabel: "PADDING"
                        gkey: "pad"
                        opts: [{ v: 0, label: "0" }, { v: 2, label: "2" }, { v: 4, label: "4" }, { v: 6, label: "6" }]
                    }
                }
            }
        }
    }

    CcScrollRail { root: page.root; flick: flick; z: 5 }
}
