pragma ComponentBehavior: Bound
import QtQuick
import "../kit"
import "../../modules"
import Ryoku.Ui
import Ryoku.Ui.Singletons
import shell.services as Services
import "../../../../../desktop/Singletons" as DesktopCfg
import "../../../../../visualizer/Singletons" as VizCfg
import "../../../../../depth/Singletons" as DepthCfg

// DESKTOP route (卓上). What rides the wallpaper: the seven desktop widgets and
// the audio spectrum. Widget on/off writes widgets.json through the desktop
// Config.set (the same file the drag and Ryoku Settings write); the spectrum
// reads and writes visualizer.json through its own Config, and placement is the
// desktop menu's own call (ShellState.visualizerPlacing).
Item {
    id: page
    property var root
    property var cc
    readonly property var tk: cc.tokens
    readonly property real colW: Math.min(page.width, tk.contentW)
    implicitHeight: col.implicitHeight

    // Chips render the option string, so the caption lives in `options` and maps
    // back to the shader name here.
    readonly property var filterNames: ["", "bone", "halftone", "onebit", "vignette", "grain"]
    readonly property var filterCaptions: ["None", "Bone", "Halftone", "1-bit", "Vignette", "Grain"]
    function filterCaption(name) {
        const i = page.filterNames.indexOf(String(name || ""));
        return page.filterCaptions[i >= 0 ? i : 0];
    }
    function filterName(caption) {
        const i = page.filterCaptions.indexOf(caption);
        return page.filterNames[i >= 0 ? i : 0];
    }

    // A labelled boolean row: the switch reflects `value` and writes back through
    // `toggled`. Every row but the first in its card carries a divider.
    component OnOff: SettingRow {
        id: r
        property bool value: false
        signal toggled(bool on)
        anchors.left: parent.left
        anchors.right: parent.right
        controlWidth: 54
        Sw {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            on: r.value
            onToggled: (v) => r.toggled(v)
        }
    }

    // One arrow of the style cycler, drawn like a stepper button. A bespoke
    // schematic control, so it stays on page.tk rather than becoming a form kit
    // piece; only its row container is the house SettingRow.
    component CycArrow: Rectangle {
        id: arw
        property string glyph: ""
        signal act()
        width: Tokens.ctlH
        height: Tokens.ctlH
        radius: Tokens.radius
        color: aMa.containsMouse ? Tokens.tint5 : "transparent"
        border.width: 1
        border.color: Tokens.line
        Behavior on color { ColorAnimation { duration: Tokens.snap } }
        UiText {
            anchors.centerIn: parent
            text: arw.glyph
            color: Tokens.ink
            font.family: Tokens.mono
            font.pixelSize: Tokens.fSmall
        }
        MouseArea {
            id: aMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: arw.act()
        }
    }

    // Fixes the style-name column to the widest style so the arrows never shift
    // as it counts through the eleven looks.
    TextMetrics {
        id: styleMetrics
        font.family: Tokens.mono
        font.pixelSize: Tokens.fSmall
        text: "segments"
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
            width: page.colW
            spacing: page.tk.sectionGap

            Entrance {
                width: page.colW
                index: 0
                SettingCard {
                    width: page.colW
                    title: I18n.tr("WIDGETS")
                    kana: "\u90e8\u54c1"

                    OnOff {
                        label: I18n.tr("Clock")
                        source: "widgets.json"
                        value: DesktopCfg.Config.clockEnabled
                        onToggled: (on) => DesktopCfg.Config.set("clockEnabled", on)
                    }
                    OnOff {
                        label: I18n.tr("Calendar")
                        divider: true
                        source: "widgets.json"
                        value: DesktopCfg.Config.calendarEnabled
                        onToggled: (on) => DesktopCfg.Config.set("calendarEnabled", on)
                    }
                    OnOff {
                        label: I18n.tr("Music")
                        divider: true
                        source: "widgets.json"
                        value: DesktopCfg.Config.musicEnabled
                        onToggled: (on) => DesktopCfg.Config.set("musicEnabled", on)
                    }
                    OnOff {
                        label: I18n.tr("All-in-one")
                        divider: true
                        source: "widgets.json"
                        value: DesktopCfg.Config.aioEnabled
                        onToggled: (on) => DesktopCfg.Config.set("aioEnabled", on)
                    }
                    OnOff {
                        label: I18n.tr("System stats")
                        divider: true
                        source: "widgets.json"
                        value: DesktopCfg.Config.statsEnabled
                        onToggled: (on) => DesktopCfg.Config.set("statsEnabled", on)
                    }
                    OnOff {
                        label: I18n.tr("Weather")
                        divider: true
                        source: "widgets.json"
                        value: DesktopCfg.Config.weatherEnabled
                        onToggled: (on) => DesktopCfg.Config.set("weatherEnabled", on)
                    }
                    OnOff {
                        label: I18n.tr("Notes")
                        divider: true
                        source: "widgets.json"
                        value: DesktopCfg.Config.notesEnabled
                        onToggled: (on) => DesktopCfg.Config.set("notesEnabled", on)
                    }
                }
            }

            Entrance {
                width: page.colW
                index: 1
                SettingCard {
                    width: page.colW
                    title: I18n.tr("SPECTRUM")
                    kana: "\u97f3"

                    OnOff {
                        label: I18n.tr("Visualiser")
                        source: "visualizer.json"
                        value: VizCfg.Config.enabled
                        onToggled: (on) => VizCfg.Config.setEnabled(on)
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        label: I18n.tr("Style")
                        source: "visualizer.json"
                        controlWidth: styleCyc.implicitWidth
                        Row {
                            id: styleCyc
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: page.tk.gap / 2
                            CycArrow { glyph: "\u2039"; onAct: VizCfg.Config.cycleStyle(-1) }
                            UiText {
                                anchors.verticalCenter: parent.verticalCenter
                            width: styleMetrics.width + page.tk.gap
                                horizontalAlignment: Text.AlignHCenter
                                text: VizCfg.Config.styleId
                                color: Tokens.ink
                                font.family: Tokens.mono
                                font.pixelSize: Tokens.fSmall
                            }
                            CycArrow { glyph: "\u203a"; onAct: VizCfg.Config.cycleStyle(1) }
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        footH: 32
                        label: I18n.tr("Place visualiser")
                        Btn {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: I18n.tr("PLACE")
                            onAct: {
                                VizCfg.Config.setEnabled(true);
                                const st = Services.ShellState.forActive();
                                if (st)
                                    st.visualizerPlacing = true;
                                if (page.cc)
                                    page.cc.close();
                            }
                        }
                    }
                }
            }
            Entrance {
                width: page.colW
                index: 2
                SettingCard {
                    width: page.colW
                    title: I18n.tr("DEPTH")
                    kana: "\u5965\u884c"

                    OnOff {
                        label: I18n.tr("Depth effect")
                        source: "depth.json"
                        value: DepthCfg.Config.enabled
                        enabled: DepthCfg.DepthBackend.available
                        onToggled: on => DepthCfg.Config.setEnabled(on)
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        visible: !DepthCfg.DepthBackend.available
                        block: true
                        label: DepthCfg.DepthBackend.installing ? I18n.tr("Installing engine") : I18n.tr("Install engine")
                        desc: DepthCfg.DepthBackend.installing ? DepthCfg.DepthBackend.progress : I18n.tr("Downloads a small on-device model to cut the wallpaper's subject out.")
                        Btn {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: DepthCfg.DepthBackend.installing ? I18n.tr("WORKING") : I18n.tr("INSTALL")
                            enabled: !DepthCfg.DepthBackend.installing
                            onAct: DepthCfg.DepthBackend.install()
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        visible: DepthCfg.DepthBackend.available && DepthCfg.DepthBackend.models.length > 1
                        block: true
                        label: I18n.tr("Model")
                        source: "depth.json"
                        Chips {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            options: DepthCfg.DepthBackend.models
                            current: DepthCfg.Config.model
                            onChose: m => DepthCfg.Config.setModel(m)
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        divider: true
                        visible: DepthCfg.DepthBackend.available
                        footH: 32
                        label: I18n.tr("Compose depth")
                        Btn {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("COMPOSE")
                            onAct: {
                                DepthCfg.Config.setEnabled(true);
                                const st = Services.ShellState.forActive();
                                if (st)
                                    st.depthComposing = true;
                                if (page.cc)
                                    page.cc.close();
                            }
                        }
                    }
                }
            }
            // A look, not a performance knob, so it lives here rather than on the
            // System route. Low power forces it off in decoration.lua.
            Entrance {
                width: page.colW
                index: 3
                SettingCard {
                    width: page.colW
                    title: I18n.tr("PRINT")
                    kana: "\u5237"

                    SettingRow {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        block: true
                        label: I18n.tr("Screen filter")
                        desc: I18n.tr("Resolve every window to the desktop's own ink.")
                        source: "shell.json"
                        Chips {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            options: page.filterCaptions
                            current: page.filterCaption(Services.Config.screenShader)
                            onChose: (caption) => Services.Config.setScreenShader(page.filterName(caption))
                        }
                    }
                }
            }
        }
    }

    CcScrollRail { root: page.root; flick: flick; z: 5 }
}
